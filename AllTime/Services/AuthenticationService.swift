import Foundation
import AuthenticationServices
import Combine

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService()
    private let keychainManager = KeychainManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        print("🔐 AuthenticationService: Initializing...")
        print("🔐 AuthenticationService: Backend URL: \(Constants.API.baseURL)")
        
        // Test backend connection
        Task {
            await apiService.testBackendConnection()
        }
        
        // Listen for force sign-out notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ForceSignOut"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                print("🔐 AuthenticationService: Received force sign-out notification")
                self?.signOut()
            }
        }
        
        checkExistingSession()
    }
    
    // MARK: - Session Management
    
    private func checkExistingSession() {
        print("🔐 AuthenticationService: Checking existing session...")
        
        if keychainManager.hasValidTokens() {
            print("🔐 AuthenticationService: Found stored tokens, restoring session...")
            // Try to fetch user profile to validate tokens
            Task {
                await fetchUserProfile()
            }
        } else {
            print("🔐 AuthenticationService: No stored tokens found")
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
    
    func signOut() {
        print("🔐 AuthenticationService: Signing out user...")
        
        // Clear all stored data
        _ = keychainManager.clearTokens()
        UserDefaults.standard.removeObject(forKey: "user_profile")
        
        // Reset app state
        currentUser = nil
        isAuthenticated = false
        errorMessage = nil
        
        print("🔐 AuthenticationService: User signed out successfully")
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
            } else {
                print("❌ Apple Sign-In: Failed to store tokens in Keychain")
            }
            
            // Store user profile data
            let user = authResponse.user
            if let userData = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(userData, forKey: "user_profile")
                print("🍎 Apple Sign-In: User profile stored")
            }
            
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
            
            // Preload events cache for instant wheel scrolling
            Task {
                await preloadEventsCache()
            }
            
            // Log profile completion status
            if let profileCompleted = authResponse.profileCompleted {
                print("🍎 Apple Sign-In: Profile completed: \(profileCompleted)")
            } else {
                print("🍎 Apple Sign-In: Profile completion status not provided by backend")
            }
            
            print("🍎 Apple Sign-In: Authentication successful!")
            print("🍎 Apple Sign-In: Access token expires in: \(authResponse.expiresIn) seconds")
            print("🍎 Apple Sign-In: Refresh token expires in: \(authResponse.refreshExpiresIn) seconds")
            
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
            
            // Preload events cache when restoring session
            await preloadEventsCache()
            if let profileCompleted = user.profileCompleted {
                print("🔐 AuthenticationService: Profile completed: \(profileCompleted)")
            }
        } catch {
            // If user profile fetch fails, don't sign out - just log the error
            print("🔐 AuthenticationService: Failed to fetch user profile: \(error.localizedDescription)")
            print("🔐 AuthenticationService: Keeping authentication state - user profile fetch is optional")
        }
    }
    
    // MARK: - Token Management
    
    func getAuthHeader() -> String? {
        guard let token = keychainManager.getAccessToken() else { return nil }
        return "Bearer \(token)"
    }
    
    func refreshTokenIfNeeded() async -> Bool {
        guard let refreshToken = keychainManager.getRefreshToken() else {
            print("❌ AuthenticationService: No refresh token available")
            return false
        }
        
        print("🔄 AuthenticationService: Refreshing access token...")
        
        do {
            let refreshResponse = try await apiService.refreshToken(refreshToken: refreshToken)
            
            // Store new access token
            let success = keychainManager.store(key: "access_token", value: refreshResponse.accessToken)
            
            if success {
                print("✅ AuthenticationService: Token refreshed successfully")
                return true
            } else {
                print("❌ AuthenticationService: Failed to store refreshed token")
                return false
            }
        } catch {
            print("❌ AuthenticationService: Token refresh failed: \(error.localizedDescription)")
            // If refresh fails, sign out the user
            signOut()
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