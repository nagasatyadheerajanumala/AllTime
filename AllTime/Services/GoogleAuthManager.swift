import AuthenticationServices
import SwiftUI
import Combine

@MainActor
class GoogleAuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleAuthManager()

    @Published var isAuthenticating = false
    @Published var isConnected = false
    @Published var errorMessage: String?

    private var session: ASWebAuthenticationSession?
    private let apiService = APIService()

    private override init() {
        super.init()
    }

    func startGoogleOAuth() {
        print("🔗 GoogleAuthManager: ===== STARTING GOOGLE OAUTH =====")

        isAuthenticating = true
        errorMessage = nil

        // Check if we have a valid access token
        guard let accessToken = KeychainManager.shared.getAccessToken(), !accessToken.isEmpty else {
            print("❌ GoogleAuthManager: No access token found!")
            print("❌ GoogleAuthManager: User must sign in with Apple first")
            errorMessage = "Please sign in with Apple first"
            isAuthenticating = false
            return
        }

        print("🔗 GoogleAuthManager: Access Token: \(accessToken.prefix(20))...")

        // Step 1: Call backend API to get OAuth URL
        Task {
            do {
                print("🔗 GoogleAuthManager: Fetching OAuth URL from backend...")
                let authorizationURL = try await apiService.getGoogleOAuthStartURL()

                print("🔗 GoogleAuthManager: ===== OAUTH URL FROM BACKEND =====")
                print("🔗 GoogleAuthManager: OAuth URL: \(authorizationURL)")

                // Extract and log state parameter for debugging
                if let url = URL(string: authorizationURL),
                   let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let stateParam = components.queryItems?.first(where: { $0.name == "state" })?.value {
                    print("🔗 GoogleAuthManager: State parameter: \(stateParam)")
                } else {
                    print("⚠️ GoogleAuthManager: No state parameter found in OAuth URL")
                }

                // Step 2: Open the OAuth URL in ASWebAuthenticationSession
                guard let oauthURL = URL(string: authorizationURL) else {
                    print("❌ GoogleAuthManager: Invalid OAuth URL")
                    await MainActor.run {
                        self.errorMessage = "Invalid OAuth URL received"
                        self.isAuthenticating = false
                    }
                    return
                }

                let callbackScheme = Constants.OAuth.callbackScheme
                print("🔗 GoogleAuthManager: Opening OAuth URL with callback scheme: \(callbackScheme)")

                await MainActor.run {
                    self.session = ASWebAuthenticationSession(url: oauthURL, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
                        Task { @MainActor in
                            self?.isAuthenticating = false

                            if let error = error {
                                let nsError = error as NSError
                                // Check if user cancelled
                                if nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && nsError.code == 1 {
                                    print("🔗 GoogleAuthManager: User cancelled OAuth")
                                    self?.errorMessage = "Authentication cancelled"
                                } else {
                                    print("❌ GoogleAuthManager: OAuth error: \(error)")
                                    print("❌ GoogleAuthManager: Error details: \(error.localizedDescription)")
                                    self?.errorMessage = "Authentication failed: \(error.localizedDescription)"
                                }
                                return
                            }

                            guard let callbackURL = callbackURL else {
                                print("❌ GoogleAuthManager: No callback URL received")
                                self?.errorMessage = "Authentication failed: No callback received"
                                return
                            }

                            print("🔗 GoogleAuthManager: ===== CALLBACK URL DETAILS =====")
                            print("🔗 GoogleAuthManager: Full Callback URL: \(callbackURL)")
                            print("🔗 GoogleAuthManager: Callback Scheme: \(callbackURL.scheme ?? "nil")")
                            print("🔗 GoogleAuthManager: Callback Host: \(callbackURL.host ?? "nil")")
                            print("🔗 GoogleAuthManager: Callback Path: \(callbackURL.path)")
                            print("🔗 GoogleAuthManager: Callback Query: \(callbackURL.query ?? "nil")")

                            // Parse callback URL to check for success or error
                            if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) {
                                // Check for success
                                if callbackURL.path.contains("success") || callbackURL.host == "oauth" && callbackURL.path == "/success" {
                                    print("✅ GoogleAuthManager: Google Calendar linked successfully!")
                                    print("✅ GoogleAuthManager: Success callback URL: \(callbackURL)")
                                    self?.isConnected = true
                                    self?.errorMessage = "✅ Google Calendar connected successfully!"

                                    // Post notification to update UI and trigger sync
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("GoogleCalendarConnected"),
                                        object: nil
                                    )

                                    // Clear success message after 3 seconds
                                    Task {
                                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                                        await MainActor.run {
                                            self?.errorMessage = nil
                                        }
                                    }
                                }
                                // Check for error
                                else if callbackURL.path.contains("error") || callbackURL.host == "oauth" && callbackURL.path == "/error" {
                                    let errorMsg = components.queryItems?.first(where: { $0.name == "message" })?.value ?? "Unknown error"
                                    print("❌ GoogleAuthManager: OAuth error from backend: \(errorMsg)")
                                    self?.errorMessage = "Authentication failed: \(errorMsg)"
                                    self?.isConnected = false
                                }
                                // Fallback: check query parameters
                                else if let status = components.queryItems?.first(where: { $0.name == "status" })?.value {
                                    if status == "success" {
                                        print("✅ GoogleAuthManager: Google Calendar linked successfully!")
                                        self?.isConnected = true
                                        self?.errorMessage = "✅ Google Calendar connected successfully!"

                                        // Post notification to update UI
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("GoogleCalendarConnected"),
                                            object: nil
                                        )

                                        Task {
                                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                                            await MainActor.run {
                                                self?.errorMessage = nil
                                            }
                                        }
                                    } else {
                                        let errorMsg = components.queryItems?.first(where: { $0.name == "message" })?.value ?? "Unknown error"
                                        print("❌ GoogleAuthManager: OAuth failed: \(errorMsg)")
                                        self?.errorMessage = "Authentication failed: \(errorMsg)"
                                        self?.isConnected = false
                                    }
                                }
                                else {
                                    print("❌ GoogleAuthManager: Unexpected callback URL format")
                                    self?.errorMessage = "Authentication failed: Unexpected response"
                                    self?.isConnected = false
                                }
                            } else {
                                print("❌ GoogleAuthManager: Failed to parse callback URL")
                                self?.errorMessage = "Authentication failed: Invalid callback"
                                self?.isConnected = false
                            }
                        }
                    }

                    self.session?.presentationContextProvider = self
                    self.session?.prefersEphemeralWebBrowserSession = false // Allow persistent login

                    print("🔗 GoogleAuthManager: Starting ASWebAuthenticationSession...")
                    self.session?.start()
                }

            } catch {
                print("❌ GoogleAuthManager: Failed to get OAuth URL: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to start authentication: \(error.localizedDescription)"
                    self.isAuthenticating = false
                }
            }
        }
    }

    func disconnectGoogle() async {
        print("🔗 GoogleAuthManager: ===== DISCONNECTING GOOGLE CALENDAR =====")

        do {
            let response = try await apiService.disconnectProvider("google")
            print("✅ GoogleAuthManager: Disconnected successfully")
            print("✅ GoogleAuthManager: Message: \(response.message)")

            isConnected = false
            errorMessage = nil

            // Post notification to update UI
            NotificationCenter.default.post(
                name: NSNotification.Name("GoogleCalendarDisconnected"),
                object: nil
            )
        } catch {
            print("❌ GoogleAuthManager: Failed to disconnect: \(error)")
            errorMessage = "Failed to disconnect: \(error.localizedDescription)"
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        // Fallback for iOS 26+
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return ASPresentationAnchor(windowScene: windowScene)
        }
        fatalError("Unable to find window scene for presentation anchor")
    }
}
