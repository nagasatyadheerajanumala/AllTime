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
    private var redirectInterceptor: RedirectInterceptor?
    
    private override init() {
        super.init()
    }
    
    func startMicrosoftOAuth() {
        print("🔗 MicrosoftAuthManager: ===== STARTING MICROSOFT OAUTH =====")
        print("🔗 MicrosoftAuthManager: Calling backend to get OAuth URL with state...")
        print("🔗 MicrosoftAuthManager: Base URL: \(Constants.API.baseURL)")
        
        isAuthenticating = true
        errorMessage = nil
        
        // Step 1: Call backend to get OAuth URL with state parameter
        guard let backendURL = URL(string: "\(Constants.API.baseURL)/connections/microsoft/start") else {
            print("❌ MicrosoftAuthManager: Invalid backend URL")
            errorMessage = "Invalid backend URL"
            isAuthenticating = false
            return
        }
        
        // Check if we have a valid access token
        guard let accessToken = KeychainManager.shared.getAccessToken(), !accessToken.isEmpty else {
            print("❌ MicrosoftAuthManager: No access token found!")
            print("❌ MicrosoftAuthManager: User must sign in with Apple first")
            errorMessage = "Please sign in with Apple first"
            isAuthenticating = false
            return
        }
        
        var request = URLRequest(url: backendURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        print("🔗 MicrosoftAuthManager: Requesting OAuth URL from: \(backendURL.absoluteString)")
        print("🔗 MicrosoftAuthManager: Access Token: \(accessToken.prefix(20))...")
        print("🔗 MicrosoftAuthManager: Authorization header: Bearer \(accessToken.prefix(20))...")
        
        // Create a custom URLSession with redirect interceptor
        let interceptor = RedirectInterceptor()
        self.redirectInterceptor = interceptor
        
        interceptor.onRedirect = { [weak self] redirectURL in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                print("🔗 MicrosoftAuthManager: ===== OAUTH URL FROM BACKEND =====")
                print("🔗 MicrosoftAuthManager: OAuth URL: \(redirectURL.absoluteString)")
                
                // Extract and log state parameter for debugging
                if let components = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false),
                   let stateParam = components.queryItems?.first(where: { $0.name == "state" })?.value {
                    print("🔗 MicrosoftAuthManager: State parameter: \(stateParam)")
                } else {
                    print("⚠️ MicrosoftAuthManager: No state parameter found in OAuth URL")
                }
                
                // Step 2: Open the backend-provided OAuth URL in ASWebAuthenticationSession
                let callbackScheme = Constants.OAuth.callbackScheme
                print("🔗 MicrosoftAuthManager: Opening OAuth URL with callback scheme: \(callbackScheme)")
                
                self.session = ASWebAuthenticationSession(url: redirectURL, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
                    DispatchQueue.main.async {
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
                                
                                // Trigger sync to fetch events from Microsoft Calendar
                                // Note: The backend sync endpoint may handle all providers
                                // The CalendarViewModel will handle the actual sync on refresh
                                Task {
                                    do {
                                        let apiService = APIService()
                                        _ = try await apiService.syncGoogleCalendar() // Backend may sync all providers
                                        print("✅ MicrosoftAuthManager: Events synced after connection")
                                    } catch {
                                        print("⚠️ MicrosoftAuthManager: Failed to sync events: \(error)")
                                        // Don't show error to user - sync will happen on next refresh
                                    }
                                }
                                
                                // Clear success message after 3 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    self?.errorMessage = nil
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
                                print("❌ MicrosoftAuthManager: This is a BACKEND ERROR - backend failed to authenticate with Microsoft Graph API")
                                print("❌ MicrosoftAuthManager: Backend should check:")
                                print("   1. Microsoft Azure app configuration (Client ID, Client Secret)")
                                print("   2. Redirect URI matches Azure app settings")
                                print("   3. OAuth token exchange is successful")
                                print("   4. Access token has correct scopes/permissions")
                                print("   5. Access token is included in Microsoft Graph API calls")
                                
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
                                    
                                    // Trigger sync to fetch events from Microsoft Calendar
                                    Task {
                                        do {
                                            let apiService = APIService()
                                            _ = try await apiService.syncGoogleCalendar() // Backend may sync all providers
                                            print("✅ MicrosoftAuthManager: Events synced after connection")
                                        } catch {
                                            print("⚠️ MicrosoftAuthManager: Failed to sync events: \(error)")
                                            // Don't show error to user - sync will happen on next refresh
                                        }
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                        self?.errorMessage = nil
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
                self.session?.prefersEphemeralWebBrowserSession = true
                
                print("🔗 MicrosoftAuthManager: Starting ASWebAuthenticationSession...")
                self.session?.start()
            }
        }
        
        let config = URLSessionConfiguration.default
        let urlSession = URLSession(configuration: config, delegate: interceptor, delegateQueue: nil)
        
        urlSession.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ MicrosoftAuthManager: Backend request failed: \(error.localizedDescription)")
                    self.errorMessage = "Failed to connect to backend: \(error.localizedDescription)"
                    self.isAuthenticating = false
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ MicrosoftAuthManager: Invalid response from backend")
                    self.errorMessage = "Invalid response from backend"
                    self.isAuthenticating = false
                    return
                }
                
                print("🔗 MicrosoftAuthManager: Backend response status: \(httpResponse.statusCode)")
                print("🔗 MicrosoftAuthManager: Response headers: \(httpResponse.allHeaderFields)")
                
                // If we get here without redirect being intercepted, something went wrong
                if httpResponse.statusCode != 302 {
                    print("❌ MicrosoftAuthManager: ===== BACKEND ERROR =====")
                    print("❌ MicrosoftAuthManager: Backend didn't return 302 redirect")
                    print("❌ MicrosoftAuthManager: Status code: \(httpResponse.statusCode)")
                    print("❌ MicrosoftAuthManager: All headers: \(httpResponse.allHeaderFields)")
                    
                    if let data = data {
                        print("❌ MicrosoftAuthManager: Response data size: \(data.count) bytes")
                        if let responseBody = String(data: data, encoding: .utf8) {
                            print("❌ MicrosoftAuthManager: Response body: \(responseBody)")
                        } else {
                            print("❌ MicrosoftAuthManager: Response body (hex): \(data.map { String(format: "%02x", $0) }.joined())")
                        }
                    } else {
                        print("❌ MicrosoftAuthManager: No response body")
                    }
                    
                    // Parse error message if available
                    var errorDetail = "Status \(httpResponse.statusCode)"
                    var shouldSignOut = false
                    
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let message = json["error"] as? String ?? json["message"] as? String ?? "Unknown error"
                        errorDetail = message
                        
                        // Check if backend is requesting sign-out
                        if let action = json["action"] as? String, action == "sign_out_and_sign_in" {
                            print("❌ MicrosoftAuthManager: Backend requesting sign-out: \(message)")
                            shouldSignOut = true
                        }
                    }
                    
                    // Handle specific status codes
                    switch httpResponse.statusCode {
                    case 401:
                        print("❌ MicrosoftAuthManager: Unauthorized - token may be expired or invalid")
                        if shouldSignOut {
                            print("❌ MicrosoftAuthManager: Triggering automatic sign-out...")
                            self.errorMessage = "Session expired. Redirecting to sign in..."
                            
                            // Trigger sign-out after a brief delay to show the message
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                // Post notification to trigger sign-out
                                NotificationCenter.default.post(name: NSNotification.Name("ForceSignOut"), object: nil)
                            }
                        } else {
                            self.errorMessage = "Authentication expired. Please sign in again."
                        }
                    case 500:
                        print("❌ MicrosoftAuthManager: Internal server error")
                        self.errorMessage = "Backend error: \(errorDetail)"
                    case 403:
                        print("❌ MicrosoftAuthManager: Forbidden - insufficient permissions")
                        self.errorMessage = "Access denied: \(errorDetail)"
                    default:
                        self.errorMessage = "Backend error: \(errorDetail)"
                    }
                    
                    self.isAuthenticating = false
                }
            }
        }.resume()
    }
    
    func disconnectMicrosoft() {
        print("🔗 MicrosoftAuthManager: Disconnecting Microsoft Calendar...")
        isConnected = false
        errorMessage = nil
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

