import Testing
import Foundation
import SwiftData
@testable import BeanMuWiki

@MainActor
struct GoogleAuthTests {
    /// RFC 7636 Appendix B
    @Test func pkceKnownVector() {
        #expect(PKCE.challenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        let v = PKCE.verifier()
        #expect(v.count == 43 && v.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") })
        #expect(PKCE.verifier() != v)
    }

    @Test func keychainRoundTrip() throws {
        let key = "test-\(UUID().uuidString)"
        #expect(Keychain.load(key: key) == nil)
        try Keychain.save(Data([1, 2, 3]), key: key)
        #expect(Keychain.load(key: key) == Data([1, 2, 3]))
        try Keychain.save(Data([9]), key: key)   // 덮어쓰기
        #expect(Keychain.load(key: key) == Data([9]))
        Keychain.delete(key: key)
        #expect(Keychain.load(key: key) == nil)
    }

    @Test func googleConfigDerivesScheme() {
        #expect(GoogleConfig.scheme(for: "123-abc.apps.googleusercontent.com") == "com.googleusercontent.apps.123-abc")
        #expect(GoogleConfig.redirectURI.hasSuffix(":/oauth2redirect"))
        #expect(!GoogleConfig.isConfigured)   // 자리표시자 상태
    }

    @Test func syncEngineStateWithoutConfig() throws {
        let container = try ModelContainer(for: Bean.self, Tombstone.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let engine = SyncEngine(context: container.mainContext, enabled: true)
        #expect(engine.state == .notConfigured)
        engine.start()   // 미설정 → 네트워크 없이 no-op
        #expect(engine.state == .notConfigured)
    }
}
