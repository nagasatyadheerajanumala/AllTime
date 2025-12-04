import AuthenticationServices
import SwiftUI
import Combine

@MainActor
class MicrosoftAuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = MicrosoftAuthManager()

    @Published var isAuthenticating = false
    @Published var isConnected = false
    @Published var errorMessage: String?

    private var session: ASWebAuthenticationSession?
    private let apiService = APIService()

    private override init() {
        super.init()
    }

    func startMicrosoftOAuth() {
        print("🔗 MicrosoftAuthManager: ===== STARTING MICROSOFT OAUTH =====")

        isAuthenticating = true
        errorMessage = nil

        // Check if we have a valid access token
        guard let accessToken = KeychainManager.shared.getAccessToken(), !accessToken.isEmpty else {
            print("❌ MicrosoftAuthManager: No access token found!")
            print("❌ MicrosoftAuthManager: User must sign in with Apple first")
            errorMessage = "Please sign in with Apple first"
            isAuthenticating = false
            return
        }

        print("🔗 MicrosoftAuthManager: Access Token: \(accessToken.prefix(20))...")

        // Step 1: Call backend API to get OAuth URL
        Task {
            do {
                print("🔗 MicrosoftAuthManager: Fetching OAuth URL from backend...")
                let authorizationURL = try await apiService.getMicrosoftOAuthStartURL()

                print("🔗 MicrosoftAuthManager: ===== OAUTH URL FROM BACKEND =====")
                print("🔗 MicrosoftAuthManager: OAuth URL: \(authorizationURL)")

                // Extract and log state parameter for debugging
                if let url = URL(string: authorizationURL),
                   let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let stateParam = components.queryItems?.first(where: { $0.name == "state" })?.value {
                    print("🔗 MicrosoftAuthManager: State parameter: \(stateParam)")
                } else {
                    print("⚠️ MicrosoftAuthManager: No state parameter found in OAuth URL")
                }

                // Step 2: Open the OAuth URL in ASWebAuthenticationSession
                guard let oauthURL = URL(string: authorizationURL) else {
                    print("❌ MicrosoftAuthManager: Invalid OAuth URL")
                    await MainActor.run {
                        self.errorMessage = "Invalid OAuth URL received"
                        self.isAuthenticating = false
                    }
                    return
                }

                let callbackScheme = Constants.OAuth.callbackScheme
                print("🔗 MicrosoftAuthManager: Opening OAuth URL with callback scheme: \(callbackScheme)")

                await MainActor.run {
                    self.session = ASWebAuthenticationSession(url: oauthURL, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
                        Task { @MainActor in
                            self?.isAuthenticating = false

                            if let error = error {
                                let nsError = error as NSError
                                // Check if user cancelled
                                if nsError.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && nsError.code == 1 {
                                    print("🔗 MicrosoftAuthManager: User cancelled OAuth")
                                    self?.errorMessage = "Authentication cancelled"
                                } else {
                                    print("❌ MicrosoftAuthManager: OAuth error: \(error)")
                                    print("❌ MicrosoftAuthManager: Error details: \(error.localizedDescription)")
                                    self?.errorMessage = "Authentication failed: \(error.localizedDescription)"
                                }
                                return
                            }

                            guard let callbackURL = callbackURL else {
                                print("❌ MicrosoftAuthManager: No callback URL received")
                                self?.errorMessage = "Authentication failed: No callback received"
                                return
                            }

                            print("🔗 MicrosoftAuthManager: ===== CALLBACK URL DETAILS =====")
                            print("🔗 MicrosoftAuthManager: Full Callback URL: \(callbackURL)")
                            print("🔗 MicrosoftAuthManager: Callback Scheme: \(callbackURL.scheme ?? "nil")")
                            print("🔗 MicrosoftAuthManager: Callback Host: \(callbackURL.host ?? "nil")")
                            print("🔗 MicrosoftAuthManager: Callback Path: \(callbackURL.path)")
                            print("🔗 MicrosoftAuthManager: Callback Query: \(callbackURL.query ?? "nil")")

                            // Parse callback URL to check for success or error
                            if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) {
                                // Check for success
                                if callbackURL.path.contains("success") || callbackURL.host == "oauth" && callbackURL.path == "/success" {
                                    print("✅ MicrosoftAuthManager: Microsoft Calendar linked successfully!")
                                    print("✅ MicrosoftAuthManager: Success callback URL: \(callbackURL)")
                                    self?.isConnected = true
                                    self?.errorMessage = "✅ Microsoft Calendar connected successfully!"

                                    // Post notification to update UI and trigger sync
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("MicrosoftCalendarConnected"),
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
                                    var errorMsg = components.queryItems?.first(where: { $0.name == "message" })?.value ?? "Unknown error"

                                    // Decode URL-encoded error message
                                    errorMsg = errorMsg.removingPercentEncoding ?? errorMsg

                                    // Replace + with spaces for better readability
                                    errorMsg = errorMsg.replacingOccurrences(of: "+", with: " ")

                                    print("❌ MicrosoftAuthManager: ===== OAUTH ERROR FROM BACKEND =====")
                                    print("❌ MicrosoftAuthManager: Raw error message: \(errorMsg)")

                                    // Parse the error to provide more helpful messages
                                    var userFriendlyMessage = "Microsoft Calendar connection failed"

                                    if errorMsg.contains("401") && errorMsg.contains("Unauthorized") {
                                        if errorMsg.contains("graph.microsoft.com") {
                                            userFriendlyMessage = "Microsoft authentication failed. The backend may need to refresh Microsoft OAuth credentials or check Azure app configuration."
                                        } else {
                                            userFriendlyMessage = "Authentication failed. Please try again or contact support."
                                        }
                                    } else if errorMsg.contains("403") {
                                        userFriendlyMessage = "Access denied. Please check that calendar permissions are granted."
                                    } else if errorMsg.contains("500") {
                                        userFriendlyMessage = "Server error. Please try again later."
                                    } else {
                                        userFriendlyMessage = "Connection failed: \(errorMsg)"
                                    }

                                    print("❌ MicrosoftAuthManager: User-friendly message: \(userFriendlyMessage)")

                                    self?.errorMessage = userFriendlyMessage
                                    self?.isConnected = false
                                }
                                // Fallback: check query parameters
                                else if let status = components.queryItems?.first(where: { $0.name == "status" })?.value {
                                    if status == "success" {
                                        print("✅ MicrosoftAuthManager: Microsoft Calendar linked successfully!")
                                        self?.isConnected = true
                                        self?.errorMessage = "✅ Microsoft Calendar connected successfully!"

                                        // Post notification to update UI
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("MicrosoftCalendarConnected"),
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
                                        print("❌ MicrosoftAuthManager: OAuth failed: \(errorMsg)")
                                        self?.errorMessage = "Authentication failed: \(errorMsg)"
                                        self?.isConnected = false
                                    }
                                }
                                else {
                                    print("❌ MicrosoftAuthManager: Unexpected callback URL format")
                                    self?.errorMessage = "Authentication failed: Unexpected response"
                                    self?.isConnected = false
                                }
                            } else {
                                print("❌ MicrosoftAuthManager: Failed to parse callback URL")
                                self?.errorMessage = "Authentication failed: Invalid callback"
                                self?.isConnected = false
                            }
                        }
                    }

                    self.session?.presentationContextProvider = self
                    self.session?.prefersEphemeralWebBrowserSession = false // Allow persistent login

                    print("🔗 MicrosoftAuthManager: Starting ASWebAuthenticationSession...")
                    self.session?.start()
                }

            } catch {
                print("❌ MicrosoftAuthManager: Failed to get OAuth URL: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to start authentication: \(error.localizedDescription)"
                    self.isAuthenticating = false
                }
            }
        }
    }

    func disconnectMicrosoft() async {
        print("🔗 MicrosoftAuthManager: ===== DISCONNECTING MICROSOFT CALENDAR =====")

        do {
            let response = try await apiService.disconnectProvider("microsoft")
            print("✅ MicrosoftAuthManager: Disconnected successfully")
            print("✅ MicrosoftAuthManager: Message: \(response.message)")

            isConnected = false
            errorMessage = nil

            // Post notification to update UI
            NotificationCenter.default.post(
                name: NSNotification.Name("MicrosoftCalendarDisconnected"),
                object: nil
            )
        } catch {
            print("❌ MicrosoftAuthManager: Failed to disconnect: \(error)")
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
