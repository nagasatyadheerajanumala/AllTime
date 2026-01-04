import Foundation
import Combine
import os.log

/// Centralized auth diagnostics for debugging authentication issues
/// Tags: [AUTH], [DEEPLINK], [NAV], [SYNC], [OFFLINE]
@MainActor
class AuthDiagnostics: ObservableObject {
    static let shared = AuthDiagnostics()

    // MARK: - OSLog Subsystems
    private let authLog = OSLog(subsystem: "com.alltime.clara", category: "AUTH")
    private let deepLinkLog = OSLog(subsystem: "com.alltime.clara", category: "DEEPLINK")
    private let navLog = OSLog(subsystem: "com.alltime.clara", category: "NAV")
    private let syncLog = OSLog(subsystem: "com.alltime.clara", category: "SYNC")
    private let offlineLog = OSLog(subsystem: "com.alltime.clara", category: "OFFLINE")

    // MARK: - Tracked State
    @Published private(set) var isLoggedIn: Bool = false
    @Published private(set) var tokenExpiresAt: Date?
    @Published private(set) var lastRefreshAt: Date?
    @Published private(set) var lastRefreshResult: String?
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var lastSyncResult: String?
    @Published private(set) var pendingOfflineQueueCount: Int = 0
    @Published private(set) var lastLogoutReason: String?
    @Published private(set) var lastLogoutFile: String?
    @Published private(set) var lastLogoutLine: Int?

    // MARK: - Session Restoration State
    @Published private(set) var isSessionRestoring: Bool = false
    @Published private(set) var sessionRestorationComplete: Bool = false

    private init() {
        // Load persisted token expiry if available
        if let expiryTimestamp = UserDefaults.standard.object(forKey: "auth_token_expires_at") as? TimeInterval {
            tokenExpiresAt = Date(timeIntervalSince1970: expiryTimestamp)
        }
        if let refreshTimestamp = UserDefaults.standard.object(forKey: "auth_last_refresh_at") as? TimeInterval {
            lastRefreshAt = Date(timeIntervalSince1970: refreshTimestamp)
        }
    }

    // MARK: - Auth Logging

    func logAuthEvent(_ message: String, type: OSLogType = .info, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        os_log("[AUTH] %{public}@ (%{public}@:%{public}d)", log: authLog, type: type, message, fileName, line)
        print("[AUTH] \(message) (\(fileName):\(line))")
    }

    func logSessionRestoreStart() {
        isSessionRestoring = true
        sessionRestorationComplete = false
        logAuthEvent("Session restoration STARTED", type: .info)
    }

    func logSessionRestoreComplete(success: Bool, reason: String? = nil) {
        isSessionRestoring = false
        sessionRestorationComplete = true
        isLoggedIn = success

        let message = success ? "Session restoration SUCCEEDED" : "Session restoration FAILED: \(reason ?? "unknown")"
        logAuthEvent(message, type: success ? .info : .error)
    }

    func logTokenRefreshAttempt() {
        logAuthEvent("Token refresh ATTEMPTING", type: .info)
    }

