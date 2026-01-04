import Foundation
import AuthenticationServices
import Combine
import os.log

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isCheckingSession = true  // True while checking existing session on app launch

    private let apiService = APIService()
    private let keychainManager = KeychainManager.shared
    private let diagnostics = AuthDiagnostics.shared
    private var cancellables = Set<AnyCancellable>()
    private var proactiveRefreshTask: Task<Void, Never>?

    // OSLog for auth operations
    private let log = OSLog(subsystem: "com.alltime.clara", category: "AUTH")

    override init() {
        super.init()
        os_log("[AUTH] Initializing AuthenticationService, Backend URL: %{public}@", log: log, type: .info, Constants.API.baseURL)

        // Test backend connection
        Task {
            await apiService.testBackendConnection()
        }

        // Listen for force sign-out notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ForceSignOut"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                let reason = (notification.userInfo?["reason"] as? String) ?? "ForceSignOut notification"
                self?.diagnostics.logLogout(reason: reason)
                os_log("[AUTH] Force sign-out triggered: %{public}@", log: self?.log ?? .default, type: .fault, reason)
                self?.signOut()
            }
        }

        checkExistingSession()
    }
    
    // MARK: - Session Management

    private func checkExistingSession() {
        os_log("[AUTH] Checking existing session...", log: log, type: .info)
        diagnostics.logSessionRestoreStart()

        if keychainManager.hasValidTokens() {
            os_log("[AUTH] Found stored tokens, restoring session...", log: log, type: .info)
            // Try to fetch user profile to validate tokens
            Task {
                await fetchUserProfile()
                isCheckingSession = false

                if isAuthenticated {
                    diagnostics.logSessionRestoreComplete(success: true)
                    // Start proactive token refresh
                    startProactiveTokenRefresh()
                } else {
                    diagnostics.logSessionRestoreComplete(success: false, reason: "Profile fetch failed")
                }
            }
        } else {
            os_log("[AUTH] No stored tokens found", log: log, type: .info)
            diagnostics.logSessionRestoreComplete(success: false, reason: "No tokens in keychain")
            isCheckingSession = false
        }
    }

    /// Proactively refresh token before it expires (5 minutes before expiry)
    private func startProactiveTokenRefresh() {
        proactiveRefreshTask?.cancel()

        proactiveRefreshTask = Task {
            while !Task.isCancelled && isAuthenticated {
                // Check token expiry every 60 seconds
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds

                guard !Task.isCancelled else { break }

                // Refresh if token expires within 5 minutes
                if diagnostics.tokenExpiresWithin(seconds: 300) {
                    os_log("[AUTH] Token expires soon, proactively refreshing...", log: log, type: .info)
                    diagnostics.logTokenRefreshAttempt()

                    let success = await refreshTokenIfNeeded()
                    if success {
                        os_log("[AUTH] Proactive token refresh succeeded", log: log, type: .info)
                    } else {
                        os_log("[AUTH] Proactive token refresh failed", log: log, type: .error)
                    }
                }
            }
        }
    }
    
    func signInWithApple() {
        print("🍎 AuthenticationService: Starting Apple Sign-In...")
        isLoading = true
        errorMessage = nil
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func signOut(reason: String = "User initiated", file: String = #file, line: Int = #line) {
        os_log("[AUTH] Signing out user, reason: %{public}@", log: log, type: .info, reason)
        diagnostics.logLogout(reason: reason, file: file, line: line)

        // Stop proactive refresh
        proactiveRefreshTask?.cancel()
        proactiveRefreshTask = nil

        // Clear all stored data
        _ = keychainManager.clearTokens()
        UserDefaults.standard.removeObject(forKey: "user_profile")
        UserDefaults.standard.removeObject(forKey: "userId")

        // Reset app state
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil

        os_log("[AUTH] User signed out successfully", log: log, type: .info)
    }
    
    // MARK: - Backend Communication
    
    func handleAppleSignInSuccess(identityToken: String, authorizationCode: String?, userIdentifier: String, email: String?, fullName: PersonNameComponents?) async {
        print("🍎 Apple Sign-In: Starting authentication process...")
        
        do {
            print("🍎 Apple Sign-In: Calling backend API...")
            let authResponse = try await apiService.signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                userIdentifier: userIdentifier,
                email: email,
                fullName: fullName
            )
            print("🍎 Apple Sign-In: Backend response received successfully")
            
            // Store tokens securely in Keychain
            let tokenStored = keychainManager.storeTokens(
                accessToken: authResponse.accessToken,
                refreshToken: authResponse.refreshToken
            )

            if tokenStored {
                print("🍎 Apple Sign-In: Tokens stored securely in Keychain")

                // CRITICAL: Verify tokens were actually stored by reading them back
                let verifyAccess = keychainManager.getAccessToken()
                let verifyRefresh = keychainManager.getRefreshToken()

                if verifyAccess != nil && verifyRefresh != nil {
                    print("✅ Apple Sign-In: Token verification passed - both tokens readable from Keychain")
                } else {
                    print("❌ Apple Sign-In: Token verification FAILED!")
                    print("   - Access token readable: \(verifyAccess != nil)")
                    print("   - Refresh token readable: \(verifyRefresh != nil)")
                    // Retry storage once
                    let retryStored = keychainManager.storeTokens(
                        accessToken: authResponse.accessToken,
                        refreshToken: authResponse.refreshToken
                    )
                    print("   - Retry storage result: \(retryStored)")
                }
            } else {
                print("❌ Apple Sign-In: Failed to store tokens in Keychain - retrying...")
                // Retry once with a clear first
                _ = keychainManager.clearTokens()
                let retryStored = keychainManager.storeTokens(
                    accessToken: authResponse.accessToken,
                    refreshToken: authResponse.refreshToken
                )
                if retryStored {
                    print("✅ Apple Sign-In: Tokens stored on retry")
                } else {
                    print("❌ Apple Sign-In: CRITICAL - Tokens could not be stored even after retry!")
                    throw NSError(domain: "AllTime", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to securely store authentication tokens. Please try again."
                    ])
                }
            }
            
            // Store user profile data
            let user = authResponse.user
            if let userData = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(userData, forKey: "user_profile")
                print("🍎 Apple Sign-In: User profile stored")
            }

            // Store userId separately for services that need quick access
            UserDefaults.standard.set(user.id, forKey: "userId")
            print("🍎 Apple Sign-In: User ID (\(user.id)) stored")
            
            // Update user with profileCompleted from response
            // Prefer top-level profileCompleted, fallback to user.profileCompleted
            let finalProfileCompleted = authResponse.profileCompleted ?? user.profileCompleted
            
            // Create updated user with profileCompleted
            // Preserve createdAt from original user if available
            let updatedUser = User(
                id: user.id,
                email: user.email,
                fullName: user.fullName,
                createdAt: user.createdAt, // Preserve from original user
                profilePictureUrl: user.profilePictureUrl,
                profileCompleted: finalProfileCompleted,
                dateOfBirth: user.dateOfBirth,
                gender: user.gender,
                location: user.location,
                bio: user.bio,
                phoneNumber: user.phoneNumber
            )
            currentUser = updatedUser
            
            // Set authentication state
            isAuthenticated = true
            isLoading = false

            // Log successful login with diagnostics
            diagnostics.logLoginSuccess(expiresIn: authResponse.expiresIn)
            os_log("[AUTH] Login successful - token expires in %{public}d seconds", log: log, type: .info, authResponse.expiresIn)

            // Start proactive token refresh
            startProactiveTokenRefresh()

            // Preload caches for instant UI
            Task {
                await preloadEventsCache()
                await InsightsPrefetchService.shared.prefetchAllInsights()
            }

            // Process any pending deep link destination (e.g., from notification tap)
            NavigationManager.shared.processPendingDestination()

            // Log profile completion status
            if let profileCompleted = authResponse.profileCompleted {
                os_log("[AUTH] Profile completed: %{public}@", log: log, type: .info, profileCompleted ? "true" : "false")
            }

            os_log("[AUTH] Authentication successful! Access token expires in %{public}d seconds, Refresh token expires in %{public}d seconds",
                   log: log, type: .info, authResponse.expiresIn, authResponse.refreshExpiresIn)
            
        } catch {
            print("🍎 Apple Sign-In: Error occurred: \(error.localizedDescription)")
            print("🍎 Apple Sign-In: Full error details: \(error)")
            
            // Extract the actual error message
            if let apiError = error as? APIError {
                let backendMessage = apiError.message
                print("🍎 Apple Sign-In: Backend error message: \(backendMessage)")
                
                // Check if it's a database migration error
                if backendMessage.contains("column") && backendMessage.contains("does not exist") {
                    errorMessage = "Backend database is being updated. Please wait a few minutes and try again.\n\nIf this persists, contact support."
                } else {
                    // Show a cleaner version of the backend error
                    // Remove technical SQL details for user-facing messages
                    let cleanMessage = backendMessage
                        .replacingOccurrences(of: "JDBC exception executing SQL", with: "")
                        .replacingOccurrences(of: "\\[.*?\\]", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    errorMessage = cleanMessage.isEmpty ? backendMessage : cleanMessage
                }
            } else {
                // Show the actual error description
                errorMessage = error.localizedDescription
                print("🍎 Apple Sign-In: System error: \(error.localizedDescription)")
            }
            
            isLoading = false
        }
    }
    
    // MARK: - Cache Preloading
    
    /// Preload events cache on sign-in for instant wheel scrolling
    private func preloadEventsCache() async {
        print("💾 AuthenticationService: Preloading events cache for instant access...")
        
        do {
            // Fetch events in background (non-blocking)
            let response = try await apiService.getUpcomingEvents(days: 60) // Load 60 days for good coverage
            
            // Save to cache immediately
            EventCacheManager.shared.saveEvents(response.events, daysFetched: 60)
            
            print("💾 AuthenticationService: ✅ Preloaded \(response.events.count) events to cache")
        } catch {
            // Silently fail - cache will be loaded on first access
            print("⚠️ AuthenticationService: Cache preload failed (will load on first access): \(error.localizedDescription)")
        }
    }
    
    private func fetchUserProfile() async {
        do {
            let user = try await apiService.fetchUserProfile()
            currentUser = user
            isAuthenticated = true
            print("🔐 AuthenticationService: User profile fetched successfully")

            // Store userId for services that need quick access (in case it wasn't stored before)
            UserDefaults.standard.set(user.id, forKey: "userId")
            print("🔐 AuthenticationService: User ID (\(user.id)) stored")

            // Preload caches when restoring session
            await preloadEventsCache()
            await InsightsPrefetchService.shared.prefetchAllInsights()
            if let profileCompleted = user.profileCompleted {
                print("🔐 AuthenticationService: Profile completed: \(profileCompleted)")
            }
        } catch {
            // Check if this is a 401 error (tokens are invalid)
            // Handle both NSError and APIError cases
            let is401Error: Bool
            if let nsError = error as NSError?, nsError.code == 401 {
                is401Error = true
            } else if let apiError = error as? APIError, apiError.code == "401" {
                is401Error = true
            } else if error.localizedDescription.contains("401") || error.localizedDescription.contains("Unauthorized") {
                is401Error = true
            } else {
                is401Error = false
            }

            if is401Error {
                print("🔐 AuthenticationService: User profile fetch failed with 401 - access token may be expired")
                print("🔐 AuthenticationService: Attempting to refresh token...")

                // Try to refresh the token before signing out
                let refreshSuccess = await refreshTokenIfNeeded()

                if refreshSuccess {
                    print("🔐 AuthenticationService: Token refreshed successfully, retrying profile fetch...")
                    // Retry fetching profile with the new token
                    do {
                        let user = try await apiService.fetchUserProfile()
                        currentUser = user
                        isAuthenticated = true
                        UserDefaults.standard.set(user.id, forKey: "userId")
                        print("🔐 AuthenticationService: User profile fetched successfully after token refresh")

                        // Preload caches
                        await preloadEventsCache()
                        await InsightsPrefetchService.shared.prefetchAllInsights()
                        return
                    } catch {
                        print("🔐 AuthenticationService: Profile fetch failed even after token refresh: \(error.localizedDescription)")
                        // Fall through to use cached profile
                    }
                } else {
                    print("🔐 AuthenticationService: Token refresh failed - refresh token may be expired")
                }

                // If refresh failed or retry failed, try to use cached profile before signing out
                if let userData = UserDefaults.standard.data(forKey: "user_profile"),
                   let cachedUser = try? JSONDecoder().decode(User.self, from: userData),
                   keychainManager.hasValidTokens() {
                    // We have cached profile and tokens exist - stay logged in but warn
                    currentUser = cachedUser
                    isAuthenticated = true
                    print("🔐 AuthenticationService: Using cached user profile (ID: \(cachedUser.id)) - token refresh failed but staying logged in")
                    print("⚠️ AuthenticationService: Next API call will trigger another refresh attempt")
                } else {
                    // No cached profile or no tokens - must sign out
                    print("🔐 AuthenticationService: No cached profile available - signing out...")
                    signOut()
                }
            } else {
                // For other errors (network, server issues), keep user authenticated
                // They have valid tokens, just couldn't fetch profile right now
                print("🔐 AuthenticationService: Failed to fetch user profile: \(error.localizedDescription)")
                print("🔐 AuthenticationService: Keeping user authenticated - profile fetch is optional")
                isAuthenticated = true

                // Try to load cached user profile from UserDefaults
                if let userData = UserDefaults.standard.data(forKey: "user_profile"),
                   let cachedUser = try? JSONDecoder().decode(User.self, from: userData) {
                    currentUser = cachedUser
                    print("🔐 AuthenticationService: Using cached user profile (ID: \(cachedUser.id))")
                }
            }
        }
    }
    
    // MARK: - Token Management
    
    func getAuthHeader() -> String? {
        guard let token = keychainManager.getAccessToken() else { return nil }
        return "Bearer \(token)"
    }
    
    func refreshTokenIfNeeded() async -> Bool {
        diagnostics.logTokenRefreshAttempt()

        guard let refreshToken = keychainManager.getRefreshToken() else {
            os_log("[AUTH] No refresh token available for refresh", log: log, type: .error)
            diagnostics.logTokenRefreshFailure(reason: "No refresh token in keychain")
            return false
        }

        os_log("[AUTH] Refreshing access token...", log: log, type: .info)

        do {
            let refreshResponse = try await apiService.refreshToken(refreshToken: refreshToken)

            // Store new access token
            let success = keychainManager.store(key: "access_token", value: refreshResponse.accessToken)

            // Also store new refresh token if provided
            if let newRefreshToken = refreshResponse.refreshToken {
                _ = keychainManager.store(key: "refresh_token", value: newRefreshToken)
                os_log("[AUTH] New refresh token also stored", log: log, type: .info)
            }

            if success {
                // Get expiry from response if available, default to 24 hours
                let expiresIn = refreshResponse.expiresIn ?? 86400
                diagnostics.logTokenRefreshSuccess(expiresIn: expiresIn)
                os_log("[AUTH] Token refreshed successfully, expires in %{public}d seconds", log: log, type: .info, expiresIn)
                return true
            } else {
                os_log("[AUTH] Failed to store refreshed token in keychain", log: log, type: .error)
                diagnostics.logTokenRefreshFailure(reason: "Keychain store failed")
                return false
            }
        } catch {
            os_log("[AUTH] Token refresh failed: %{public}@", log: log, type: .error, error.localizedDescription)
            diagnostics.logTokenRefreshFailure(reason: error.localizedDescription)
            // Don't sign out here - let the caller decide based on context
            // The caller (fetchUserProfile) will handle sign out if needed
            return false
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
           let identityToken = credential.identityToken,
           let tokenString = String(data: identityToken, encoding: .utf8) {
            
            let authorizationCode = credential.authorizationCode != nil ? String(data: credential.authorizationCode!, encoding: .utf8) : nil
            let userIdentifier = credential.user
            let email = credential.email
            let fullName = credential.fullName
            
            Task {
                await handleAppleSignInSuccess(
                    identityToken: tokenString,
                    authorizationCode: authorizationCode,
                    userIdentifier: userIdentifier,
                    email: email,
                    fullName: fullName
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
        // Fallback for iOS 26+ - use windowScene initializer
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return ASPresentationAnchor(windowScene: windowScene)
        }
        // This should never be reached, but if it is, we need to handle it gracefully
        fatalError("Unable to find window scene for presentation anchor")
    }
}