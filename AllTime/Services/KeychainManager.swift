import Foundation
import Security
import os.log

class KeychainManager {
    static let shared = KeychainManager()

    // Service identifier - scopes keychain items to this app
    private let service = "com.alltime.clara"

    // OSLog for keychain operations
    private let log = OSLog(subsystem: "com.alltime.clara", category: "KEYCHAIN")

    // Retry configuration for transient Keychain failures
    private let maxRetries = 5
    private let retryDelayMs: UInt64 = 200_000_000 // 200ms

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
        // Synchronous retrieval with internal retry
        return retrieveWithRetry(key: key, attempt: 1)
    }

    private func retrieveWithRetry(key: String, attempt: Int) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let value = String(data: data, encoding: .utf8) {
            if attempt > 1 {
                os_log("[KEYCHAIN] Retrieved %{public}@ on attempt %{public}d", log: log, type: .info, key, attempt)
            }
            return value
        }

        // Handle different error codes
        switch status {
        case errSecItemNotFound:
            // Item genuinely doesn't exist - don't retry
            return nil

        case errSecInteractionNotAllowed:
            // Device locked - retry with delay
            os_log("[KEYCHAIN] %{public}@ errSecInteractionNotAllowed (device locked?) - attempt %{public}d/%{public}d",
                   log: log, type: .error, key, attempt, maxRetries)

        case errSecAuthFailed:
            // Auth failed - retry
            os_log("[KEYCHAIN] %{public}@ errSecAuthFailed - attempt %{public}d/%{public}d",
                   log: log, type: .error, key, attempt, maxRetries)

        default:
            // Other error - log and retry
            os_log("[KEYCHAIN] %{public}@ failed with status %{public}d - attempt %{public}d/%{public}d",
                   log: log, type: .error, key, status, attempt, maxRetries)
        }

        // Retry if we haven't exceeded max attempts
        if attempt < maxRetries {
            // Synchronous sleep for retry
            Thread.sleep(forTimeInterval: Double(retryDelayMs) / 1_000_000_000)
            return retrieveWithRetry(key: key, attempt: attempt + 1)
        }

        os_log("[KEYCHAIN] CRITICAL: Failed to retrieve %{public}@ after %{public}d attempts, final status: %{public}d",
               log: log, type: .fault, key, maxRetries, status)
        print("🔑 KeychainManager: CRITICAL - Failed to retrieve \(key) after \(maxRetries) attempts, status: \(status)")
        return nil
    }

    /// Async version with proper retry delays
    func retrieveAsync(key: String) async -> String? {
        for attempt in 1...maxRetries {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]

            var dataTypeRef: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

            if status == errSecSuccess,
               let data = dataTypeRef as? Data,
               let value = String(data: data, encoding: .utf8) {
                if attempt > 1 {
                    os_log("[KEYCHAIN] Retrieved %{public}@ on async attempt %{public}d", log: log, type: .info, key, attempt)
                }
                return value
            }

            if status == errSecItemNotFound {
                return nil
            }

            os_log("[KEYCHAIN] Async retrieve %{public}@ failed, status %{public}d, attempt %{public}d/%{public}d",
                   log: log, type: .error, key, status, attempt, maxRetries)

            if attempt < maxRetries {
                try? await Task.sleep(nanoseconds: retryDelayMs)
            }
        }

        os_log("[KEYCHAIN] CRITICAL: Async retrieve %{public}@ failed after %{public}d attempts",
               log: log, type: .fault, key, maxRetries)
        return nil
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