    func logTokenRefreshSuccess(expiresIn: Int) {
        lastRefreshAt = Date()
        lastRefreshResult = "success"

        // Calculate new expiry
        tokenExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))

        // Persist
        UserDefaults.standard.set(tokenExpiresAt?.timeIntervalSince1970, forKey: "auth_token_expires_at")
        UserDefaults.standard.set(lastRefreshAt?.timeIntervalSince1970, forKey: "auth_last_refresh_at")

        logAuthEvent("Token refresh SUCCEEDED - expires in \(expiresIn)s", type: .info)
    }

    func logTokenRefreshFailure(reason: String) {
        lastRefreshResult = "failed: \(reason)"
        logAuthEvent("Token refresh FAILED: \(reason)", type: .error)
    }

    func logLogout(reason: String, file: String = #file, line: Int = #line) {
        isLoggedIn = false
        lastLogoutReason = reason
        lastLogoutFile = (file as NSString).lastPathComponent
        lastLogoutLine = line
        tokenExpiresAt = nil

        logAuthEvent("LOGOUT triggered: \(reason)", type: .fault, file: file, line: line)
    }

    func logLoginSuccess(expiresIn: Int) {
        isLoggedIn = true
        tokenExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        lastRefreshAt = Date()
        lastLogoutReason = nil

        // Persist
        UserDefaults.standard.set(tokenExpiresAt?.timeIntervalSince1970, forKey: "auth_token_expires_at")
        UserDefaults.standard.set(lastRefreshAt?.timeIntervalSince1970, forKey: "auth_last_refresh_at")

        logAuthEvent("LOGIN succeeded - token expires at \(tokenExpiresAt?.description ?? "unknown")", type: .info)
    }

    // MARK: - Deep Link Logging

    func logDeepLinkReceived(url: URL?, type: String?, destination: String?) {
        os_log("[DEEPLINK] Received - URL: %{public}@, type: %{public}@, destination: %{public}@",
               log: deepLinkLog, type: .info,
               url?.absoluteString ?? "nil", type ?? "nil", destination ?? "nil")
        print("[DEEPLINK] Received - URL: \(url?.absoluteString ?? "nil"), type: \(type ?? "nil"), destination: \(destination ?? "nil")")
    }

    func logDeepLinkPending(destination: String, reason: String) {
        os_log("[DEEPLINK] PENDING - destination: %{public}@, reason: %{public}@",
               log: deepLinkLog, type: .info, destination, reason)
        print("[DEEPLINK] PENDING - destination: \(destination), reason: \(reason)")
    }

    func logDeepLinkProcessed(destination: String) {
        os_log("[DEEPLINK] PROCESSED - navigating to: %{public}@",
               log: deepLinkLog, type: .info, destination)
        print("[DEEPLINK] PROCESSED - navigating to: \(destination)")
    }

    // MARK: - Navigation Logging

    func logNavigation(to destination: String, from source: String) {
        os_log("[NAV] %{public}@ -> %{public}@", log: navLog, type: .info, source, destination)
        print("[NAV] \(source) -> \(destination)")
    }

    // MARK: - Sync Logging

    func logSyncAttempt(provider: String) {
        os_log("[SYNC] Attempting sync for %{public}@", log: syncLog, type: .info, provider)
        print("[SYNC] Attempting sync for \(provider)")
    }

    func logSyncSuccess(provider: String, eventsCount: Int) {
        lastSyncAt = Date()
        lastSyncResult = "\(provider): \(eventsCount) events"
        os_log("[SYNC] SUCCESS - %{public}@: %{public}d events", log: syncLog, type: .info, provider, eventsCount)
        print("[SYNC] SUCCESS - \(provider): \(eventsCount) events")
    }

    func logSyncFailure(provider: String, error: String, isTransient: Bool, retryCount: Int) {
        lastSyncResult = "\(provider): failed - \(error)"
        let logType: OSLogType = isTransient ? .info : .error
        os_log("[SYNC] %{public}@ - %{public}@: %{public}@ (transient: %{public}@, retry: %{public}d)",
               log: syncLog, type: logType,
               isTransient ? "TRANSIENT_FAILURE" : "FAILURE",
               provider, error, isTransient ? "yes" : "no", retryCount)
        print("[SYNC] \(isTransient ? "TRANSIENT_FAILURE" : "FAILURE") - \(provider): \(error) (transient: \(isTransient), retry: \(retryCount))")
    }

    func logSyncReconnectRequired(provider: String, reason: String) {
        os_log("[SYNC] RECONNECT_REQUIRED - %{public}@: %{public}@",
               log: syncLog, type: .fault, provider, reason)
        print("[SYNC] RECONNECT_REQUIRED - \(provider): \(reason)")
    }

    // MARK: - Offline Logging

    func logOfflineQueueAdd(type: String, id: String) {
        pendingOfflineQueueCount += 1
        os_log("[OFFLINE] QUEUED - %{public}@ id: %{public}@ (queue size: %{public}d)",
               log: offlineLog, type: .info, type, id, pendingOfflineQueueCount)
        print("[OFFLINE] QUEUED - \(type) id: \(id) (queue size: \(pendingOfflineQueueCount))")
    }

    func logOfflineQueueSync(synced: Int, failed: Int) {
        pendingOfflineQueueCount = max(0, pendingOfflineQueueCount - synced)
        os_log("[OFFLINE] SYNC_COMPLETE - synced: %{public}d, failed: %{public}d, remaining: %{public}d",
               log: offlineLog, type: .info, synced, failed, pendingOfflineQueueCount)
        print("[OFFLINE] SYNC_COMPLETE - synced: \(synced), failed: \(failed), remaining: \(pendingOfflineQueueCount)")
    }

    func logNetworkStateChange(isOnline: Bool) {
        os_log("[OFFLINE] Network state: %{public}@", log: offlineLog, type: .info, isOnline ? "ONLINE" : "OFFLINE")
        print("[OFFLINE] Network state: \(isOnline ? "ONLINE" : "OFFLINE")")
    }

    // MARK: - Diagnostics Dump

    func printDiagnostics() {
        let divider = "============================================"
        let tokenStatus: String
        if let expiry = tokenExpiresAt {
            let remaining = expiry.timeIntervalSinceNow
            if remaining > 0 {
                let hours = Int(remaining) / 3600
                let minutes = (Int(remaining) % 3600) / 60
                tokenStatus = "expires in \(hours)h \(minutes)m"
            } else {
                tokenStatus = "EXPIRED \(Int(-remaining))s ago"
            }
        } else {
            tokenStatus = "unknown"
        }

        let diagnostics = """
        \(divider)
        🔍 CLARA AUTH DIAGNOSTICS
        \(divider)

        📱 AUTH STATE:
           - Logged In: \(isLoggedIn ? "YES" : "NO")
           - Session Restoring: \(isSessionRestoring ? "YES" : "NO")
           - Session Restored: \(sessionRestorationComplete ? "YES" : "NO")

        🔑 TOKENS:
           - Token Status: \(tokenStatus)
           - Token Expires At: \(tokenExpiresAt?.description ?? "nil")
           - Last Refresh: \(lastRefreshAt?.description ?? "never")
           - Last Refresh Result: \(lastRefreshResult ?? "none")

        🔄 SYNC:
           - Last Sync: \(lastSyncAt?.description ?? "never")
           - Last Sync Result: \(lastSyncResult ?? "none")

        📴 OFFLINE:
           - Pending Queue: \(pendingOfflineQueueCount) items

        🚪 LAST LOGOUT:
           - Reason: \(lastLogoutReason ?? "none")
           - Location: \(lastLogoutFile ?? "N/A"):\(lastLogoutLine ?? 0)

        \(divider)
        """

        print(diagnostics)
        os_log("%{public}@", log: authLog, type: .info, diagnostics)
    }

    /// Check if we should wait for session restoration before proceeding
    var shouldWaitForSessionRestoration: Bool {
        return isSessionRestoring && !sessionRestorationComplete
    }

    /// Token time remaining in seconds (negative if expired)
    var tokenTimeRemaining: TimeInterval? {
        guard let expiry = tokenExpiresAt else { return nil }
        return expiry.timeIntervalSinceNow
    }

    /// True if token will expire within the given seconds
    func tokenExpiresWithin(seconds: TimeInterval) -> Bool {
        guard let remaining = tokenTimeRemaining else { return true }
        return remaining < seconds
    }
}
