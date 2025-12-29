import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()

    // Service identifier - scopes keychain items to this app
    private let service = "com.alltime.clara"

    private init() {
        // Migrate old tokens without service identifier (one-time migration)
        migrateOldTokensIfNeeded()
    }

    // MARK: - Keychain Operations

    func store(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            print("🔑 KeychainManager: Failed to encode value for key: \(key)")
            return false
        }

        // Query to find existing item
        let findQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        // Delete existing item first
        SecItemDelete(findQuery as CFDictionary)

        // Add new item with proper accessibility
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // AccessibleAfterFirstUnlock ensures tokens persist across app restarts
            // and are available even when the device is locked (after first unlock)
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        if status == errSecSuccess {
            print("🔑 KeychainManager: Stored \(key) successfully")
            return true
        } else {
            print("🔑 KeychainManager: Failed to store \(key), status: \(status)")
            return false
        }
    }

    func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let value = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                print("🔑 KeychainManager: Failed to retrieve \(key), status: \(status)")
            }
            return nil
        }

        return value
    }

    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Migration

    /// Migrate tokens stored without service identifier to new format
    private func migrateOldTokensIfNeeded() {
        // Check if migration already done
        if UserDefaults.standard.bool(forKey: "keychain_migration_v1_done") {
            return
        }

        print("🔑 KeychainManager: Checking for old tokens to migrate...")

        // Try to retrieve old-style tokens (without service)
        let oldAccessToken = retrieveOldStyle(key: "access_token")
        let oldRefreshToken = retrieveOldStyle(key: "refresh_token")

        if let accessToken = oldAccessToken, let refreshToken = oldRefreshToken {
            print("🔑 KeychainManager: Found old tokens, migrating...")

            // Store with new format
            let success = storeTokens(accessToken: accessToken, refreshToken: refreshToken)

            if success {
                // Delete old tokens
                deleteOldStyle(key: "access_token")
                deleteOldStyle(key: "refresh_token")
                print("🔑 KeychainManager: Migration complete!")
            }
        }

        UserDefaults.standard.set(true, forKey: "keychain_migration_v1_done")
    }

    /// Retrieve old-style token (without service identifier)
    private func retrieveOldStyle(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    /// Delete old-style token (without service identifier)
    private func deleteOldStyle(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Token Management
    
    func storeTokens(accessToken: String, refreshToken: String) -> Bool {
        let accessSuccess = store(key: "access_token", value: accessToken)
        let refreshSuccess = store(key: "refresh_token", value: refreshToken)
        return accessSuccess && refreshSuccess
    }
    
    func getAccessToken() -> String? {
        return retrieve(key: "access_token")
    }
    
    func getRefreshToken() -> String? {
        return retrieve(key: "refresh_token")
    }
    
    func clearTokens() -> Bool {
        let accessDeleted = delete(key: "access_token")
        let refreshDeleted = delete(key: "refresh_token")
        return accessDeleted && refreshDeleted
    }
    
    func hasValidTokens() -> Bool {
        return getAccessToken() != nil && getRefreshToken() != nil
    }
}

