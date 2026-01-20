import Foundation
import AuthenticationServices
import Combine
import os.log

/// Auth state enum for proper state machine
enum AuthState: Equatable {
    case unknown           // Initial state - haven't checked yet
    case restoring         // Checking existing session
    case authenticated     // User is authenticated
    case unauthenticated   // No valid session
    case refreshing        // Refreshing token (for UI purposes)
}

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    // MARK: - Published State
    @Published var authState: AuthState = .unknown
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Computed properties for backward compatibility
    var isAuthenticated: Bool {
        authState == .authenticated
    }

    var isCheckingSession: Bool {
        authState == .unknown || authState == .restoring
    }

    // MARK: - Private Properties
    private let apiService = APIService()
    private let keychainManager = KeychainManager.shared
    private let diagnostics = AuthDiagnostics.shared
    private var cancellables = Set<AnyCancellable>()
    private var proactiveRefreshTask: Task<Void, Never>?
    private var foregroundRefreshTask: Task<Void, Never>?

    // Track refresh attempts to prevent infinite loops
    private var refreshAttemptCount = 0
    private let maxRefreshAttempts = 3

    // OSLog for auth operations
    private let log = OSLog(subsystem: "com.alltime.clara", category: "AUTH")

    // MARK: - Initialization

    override init() {
        super.init()
        os_log("[AUTH] Initializing AuthenticationService", log: log, type: .info)
        os_log("[AUTH] Backend URL: %{public}@", log: log, type: .info, Constants.API.baseURL)

        // Listen for force sign-out notifications (ONLY for refresh token being truly invalid)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ForceSignOut"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                let reason = (notification.userInfo?["reason"] as? String) ?? "ForceSignOut notification"
                // ONLY sign out if refresh token is confirmed invalid by the server
                // The key indicator is "401 from /auth/refresh" - meaning server rejected our refresh token
                let isRefreshTokenInvalid = reason.contains("/auth/refresh") && reason.contains("401")
                let isTokenRevoked = reason.contains("invalid_grant") || reason.contains("revoked")

                if isRefreshTokenInvalid || isTokenRevoked {
                    self?.diagnostics.logLogout(reason: reason)
                    os_log("[AUTH] Force sign-out - refresh token invalid: %{public}@", log: self?.log ?? .default, type: .fault, reason)
                    self?.signOut(reason: reason)
                } else {
                    // DON'T sign out for generic 401s - could be transient
                    os_log("[AUTH] Ignoring ForceSignOut - not a refresh token failure: %{public}@", log: self?.log ?? .default, type: .info, reason)
                }
            }
        }

        // Listen for app foreground notifications
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppForeground()
            }
        }

        // Start session restoration
        Task {
            await restoreSession()
        }
    }

    // MARK: - Apple Credential Check

    /// Check if Apple credential is still valid (not revoked)
    /// Returns true if valid, false if revoked or unknown
    private func checkAppleCredentialState() async -> Bool {
        // Get the stored Apple user identifier
        guard let appleSub = keychainManager.retrieve(key: "apple_user_id") else {
            os_log("[AUTH] No Apple user ID to verify - skipping credential check", log: log, type: .info)
            return true // Can't check, assume valid
        }

        return await withCheckedContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: appleSub) { state, error in
                if let error = error {
                    os_log("[AUTH] Apple credential state check failed: %{public}@", log: self.log, type: .error, error.localizedDescription)
                    // Can't determine state - assume valid (don't lock user out)
                    continuation.resume(returning: true)
                    return
                }

                switch state {
                case .authorized:
                    os_log("[AUTH] Apple credential: AUTHORIZED", log: self.log, type: .info)
                    continuation.resume(returning: true)
                case .revoked:
                    os_log("[AUTH] Apple credential: REVOKED - user must sign in again", log: self.log, type: .fault)
                    continuation.resume(returning: false)
                case .notFound:
                    os_log("[AUTH] Apple credential: NOT FOUND - user must sign in again", log: self.log, type: .error)
                    continuation.resume(returning: false)
                case .transferred:
                    os_log("[AUTH] Apple credential: TRANSFERRED - treating as valid", log: self.log, type: .info)
                    continuation.resume(returning: true)
                @unknown default:
                    os_log("[AUTH] Apple credential: UNKNOWN state - treating as valid", log: self.log, type: .info)
                    continuation.resume(returning: true)
                }
            }
        }
    }

    // MARK: - Session Restoration (ChatGPT-like behavior)

    /// Main entry point for session restoration
    /// This should NEVER show sign-in screen until we've exhausted all options
    /// Has a safety timeout to prevent app freeze if something goes wrong
    private func restoreSession() async {
        authState = .restoring
        diagnostics.logSessionRestoreStart()
        os_log("[AUTH] === SESSION RESTORATION STARTED ===", log: log, type: .info)

        // Safety timeout: If restoration takes more than 15 seconds, fail gracefully
        // This prevents the app from being stuck on loading screen forever
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
            if authState == .restoring {
                os_log("[AUTH] ⚠️ Session restoration timeout - failing gracefully", log: log, type: .error)
                diagnostics.logSessionRestoreComplete(success: false, reason: "Timeout after 15 seconds")

                // Try cache first
                if restoreFromCache() {
                    os_log("[AUTH] ✅ Restored from cache after timeout", log: log, type: .info)
                    authState = .authenticated
                    startProactiveTokenRefresh()
                } else if keychainManager.hasStoredTokens() && !keychainManager.isRefreshTokenExpired() {
                    // Have valid tokens but no cache - still stay authenticated
                    os_log("[AUTH] ⚠️ Timeout but have valid tokens - staying authenticated", log: log, type: .info)
                    authState = .authenticated
                    startProactiveTokenRefresh()
                } else {
                    // No tokens or refresh token expired - must sign in
                    authState = .unauthenticated
                }
            }
        }

        defer {
            timeoutTask.cancel()
        }

        // Debug: Log current token state
        let hasAccessToken = keychainManager.getAccessToken() != nil
        let hasRefreshToken = keychainManager.getRefreshToken() != nil
        let accessExpiry = keychainManager.getAccessTokenExpiry()
        let refreshExpiry = keychainManager.getRefreshTokenExpiry()
        os_log("[AUTH] Token state: access=%{public}@, refresh=%{public}@", log: log, type: .info,
               hasAccessToken ? "present" : "missing",
               hasRefreshToken ? "present" : "missing")
        if let accessExpiry = accessExpiry {
            os_log("[AUTH] Access token expiry: %{public}@ (in %{public}.0f seconds)", log: log, type: .info,
                   accessExpiry.description, accessExpiry.timeIntervalSinceNow)
        } else {
            os_log("[AUTH] Access token expiry: NOT STORED (will assume expired)", log: log, type: .info)
        }
        if let refreshExpiry = refreshExpiry {
            os_log("[AUTH] Refresh token expiry: %{public}@ (in %{public}.0f seconds)", log: log, type: .info,
                   refreshExpiry.description, refreshExpiry.timeIntervalSinceNow)
        } else {
            os_log("[AUTH] Refresh token expiry: NOT STORED (will assume valid)", log: log, type: .info)
        }

        // Step 1: Check if we have stored tokens
        guard keychainManager.hasStoredTokens() else {
            os_log("[AUTH] No stored tokens found - user needs to sign in", log: log, type: .info)
            diagnostics.logSessionRestoreComplete(success: false, reason: "No tokens in keychain")
            authState = .unauthenticated
            return
        }

        // Step 1.5: Check if Apple credential has been revoked
        // This runs in parallel with other checks for efficiency
        let isAppleCredentialValid = await checkAppleCredentialState()
        if !isAppleCredentialValid {
            os_log("[AUTH] Apple credential revoked/not found - user needs to sign in", log: log, type: .fault)
            diagnostics.logSessionRestoreComplete(success: false, reason: "Apple credential revoked")
            _ = keychainManager.clearTokens()
            authState = .unauthenticated
            return
        }

        // Step 2: Check if refresh token is expired (definitive failure)
        if keychainManager.isRefreshTokenExpired() {
            os_log("[AUTH] Refresh token is expired - user needs to sign in", log: log, type: .error)
            diagnostics.logSessionRestoreComplete(success: false, reason: "Refresh token expired")
            // Clear invalid tokens
            _ = keychainManager.clearTokens()
            authState = .unauthenticated
            return
        }

        // Step 3: If access token is expired/near expiry, refresh first
        let accessTokenExpired = keychainManager.isAccessTokenExpired(buffer: 300)
        os_log("[AUTH] Access token status: %{public}@", log: log, type: .info,
               accessTokenExpired ? "EXPIRED/EXPIRING" : "VALID")

        if accessTokenExpired {
            os_log("[AUTH] Access token expired/expiring - refreshing before validation", log: log, type: .info)

            let refreshed = await silentRefresh()
            if !refreshed {
                // Refresh failed - but DON'T sign out!
                // We have tokens, so stay authenticated and retry later
                os_log("[AUTH] Silent refresh failed - staying authenticated anyway", log: log, type: .error)

                // Try to use cached profile
                if restoreFromCache() {
                    os_log("[AUTH] ✅ Restored from cache despite refresh failure", log: log, type: .info)
                    diagnostics.logSessionRestoreComplete(success: true, reason: "Restored from cache (offline mode)")
                } else {
                    os_log("[AUTH] ⚠️ No cache but have tokens - staying authenticated", log: log, type: .info)
                    diagnostics.logSessionRestoreComplete(success: true, reason: "Have tokens, no cache (limited mode)")
                }

                // ALWAYS stay authenticated if we have tokens - refresh will retry on next API call
                authState = .authenticated
                startProactiveTokenRefresh()
                return
            }
        }

        // Step 4: Validate session by fetching profile
        os_log("[AUTH] Validating session with profile fetch...", log: log, type: .info)

        do {
            let user = try await apiService.fetchUserProfile()
            currentUser = user
            UserDefaults.standard.set(user.id, forKey: "userId")

            // Cache user profile for offline restoration
            if let userData = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(userData, forKey: "user_profile")
            }

            // Cache first name for personalization
            if let fullName = user.fullName, !fullName.isEmpty {
                let firstName = fullName.components(separatedBy: " ").first ?? fullName
                UserDefaults.standard.set(firstName, forKey: "user_first_name")
            }

            os_log("[AUTH] ✅ Session restored successfully for user: %{public}d", log: log, type: .info, user.id)
            diagnostics.logSessionRestoreComplete(success: true)
            authState = .authenticated

            // Start background tasks
            startProactiveTokenRefresh()
            await preloadCaches()

            // Process any pending deep links
            NavigationManager.shared.processPendingDestination()

        } catch {
            os_log("[AUTH] Profile fetch failed: %{public}@", log: log, type: .error, error.localizedDescription)

            // Determine if this is a transient error or a genuine auth failure
            let isAuthError = isAuthenticationError(error)

            if isAuthError {
                os_log("[AUTH] Auth error during profile fetch - attempting refresh", log: log, type: .error)

                let refreshed = await silentRefresh()
                if refreshed {
                    // Retry profile fetch after refresh
                    do {
                        let user = try await apiService.fetchUserProfile()
                        currentUser = user
                        UserDefaults.standard.set(user.id, forKey: "userId")
                        if let userData = try? JSONEncoder().encode(user) {
                            UserDefaults.standard.set(userData, forKey: "user_profile")
                        }
                        os_log("[AUTH] ✅ Session restored after token refresh", log: log, type: .info)
                        diagnostics.logSessionRestoreComplete(success: true)
                        authState = .authenticated
                        startProactiveTokenRefresh()
                        await preloadCaches()
                        return
                    } catch {
                        os_log("[AUTH] Profile fetch failed even after refresh", log: log, type: .error)
                    }
                }

                // Last resort: try cache
                if restoreFromCache() {
                    os_log("[AUTH] ✅ Restored from cache after auth error", log: log, type: .info)
                    diagnostics.logSessionRestoreComplete(success: true, reason: "Restored from cache")
                    authState = .authenticated
                    startProactiveTokenRefresh()
                    return
                }

                // Still have tokens? Stay authenticated - this could be a transient issue
                if keychainManager.hasStoredTokens() && !keychainManager.isRefreshTokenExpired() {
                    os_log("[AUTH] ⚠️ Auth error but tokens still valid - staying authenticated", log: log, type: .info)
                    diagnostics.logSessionRestoreComplete(success: true, reason: "Have valid tokens despite error")
                    authState = .authenticated
                    startProactiveTokenRefresh()
                    return
                }

                // Only sign out if refresh token is definitely expired/invalid
                os_log("[AUTH] ❌ Refresh token expired - user needs to sign in", log: log, type: .error)
                diagnostics.logSessionRestoreComplete(success: false, reason: "Refresh token expired")
                authState = .unauthenticated
            } else {
                // Transient error (network, etc.) - stay authenticated if we have cache
                os_log("[AUTH] Transient error during profile fetch - using cache", log: log, type: .info)

                if restoreFromCache() {
                    os_log("[AUTH] ✅ Using cached profile (transient error)", log: log, type: .info)
                    diagnostics.logSessionRestoreComplete(success: true, reason: "Cached profile (offline)")
                    authState = .authenticated
                    startProactiveTokenRefresh()
                } else {
                    // No cache but we have tokens - stay authenticated in limited mode
                    os_log("[AUTH] ⚠️ No cache but have tokens - authenticated in limited mode", log: log, type: .info)
                    diagnostics.logSessionRestoreComplete(success: true, reason: "Limited mode (no cache)")
                    authState = .authenticated
                    startProactiveTokenRefresh()
                }
            }
        }
    }

    /// Restore user from cached profile
    private func restoreFromCache() -> Bool {
        guard let userData = UserDefaults.standard.data(forKey: "user_profile"),
              let cachedUser = try? JSONDecoder().decode(User.self, from: userData) else {
            return false
        }
        currentUser = cachedUser
        UserDefaults.standard.set(cachedUser.id, forKey: "userId")
        return true
    }

    /// Determine if an error is an authentication error (401) vs transient error
    private func isAuthenticationError(_ error: Error) -> Bool {
        if let nsError = error as NSError?, nsError.code == 401 {
            return true
        }
        if let apiError = error as? APIError, apiError.code == "401" || apiError.code == "401_REFRESHED" {
            return true
        }
        let description = error.localizedDescription.lowercased()
        // Check for various auth error messages
        return description.contains("401") ||
               description.contains("unauthorized") ||
               description.contains("authentication") ||
               description.contains("invalid") && description.contains("token") ||
               description.contains("expired") && description.contains("token") ||
               description.contains("token expired") ||
               description.contains("invalid token") ||
               description.contains("no access token")
    }

    // MARK: - Foreground Refresh

    /// Called when app comes to foreground - ensures tokens are valid
    private func handleAppForeground() async {
        guard authState == .authenticated else { return }

        os_log("[AUTH] App foreground - checking token validity", log: log, type: .info)

        // If access token is expired or expiring soon, refresh immediately
        if keychainManager.isAccessTokenExpired(buffer: 600) { // 10 min buffer for foreground
            os_log("[AUTH] Access token expired/expiring - refreshing on foreground", log: log, type: .info)
            let refreshed = await silentRefresh()
            if !refreshed {
                os_log("[AUTH] ⚠️ Foreground refresh failed - will retry on next API call", log: log, type: .error)
                // Don't sign out - just log the issue
            }
        }
    }

    // MARK: - Silent Token Refresh

    /// Silently refresh the access token using the refresh token
    /// Returns true if successful, false otherwise
    /// NEVER triggers sign-out - only returns success/failure
    private func silentRefresh() async -> Bool {
        guard let refreshToken = keychainManager.getRefreshToken() else {
            os_log("[AUTH] Silent refresh failed - no refresh token", log: log, type: .error)
            return false
        }

        // Check if we've exceeded retry attempts
        refreshAttemptCount += 1
        if refreshAttemptCount > maxRefreshAttempts {
            os_log("[AUTH] Silent refresh failed - max attempts exceeded", log: log, type: .error)
            refreshAttemptCount = 0 // Reset for next session
            return false
        }

        diagnostics.logTokenRefreshAttempt()
        os_log("[AUTH] Attempting silent refresh (attempt %{public}d/%{public}d)", log: log, type: .info, refreshAttemptCount, maxRefreshAttempts)

        do {
            let refreshResponse = try await apiService.refreshToken(refreshToken: refreshToken)

            // Store new access token
            let expiresIn = refreshResponse.expiresIn ?? 3600
            let success = keychainManager.updateAccessToken(refreshResponse.accessToken, expiresIn: expiresIn)

            // Also update refresh token if rotated
            if let newRefreshToken = refreshResponse.refreshToken {
                // Use server-provided expiry, or default to 1 year (31536000 seconds)
                // CRITICAL: Don't use short expiry like 7 days - backend provides 1 year refresh tokens
                let refreshExpiresIn = refreshResponse.refreshExpiresIn ?? 31536000
                _ = keychainManager.updateRefreshToken(newRefreshToken, expiresIn: refreshExpiresIn)
                os_log("[AUTH] Refresh token also rotated (expires in %{public}d seconds)", log: log, type: .info, refreshExpiresIn)
            }

            if success {
                refreshAttemptCount = 0 // Reset on success
                diagnostics.logTokenRefreshSuccess(expiresIn: expiresIn)
                os_log("[AUTH] ✅ Silent refresh successful - token expires in %{public}d seconds", log: log, type: .info, expiresIn)
                return true
            } else {
                os_log("[AUTH] Silent refresh - failed to store token in keychain", log: log, type: .error)
                return false
            }
        } catch {
            let errorDesc = error.localizedDescription.lowercased()
            os_log("[AUTH] Silent refresh failed: %{public}@", log: log, type: .error, error.localizedDescription)
            diagnostics.logTokenRefreshFailure(reason: error.localizedDescription)

            // Extract server error message if available (added by APIService for 401s)
            var serverError = ""
            if let nsError = error as NSError? {
                os_log("[AUTH] Error code: %{public}d, domain: %{public}@", log: log, type: .error,
                       nsError.code, nsError.domain)
                if let serverErrorMsg = nsError.userInfo["serverError"] as? String {
                    serverError = serverErrorMsg.lowercased()
                    os_log("[AUTH] Server error: %{public}@", log: log, type: .error, serverErrorMsg)
                }
            }

            // Check if this is a definitive failure (refresh token is DEFINITELY invalid/revoked)
            // Check BOTH the localized description AND the raw server error
            let isExplicitRejection = errorDesc.contains("invalid_grant") ||
                                       errorDesc.contains("revoked") ||
                                       errorDesc.contains("refresh token") && errorDesc.contains("invalid") ||
                                       errorDesc.contains("token has been revoked") ||
                                       serverError.contains("invalid refresh token") ||
                                       serverError.contains("invalid_grant") ||
                                       serverError.contains("token revoked")

            // Note: Generic "invalid token" or "expired token" messages could be about access token, not refresh token
            // So we DON'T clear tokens for those - we'll retry on next API call

            if isExplicitRejection {
                os_log("[AUTH] ❌ Refresh token explicitly rejected by server - clearing tokens", log: log, type: .fault)
                refreshAttemptCount = 0
                // Clear the invalid tokens so user can sign in fresh
                _ = keychainManager.clearTokens()
                return false
            }

            // For generic 401s or other errors, DON'T clear tokens
            // The user may still have a valid session - we'll retry later
            os_log("[AUTH] ⚠️ Refresh failed but not definitively - keeping tokens, will retry", log: log, type: .info)

            // Transient error - don't count against retries if it's network-related
            if errorDesc.contains("network") || errorDesc.contains("connection") || errorDesc.contains("timeout") {
                refreshAttemptCount -= 1 // Don't penalize for network errors
                os_log("[AUTH] Transient network error - will retry", log: log, type: .info)
            }

            return false
        }
    }

    // MARK: - Proactive Token Refresh

    private func startProactiveTokenRefresh() {
        proactiveRefreshTask?.cancel()

        proactiveRefreshTask = Task {
            while !Task.isCancelled && authState == .authenticated {
                // Check every 60 seconds
                try? await Task.sleep(nanoseconds: 60_000_000_000)

                guard !Task.isCancelled else { break }

                // Refresh if token expires within 5 minutes
                if keychainManager.isAccessTokenExpired(buffer: 300) {
                    os_log("[AUTH] Proactive refresh - token expiring soon", log: log, type: .info)
                    let _ = await silentRefresh()
                }
            }
        }
    }

    // MARK: - Sign In

    func signInWithApple() {
        os_log("[AUTH] Starting Apple Sign-In", log: log, type: .info)
        isLoading = true
        errorMessage = nil

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    func handleAppleSignInSuccess(identityToken: String, authorizationCode: String?, userIdentifier: String, email: String?, fullName: PersonNameComponents?) async {
        os_log("[AUTH] Processing Apple Sign-In success", log: log, type: .info)

        do {
            let authResponse = try await apiService.signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                userIdentifier: userIdentifier,
                email: email,
                fullName: fullName
            )

            // Store tokens with expiry metadata
            let tokenStored = keychainManager.storeTokens(
                accessToken: authResponse.accessToken,
                refreshToken: authResponse.refreshToken,
                accessExpiresIn: authResponse.expiresIn,
                refreshExpiresIn: authResponse.refreshExpiresIn
            )

            if !tokenStored {
                os_log("[AUTH] ⚠️ Token storage failed - retrying", log: log, type: .error)
                _ = keychainManager.clearTokens()
                let retryStored = keychainManager.storeTokens(
                    accessToken: authResponse.accessToken,
                    refreshToken: authResponse.refreshToken,
                    accessExpiresIn: authResponse.expiresIn,
                    refreshExpiresIn: authResponse.refreshExpiresIn
                )
                if !retryStored {
                    throw NSError(domain: "AllTime", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to securely store tokens. Please try again."
                    ])
                }
            }

            // Store Apple user identifier for credential revocation checks
            _ = keychainManager.store(key: "apple_user_id", value: userIdentifier)

            // Store user profile
            let user = authResponse.user
            if let userData = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(userData, forKey: "user_profile")
            }
            UserDefaults.standard.set(user.id, forKey: "userId")

            // Cache first name
            if let fullName = user.fullName, !fullName.isEmpty {
                let firstName = fullName.components(separatedBy: " ").first ?? fullName
                UserDefaults.standard.set(firstName, forKey: "user_first_name")
            }

            // Update state
            let finalProfileCompleted = authResponse.profileCompleted ?? user.profileCompleted
            currentUser = User(
                id: user.id,
                email: user.email,
                fullName: user.fullName,
                createdAt: user.createdAt,
                profilePictureUrl: user.profilePictureUrl,
                profileCompleted: finalProfileCompleted,
                dateOfBirth: user.dateOfBirth,
                gender: user.gender,
                location: user.location,
                bio: user.bio,
                phoneNumber: user.phoneNumber
            )

            authState = .authenticated
            isLoading = false
            refreshAttemptCount = 0

            // Log and start background tasks
            diagnostics.logLoginSuccess(expiresIn: authResponse.expiresIn)
            os_log("[AUTH] ✅ Sign-in successful - token expires in %{public}d seconds", log: log, type: .info, authResponse.expiresIn)

            startProactiveTokenRefresh()
            await preloadCaches()
            NavigationManager.shared.processPendingDestination()

        } catch {
            os_log("[AUTH] Sign-in failed: %{public}@", log: log, type: .error, error.localizedDescription)
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Sign Out

    func signOut(reason: String = "User initiated", file: String = #file, line: Int = #line) {
        os_log("[AUTH] Signing out - reason: %{public}@", log: log, type: .info, reason)
        diagnostics.logLogout(reason: reason, file: file, line: line)

        // Stop background tasks
        proactiveRefreshTask?.cancel()
        proactiveRefreshTask = nil
        foregroundRefreshTask?.cancel()
        foregroundRefreshTask = nil

        // Clear ALL stored data
        _ = keychainManager.clearTokens()
        _ = keychainManager.delete(key: "apple_user_id")
        UserDefaults.standard.removeObject(forKey: "user_profile")
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "user_first_name")

        // Reset state
        currentUser = nil
        authState = .unauthenticated
        errorMessage = nil
        refreshAttemptCount = 0

        os_log("[AUTH] Sign-out complete", log: log, type: .info)
    }

    // MARK: - Token Management (for API calls)

    func getAuthHeader() -> String? {
        guard let token = keychainManager.getAccessToken() else { return nil }
        return "Bearer \(token)"
    }

    /// Public method for manual token refresh (used by APIService)
    func refreshTokenIfNeeded() async -> Bool {
        return await silentRefresh()
    }

    // MARK: - Cache Preloading

    private func preloadCaches() async {
        os_log("[AUTH] Preloading caches", log: log, type: .info)

        do {
            let response = try await apiService.getUpcomingEvents(days: 60)
            EventCacheManager.shared.saveEvents(response.events, daysFetched: 60)
            os_log("[AUTH] ✅ Preloaded %{public}d events", log: log, type: .info, response.events.count)
        } catch {
            os_log("[AUTH] ⚠️ Cache preload failed (will load on demand): %{public}@", log: log, type: .info, error.localizedDescription)
        }

        await InsightsPrefetchService.shared.prefetchAllInsights()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
           let identityToken = credential.identityToken,
           let tokenString = String(data: identityToken, encoding: .utf8) {

            let authorizationCode = credential.authorizationCode != nil ? String(data: credential.authorizationCode!, encoding: .utf8) : nil

            Task {
                await handleAppleSignInSuccess(
                    identityToken: tokenString,
                    authorizationCode: authorizationCode,
                    userIdentifier: credential.user,
                    email: credential.email,
                    fullName: credential.fullName
                )
            }
        } else {
            errorMessage = "Failed to retrieve Apple identity token"
            isLoading = false
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        errorMessage = error.localizedDescription
        isLoading = false
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return ASPresentationAnchor(windowScene: windowScene)
        }
        fatalError("Unable to find window scene for presentation anchor")
    }
}
