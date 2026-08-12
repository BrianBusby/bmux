import Foundation
#if canImport(Security)
import Security
#endif

/// Production Keychain backend for generic-password secrets.
struct SystemKeychainSecretStoreBackend: KeychainSecretStoreBackend {
    func read(service: String, account: String) async throws -> String? {
        #if canImport(Security)
        var query = Self.baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainSecretStoreError.readFailed(status: Int32(status))
        }
        return String(data: data, encoding: .utf8)
        #else
        throw KeychainSecretStoreError.unavailable
        #endif
    }

    func write(_ value: String, service: String, account: String) async throws {
        #if canImport(Security)
        guard let data = value.data(using: .utf8) else {
            throw KeychainSecretStoreError.writeFailed(status: errSecParam)
        }
        let lookup = Self.baseQuery(service: service, account: account)
        let updateStatus = SecItemUpdate(
            lookup as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            throw KeychainSecretStoreError.writeFailed(status: Int32(updateStatus))
        }
        var insert = lookup
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainSecretStoreError.writeFailed(status: Int32(addStatus))
        }
        #else
        throw KeychainSecretStoreError.unavailable
        #endif
    }

    func delete(service: String, account: String) async throws {
        #if canImport(Security)
        let status = SecItemDelete(Self.baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainSecretStoreError.deleteFailed(status: Int32(status))
        }
        #else
        throw KeychainSecretStoreError.unavailable
        #endif
    }

    #if canImport(Security)
    private static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
    #endif
}
