import AuthenticationServices
import SwiftUI
import Combine

// URLSession delegate to intercept 302 redirects
class RedirectInterceptor: NSObject, URLSessionTaskDelegate {
    var onRedirect: ((URL) -> Void)?
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Intercept the redirect and don't follow it
        if response.statusCode == 302, let redirectURL = request.url {
            print("🔗 RedirectInterceptor: Intercepted 302 redirect to: \(redirectURL.absoluteString)")
            onRedirect?(redirectURL)
            completionHandler(nil) // Don't follow the redirect
        } else {
            completionHandler(request) // Follow other redirects
        }
    }
}

@MainActor
class GoogleAuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleAuthManager()
    
    @Published var isAuthenticating = false
    @Published var isConnected = false
    @Published var errorMessage: String?
    
    private var session: ASWebAuthenticationSession?
    private var redirectInterceptor: RedirectInterceptor?
    
    private override init() {
        super.init()
    }
    
    func startGoogleOAuth() {
        print("🔗 GoogleAuthManager: ===== STARTING GOOGLE OAUTH =====")
        print("🔗 GoogleAuthManager: Calling backend to get OAuth URL with state...")
        print("🔗 GoogleAuthManager: Base URL: \(Constants.API.baseURL)")
        
        isAuthenticating = true
        errorMessage = nil
        
        // Step 1: Call backend to get OAuth URL with state parameter
        guard let backendURL = URL(string: "\(Constants.API.baseURL)/connections/google/start") else {
            print("❌ GoogleAuthManager: Invalid backend URL")
            errorMessage = "Invalid backend URL"
            isAuthenticating = false
            return
        }
        
        // Check if we have a valid access token
        guard let accessToken = KeychainManager.shared.getAccessToken(), !accessToken.isEmpty else {
            print("❌ GoogleAuthManager: No access token found!")
            print("❌ GoogleAuthManager: User must sign in with Apple first")
            errorMessage = "Please sign in with Apple first"
            isAuthenticating = false
            return
        }
        
        var request = URLRequest(url: backendURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        print("🔗 GoogleAuthManager: Requesting OAuth URL from: \(backendURL.absoluteString)")
        print("🔗 GoogleAuthManager: Access Token: \(accessToken.prefix(20))...")
        print("🔗 GoogleAuthManager: Authorization header: Bearer \(accessToken.prefix(20))...")
        
        // Create a custom URLSession with redirect interceptor
        let interceptor = RedirectInterceptor()
        self.redirectInterceptor = interceptor
        
        interceptor.onRedirect = { [weak self] redirectURL in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                print("🔗 GoogleAuthManager: ===== OAUTH URL FROM BACKEND =====")
                print("🔗 GoogleAuthManager: OAuth URL: \(redirectURL.absoluteString)")
                
                // Extract and log state parameter for debugging
                if let components = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false),
                   let stateParam = components.queryItems?.first(where: { $0.name == "state" })?.value {
                    print("🔗 GoogleAuthManager: State parameter: \(stateParam)")
                } else {
                    print("⚠️ GoogleAuthManager: No state parameter found in OAuth URL")
                }
                
                // Step 2: Open the backend-provided OAuth URL in ASWebAuthenticationSession
                let callbackScheme = Constants.OAuth.callbackScheme
                print("🔗 GoogleAuthManager: Opening OAuth URL with callback scheme: \(callbackScheme)")
                
                self.session = ASWebAuthenticationSession(url: redirectURL, callbackURLScheme: callbackScheme) { [weak self] callbackURL, error in
                    DispatchQueue.main.async {
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
                                
                                // Clear success message after 3 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    self?.errorMessage = nil
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
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                        self?.errorMessage = nil
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
                self.session?.prefersEphemeralWebBrowserSession = true
                
                print("🔗 GoogleAuthManager: Starting ASWebAuthenticationSession...")
                self.session?.start()
            }
        }
        
        let config = URLSessionConfiguration.default
        let urlSession = URLSession(configuration: config, delegate: interceptor, delegateQueue: nil)
        
        urlSession.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ GoogleAuthManager: Backend request failed: \(error.localizedDescription)")
                    self.errorMessage = "Failed to connect to backend: \(error.localizedDescription)"
                    self.isAuthenticating = false
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ GoogleAuthManager: Invalid response from backend")
                    self.errorMessage = "Invalid response from backend"
                    self.isAuthenticating = false
                    return
                }
                
                print("🔗 GoogleAuthManager: Backend response status: \(httpResponse.statusCode)")
                print("🔗 GoogleAuthManager: Response headers: \(httpResponse.allHeaderFields)")
                
                // If we get here without redirect being intercepted, something went wrong
                if httpResponse.statusCode != 302 {
                    print("❌ GoogleAuthManager: ===== BACKEND ERROR =====")
                    print("❌ GoogleAuthManager: Backend didn't return 302 redirect")
                    print("❌ GoogleAuthManager: Status code: \(httpResponse.statusCode)")
                    print("❌ GoogleAuthManager: All headers: \(httpResponse.allHeaderFields)")
                    
                    if let data = data {
                        print("❌ GoogleAuthManager: Response data size: \(data.count) bytes")
                        if let responseBody = String(data: data, encoding: .utf8) {
                            print("❌ GoogleAuthManager: Response body: \(responseBody)")
                        } else {
                            print("❌ GoogleAuthManager: Response body (hex): \(data.map { String(format: "%02x", $0) }.joined())")
                        }
                    } else {
                        print("❌ GoogleAuthManager: No response body")
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
                            print("❌ GoogleAuthManager: Backend requesting sign-out: \(message)")
                            shouldSignOut = true
                        }
                    }
                    
                    // Handle specific status codes
                    switch httpResponse.statusCode {
                    case 401:
                        print("❌ GoogleAuthManager: Unauthorized - token may be expired or invalid")
                        if shouldSignOut {
                            print("❌ GoogleAuthManager: Triggering automatic sign-out...")
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
                        print("❌ GoogleAuthManager: Internal server error")
                        self.errorMessage = "Backend error: \(errorDetail)"
                    case 403:
                        print("❌ GoogleAuthManager: Forbidden - insufficient permissions")
                        self.errorMessage = "Access denied: \(errorDetail)"
                    default:
                        self.errorMessage = "Backend error: \(errorDetail)"
                    }
                    
                    self.isAuthenticating = false
                }
            }
        }.resume()
    }
    
    func disconnectGoogle() {
        print("🔗 GoogleAuthManager: Disconnecting Google Calendar...")
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
