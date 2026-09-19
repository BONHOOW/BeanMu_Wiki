import Foundation
import Security

/// 제네릭 패스워드 항목. kSecUseDataProtectionKeychain은 쓰지 않는다 — 무료 팀의 macOS 앱에서 -34018
enum Keychain {
    private static func query(_ key: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: "BeanMuWiki.google", kSecAttrAccount: key]
    }

    /// 삭제 후 추가
    static func save(_ data: Data, key: String) throws {
        delete(key: key)
        var q = query(key); q[kSecValueData] = data
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    static func load(key: String) -> Data? {
        var q = query(key); q[kSecReturnData] = true; q[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess ? result as? Data : nil
    }

    static func delete(key: String) { SecItemDelete(query(key) as CFDictionary) }
}
