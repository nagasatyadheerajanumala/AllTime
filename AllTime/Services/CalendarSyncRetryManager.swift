import Foundation
import Combine
import os.log

/// Manages retry logic for calendar sync operations with exponential backoff.
/// Prevents showing reconnect prompts for transient failures.
@MainActor
class CalendarSyncRetryManager: ObservableObject {
    static let shared = CalendarSyncRetryManager()

    private let log = OSLog(subsystem: "com.alltime.clara", category: "SYNC")
    private let diagnostics = AuthDiagnostics.shared

    // Retry configuration
    private let maxRetries = 3
    private let baseDelaySeconds: Double = 2.0  // 2, 4, 8 seconds with exponential backoff

    // Track retry state per provider
    private var retryCount: [String: Int] = [:]
    private var lastAttempt: [String: Date] = [:]
    private var isRetrying: [String: Bool] = [:]

    // Published state for UI
    @Published var isReconnectRequired: [String: Bool] = [:]
    @Published var retryStatus: [String: String] = [:]

    private init() {}

    // MARK: - Public API

    /// Attempt a sync operation with automatic retry on transient failures.
    /// Returns true if sync succeeded or was retried, false if reconnection is truly required.
    func attemptSyncWithRetry(
        provider: String,
        syncOperation: @escaping () async throws -> Void
    ) async -> Bool {
        let providerKey = provider.lowercased()

        // Reset state if last attempt was more than 10 minutes ago
        if let lastTime = lastAttempt[providerKey],
           Date().timeIntervalSince(lastTime) > 600 {
            retryCount[providerKey] = 0
            isReconnectRequired[providerKey] = false
        }

        // Check if we're already retrying
        guard isRetrying[providerKey] != true else {
            os_log("[SYNC] Already retrying %{public}@ sync, skipping duplicate attempt", log: log, type: .info, provider)
            return true
        }

        isRetrying[providerKey] = true
        lastAttempt[providerKey] = Date()

        defer {
            isRetrying[providerKey] = false
        }

        // Attempt sync with retries
        for attempt in 1...maxRetries {
            do {
                os_log("[SYNC] %{public}@ sync attempt %{public}d/%{public}d", log: log, type: .info, provider, attempt, maxRetries)
                retryStatus[providerKey] = "Syncing... (attempt \(attempt)/\(maxRetries))"

                try await syncOperation()

                // Success - reset retry count
                retryCount[providerKey] = 0
                isReconnectRequired[providerKey] = false
                retryStatus[providerKey] = nil
                diagnostics.logSyncSuccess(provider: provider, eventsCount: 0)
                os_log("[SYNC] %{public}@ sync succeeded on attempt %{public}d", log: log, type: .info, provider, attempt)
                return true

            } catch {
                retryCount[providerKey] = attempt

                // Check if this is a permanent failure (token revoked, not transient)
                if isPermamentFailure(error: error) {
                    os_log("[SYNC] %{public}@ sync failed with permanent error: %{public}@",
                           log: log, type: .error, provider, error.localizedDescription)
                    diagnostics.logSyncFailure(provider: provider, error: error.localizedDescription, isTransient: false, retryCount: attempt)
                    isReconnectRequired[providerKey] = true
                    retryStatus[providerKey] = "Reconnection required"
                    return false
                }

                // Transient failure - retry with backoff
                diagnostics.logSyncFailure(provider: provider, error: error.localizedDescription, isTransient: true, retryCount: attempt)

                if attempt < maxRetries {
                    let delay = baseDelaySeconds * pow(2.0, Double(attempt - 1))
                    os_log("[SYNC] %{public}@ sync failed (transient), retrying in %.1f seconds...",
                           log: log, type: .info, provider, delay)
                    retryStatus[providerKey] = "Retry in \(Int(delay))s..."

                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    os_log("[SYNC] %{public}@ sync failed after %{public}d attempts: %{public}@",
                           log: log, type: .error, provider, maxRetries, error.localizedDescription)
                }
            }
        }

        // All retries exhausted - check if we should show reconnect
        os_log("[SYNC] %{public}@ sync failed after all retries, checking if reconnection needed",
               log: log, type: .fault, provider)
        diagnostics.logSyncReconnectRequired(provider: provider, reason: "All retry attempts exhausted")
        isReconnectRequired[providerKey] = true
        retryStatus[providerKey] = "Reconnection required"
        return false
    }

    /// Reset retry state for a provider (call after successful reconnection)
    func resetRetryState(for provider: String) {
        let providerKey = provider.lowercased()
        retryCount[providerKey] = 0
        isReconnectRequired[providerKey] = false
        isRetrying[providerKey] = false
        retryStatus[providerKey] = nil
        lastAttempt[providerKey] = nil
        os_log("[SYNC] Reset retry state for %{public}@", log: log, type: .info, provider)
    }

    /// Check if a provider needs reconnection
    func needsReconnection(provider: String) -> Bool {
        return isReconnectRequired[provider.lowercased()] ?? false
    }

    // MARK: - Private Helpers

    /// Determine if an error is permanent (requires reconnection) vs transient (should retry)
    private func isPermamentFailure(error: Error) -> Bool {
        let errorString = error.localizedDescription.lowercased()

        // Permanent failures that require reconnection
        let permanentPatterns = [
            "token revoked",
            "token has been expired or revoked",
            "invalid_grant",
            "access_denied",
            "consent required",
            "user not authorized",
            "refresh token expired",
            "requires_reconnection"
        ]

        for pattern in permanentPatterns {
            if errorString.contains(pattern) {
                return true
            }
        }

        // Check NSError userInfo for explicit reconnection requirement
        if let nsError = error as NSError? {
            if nsError.userInfo["requires_reconnection"] as? Bool == true {
                return true
            }
            if nsError.userInfo["error_type"] as? String == "token_revoked" {
                return true
            }
        }

        // Check APIError
        if let apiError = error as? APIError {
            if apiError.code == "401_CALENDAR_REVOKED" ||
               apiError.code == "token_revoked" {
                return true
            }
        }

        // Transient failures that should be retried
        let transientPatterns = [
            "network",
            "timeout",
            "connection",
            "temporarily unavailable",
            "service unavailable",
            "rate limit",
            "too many requests",
            "internal server error",
            "bad gateway",
            "gateway timeout"
        ]

        for pattern in transientPatterns {
            if errorString.contains(pattern) {
                return false  // Transient - should retry
            }
        }

        // Default: If it's a 401 without explicit revocation, treat as transient initially
        // The backend might just be having issues
        if let nsError = error as NSError?, nsError.code == 401 {
            // Check retry count - if we've tried multiple times, it's probably permanent
            return false  // Let the retry loop exhaust before declaring permanent
        }

        // Unknown error type - assume transient for first few retries
        return false
    }
}
