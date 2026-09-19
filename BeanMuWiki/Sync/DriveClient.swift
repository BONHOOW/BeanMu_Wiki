import Foundation

struct DriveFile: Decodable { let id, name, modifiedTime: String }

nonisolated enum DriveError: LocalizedError {
    case http(Int, String)
    var errorDescription: String? { if case .http(let code, let body) = self { "Drive HTTP \(code): \(body)" } else { nil } }
}

/// Drive v3 appDataFolder(사용자에게 보이지 않는 앱 전용 공간) REST 클라이언트
final class DriveClient {
    private let auth: GoogleAuth
    private static let api = "https://www.googleapis.com/drive/v3/files"
    private static let upload = "https://www.googleapis.com/upload/drive/v3/files"

    init(auth: GoogleAuth) { self.auth = auth }

    /// 이름 → 파일. 이름이 같으면 하나만 남는다
    // ponytail: appDataFolder 파일 1000개 초과 시 nextPageToken 페이지네이션
    func listAppData() async throws -> [String: DriveFile] {
        struct List: Decodable { var files: [DriveFile] }
        let url = URL(string: Self.api + "?spaces=appDataFolder&fields=files(id,name,modifiedTime)&pageSize=1000")!
        let files = try JSONDecoder().decode(List.self, from: try await send(URLRequest(url: url))).files
        return Dictionary(files.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func download(_ id: String) async throws -> Data {
        try await send(URLRequest(url: URL(string: Self.api + "/\(id)?alt=media")!))
    }

    func modifiedTime(_ id: String) async throws -> String {
        struct Meta: Decodable { var modifiedTime: String }
        return try JSONDecoder().decode(Meta.self, from: try await send(URLRequest(url: URL(string: Self.api + "/\(id)?fields=modifiedTime")!))).modifiedTime
    }

    /// 기존 파일은 내용만 교체(PATCH media), 새 파일은 multipart로 메타데이터 + 내용
    func upload(name: String, existingID: String?, data: Data, mimeType: String) async throws -> DriveFile {
        var req: URLRequest
        if let existingID {
            req = URLRequest(url: URL(string: Self.upload + "/\(existingID)?uploadType=media&fields=id,name,modifiedTime")!)
            req.httpMethod = "PATCH"
            req.setValue(mimeType, forHTTPHeaderField: "Content-Type")
            req.httpBody = data
        } else {
            let boundary = "beanmuwiki-\(UUID().uuidString)"
            req = URLRequest(url: URL(string: Self.upload + "?uploadType=multipart&fields=id,name,modifiedTime")!)
            req.httpMethod = "POST"
            req.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            let meta = try JSONSerialization.data(withJSONObject: ["name": name, "parents": ["appDataFolder"]])
            var body = Data("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".utf8)
            body += meta
            body += Data("\r\n--\(boundary)\r\nContent-Type: \(mimeType)\r\n\r\n".utf8)
            body += data
            body += Data("\r\n--\(boundary)--".utf8)
            req.httpBody = body
        }
        return try JSONDecoder().decode(DriveFile.self, from: try await send(req))
    }

    /// Bearer 토큰 부착. 401이면 갱신 후 한 번 재시도
    private func send(_ req: URLRequest, retry: Bool = true) async throws -> Data {
        var req = req
        req.setValue("Bearer " + (try await auth.validAccessToken()), forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401, retry { try await auth.refresh(); return try await send(req, retry: false) }
        guard (200..<300).contains(status) else { throw DriveError.http(status, String(decoding: data.prefix(300), as: UTF8.self)) }
        return data
    }
}
