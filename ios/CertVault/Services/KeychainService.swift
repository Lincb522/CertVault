import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    private let service = AppConstants.keychainServiceName

    private init() {}

    func save(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else {
            AppLogger.auth.error("🔐 Keychain save failed — cannot encode key=\(key)")
            return
        }
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            AppLogger.auth.debug("🔐 Keychain saved key=\(key) len=\(value.count)")
        } else {
            AppLogger.auth.error("🔐 Keychain save error key=\(key) status=\(status)")
        }
    }

    func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            AppLogger.auth.debug("🔐 Keychain get key=\(key) → nil (status=\(status))")
            return nil
        }
        let value = String(data: data, encoding: .utf8)
        AppLogger.auth.debug("🔐 Keychain get key=\(key) → len=\(value?.count ?? 0)")
        return value
    }

    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        AppLogger.auth.debug("🔐 Keychain delete key=\(key) status=\(status)")
    }
}
