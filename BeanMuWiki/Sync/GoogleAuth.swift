import AuthenticationServices
import CryptoKit
import Foundation
import Observation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum GoogleConfig {
    /// Google Cloud Console → 클라이언트(iOS, 번들 ID com.bonho.BeanMuWiki)에서 복사한 값. Mac 앱도 같은 클라이언트를 쓴다.
    static let clientID = "279753157426-ec1nc65htj4tj11is0gtgkrbatvfk30r.apps.googleusercontent.com"
    static var isConfigured: Bool { !clientID.hasPrefix("PASTE_ME") }
    static var scheme: String { scheme(for: clientID) }
    static var redirectURI: String { scheme + ":/oauth2redirect" }
    static let scopes = "https://www.googleapis.com/auth/drive.appdata https://www.googleapis.com/auth/userinfo.email"

    /// "123-abc.apps.googleusercontent.com" → "com.googleusercontent.apps.123-abc"
    static func scheme(for clientID: String) -> String {
        "com.googleusercontent.apps." + clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
    }
}

/// RFC 7636
enum PKCE {
    /// 32바이트 난수 → base64url 43자
    static func verifier() -> String { base64url(Data((0..<32).map { _ in UInt8.random(in: 0...255) })) }
    static func challenge(_ verifier: String) -> String { base64url(Data(SHA256.hash(data: Data(verifier.utf8)))) }

    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

nonisolated enum AuthError: LocalizedError {
    case cancelled, signedOut, http(Int, String), missingCode, notConfigured
    var errorDescription: String? {
        switch self {
        case .cancelled: "취소되었습니다"
        case .signedOut: "로그인이 만료되었습니다. 다시 로그인하세요"
        case .http(let code, let body): "HTTP \(code): \(body)"
        case .missingCode: "인증 코드를 받지 못했습니다"
        case .notConfigured: "Google 클라이언트 ID가 설정되지 않았습니다"
        }
    }
}

/// OAuth 2.0 PKCE (iOS 클라이언트, 시크릿 없음). 토큰은 Keychain "tokens"에 JSON으로
@Observable final class GoogleAuth {
    struct Tokens: Codable { var accessToken: String; var refreshToken: String; var email: String; var expiresAt: Date }
    private struct TokenResponse: Decodable { var access_token: String; var expires_in: Double; var refresh_token: String? }

    private(set) var tokens: Tokens?
    var isSignedIn: Bool { tokens != nil }
    var email: String? { tokens?.email }
    private let anchor = Anchor()
    private static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

    init() { tokens = Keychain.load(key: "tokens").flatMap { try? JSONDecoder().decode(Tokens.self, from: $0) } }

    func signIn() async throws {
        guard GoogleConfig.isConfigured else { throw AuthError.notConfigured }
        let verifier = PKCE.verifier()
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id", value: GoogleConfig.clientID), .init(name: "redirect_uri", value: GoogleConfig.redirectURI),
            .init(name: "response_type", value: "code"), .init(name: "scope", value: GoogleConfig.scopes),
            .init(name: "code_challenge", value: PKCE.challenge(verifier)), .init(name: "code_challenge_method", value: "S256"),
            .init(name: "prompt", value: "consent"),
        ]
        let callback: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: components.url!, callback: .customScheme(GoogleConfig.scheme)) { url, error in
                if let url { continuation.resume(returning: url) }
                else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { continuation.resume(throwing: AuthError.cancelled) }
                else { continuation.resume(throwing: error ?? AuthError.missingCode) }
            }
            session.prefersEphemeralWebBrowserSession = false
            session.presentationContextProvider = anchor
            session.start()
        }
        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.missingCode
        }
        let response = try await token(["code": code, "client_id": GoogleConfig.clientID, "code_verifier": verifier,
                                        "redirect_uri": GoogleConfig.redirectURI, "grant_type": "authorization_code"])
        guard let refresh = response.refresh_token else { throw AuthError.missingCode }
        var info = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!)
        info.setValue("Bearer " + response.access_token, forHTTPHeaderField: "Authorization")
        struct UserInfo: Decodable { var email: String }
        let email = try JSONDecoder().decode(UserInfo.self, from: try await send(info)).email
        try store(Tokens(accessToken: response.access_token, refreshToken: refresh, email: email,
                         expiresAt: .now.addingTimeInterval(response.expires_in)))
    }

    /// 취소는 최선 노력 — 실패해도 로컬 토큰은 지운다
    func signOut() async {
        if let refresh = tokens?.refreshToken {
            var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/revoke?token=" + refresh)!)
            req.httpMethod = "POST"
            _ = try? await send(req)
        }
        Keychain.delete(key: "tokens"); tokens = nil
    }

    /// 만료 60초 전이면 갱신
    func validAccessToken() async throws -> String {
        guard let tokens else { throw AuthError.signedOut }
        if tokens.expiresAt > .now.addingTimeInterval(60) { return tokens.accessToken }
        try await refresh()
        return self.tokens!.accessToken
    }

    /// invalid_grant(취소·만료된 refresh token) → 로그아웃 상태
    func refresh() async throws {
        guard let tokens else { throw AuthError.signedOut }
        do {
            let response = try await token(["grant_type": "refresh_token", "client_id": GoogleConfig.clientID, "refresh_token": tokens.refreshToken])
            try store(Tokens(accessToken: response.access_token, refreshToken: tokens.refreshToken, email: tokens.email,
                             expiresAt: .now.addingTimeInterval(response.expires_in)))
        } catch AuthError.http(_, let body) where body.contains("invalid_grant") {
            Keychain.delete(key: "tokens"); self.tokens = nil
            throw AuthError.signedOut
        }
    }

    private func store(_ t: Tokens) throws { try Keychain.save(try JSONEncoder().encode(t), key: "tokens"); tokens = t }

    private func token(_ form: [String: String]) async throws -> TokenResponse {
        var req = URLRequest(url: Self.tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = URLComponents(); body.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        req.httpBody = Data(body.percentEncodedQuery!.utf8)
        return try JSONDecoder().decode(TokenResponse.self, from: try await send(req))
    }

    private func send(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw AuthError.http(status, String(decoding: data.prefix(300), as: UTF8.self)) }
        return data
    }
}

/// ASWebAuthenticationSession을 띄울 창
final class Anchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(macOS)
        NSApp.keyWindow ?? NSApp.windows.first ?? NSWindow()
        #else
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!   // 로그인 버튼은 보이는 창에서 눌린다
        return scene.keyWindow ?? UIWindow(windowScene: scene)
        #endif
    }
}
