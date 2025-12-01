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
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        // Listen for deep link notifications (in case backend redirects after processing)
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("GoogleOAuthDeepLink"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🔵 GoogleAuthManager: Received deep link notification")
            if let userInfo = notification.userInfo,
               let url = userInfo["url"] as? URL {
                self?.handleDeepLink(url: url)
            }
        }
        
        // Listen for OAuth success notification
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OAuthSuccess"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🔵 GoogleAuthManager: Received OAuth success notification")
            if let userInfo = notification.userInfo,
               let provider = userInfo["provider"] as? String,
               (provider == "google" || provider == "unknown") {
                self?.handleOAuthSuccess()
            }
        }
        
        // Listen for OAuth error notification
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OAuthError"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🔵 GoogleAuthManager: Received OAuth error notification")
            if let userInfo = notification.userInfo,
               let provider = userInfo["provider"] as? String,
               (provider == "google" || provider == "unknown"),
               let error = userInfo["error"] as? String {
                self?.handleOAuthError(error: error)
            }
        }
        
        // Listen for Google Calendar token expiry
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("GoogleCalendarTokenExpired"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                print("🔗 GoogleAuthManager: Received Google Calendar token expiry notification")
                if let userInfo = notification.userInfo,
                   let errorMessage = userInfo["error"] as? String {
                    print("🔗 GoogleAuthManager: Token expiry error: \(errorMessage)")
                    self?.errorMessage = errorMessage
                }
                self?.isConnected = false
            }
        }
    }
    
    private func handleDeepLink(url: URL) {
        print("🔵 GoogleAuthManager: Handling deep link: \(url.absoluteString)")
        
        // If this is a success callback, verify connection
        if url.path.contains("success") || url.path == "/success" {
            print("✅ GoogleAuthManager: Deep link indicates success - verifying connection")
            handleOAuthSuccess()
        } else if url.path.contains("error") || url.path == "/error" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let errorMessage = components?.queryItems?.first(where: { $0.name == "message" })?.value ?? 
                              components?.queryItems?.first(where: { $0.name == "error" })?.value ?? 
                              "Unknown error"
            print("❌ GoogleAuthManager: Deep link indicates error: \(errorMessage)")
            handleOAuthError(error: errorMessage)
        }
    }
    
    private func handleOAuthSuccess() {
        print("✅ GoogleAuthManager: Handling OAuth success from deep link")
        isAuthenticating = false
        
        // Verify connection by checking connection status
        Task {
            do {
                // Try to sync to verify connection works
                let apiService = APIService()
                _ = try await apiService.syncGoogleCalendar()
                
                await MainActor.run {
                    self.isConnected = true
                    self.errorMessage = "✅ Google Calendar connected successfully!"
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.errorMessage = nil
                    }
                    
                    // Post notification to trigger sync
                    NotificationCenter.default.post(
                        name: NSNotification.Name("GoogleCalendarConnected"),
                        object: nil
                    )
                }
                
                print("✅ GoogleAuthManager: Connection verified and sync successful")
            } catch {
                print("⚠️ GoogleAuthManager: Failed to verify connection: \(error.localizedDescription)")
                await MainActor.run {
                    self.isConnected = false
                    self.errorMessage = "Connection may have failed. Please try again."
                }
            }
        }
    }
    
    private func handleOAuthError(error: String) {
        print("❌ GoogleAuthManager: Handling OAuth error from deep link: \(error)")
        isAuthenticating = false
        isConnected = false
        errorMessage = "OAuth failed: \(error)"
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
                            // Extract authorization code from callback URL
                            let authCode = components.queryItems?.first(where: { $0.name == "code" })?.value
                            
                            // Check for success
                            if callbackURL.path.contains("success") || callbackURL.host == "oauth" && callbackURL.path == "/success" {
                                print("✅ GoogleAuthManager: Success callback URL received: \(callbackURL)")
                                
                                // CRITICAL: Complete OAuth flow by calling backend with authorization code
                                if let code = authCode {
                                    print("🔗 GoogleAuthManager: Extracted authorization code: \(code.prefix(10))...")
                                    print("🔗 GoogleAuthManager: Calling backend to complete OAuth flow...")
                                    
                                    Task {
                                        do {
                                            let apiService = APIService()
                                            try await apiService.completeGoogleOAuth(code: code)
                                            print("✅ GoogleAuthManager: Backend OAuth completion successful!")
                                            
                                            await MainActor.run {
                                                self?.isConnected = true
                                                self?.errorMessage = "✅ Google Calendar connected successfully!"
                                                
                                                // Clear success message after 3 seconds
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                                    self?.errorMessage = nil
                                                }
                                                
                                                // Post notification to trigger sync
                                                NotificationCenter.default.post(
                                                    name: NSNotification.Name("GoogleCalendarConnected"),
                                                    object: nil
                                                )
                                                
                                                // Trigger sync to fetch events
                                                Task {
                                                    do {
                                                        _ = try await apiService.syncGoogleCalendar()
                                                        print("✅ GoogleAuthManager: Events synced after connection")
                                                    } catch {
                                                        print("⚠️ GoogleAuthManager: Failed to sync events: \(error)")
                                                        // Don't show error to user - sync will happen on next refresh
                                                    }
                                                }
                                            }
                                        } catch {
                                            print("❌ GoogleAuthManager: Failed to complete OAuth with backend: \(error.localizedDescription)")
                                            await MainActor.run {
                                                self?.isConnected = false
                                                self?.errorMessage = "Failed to complete connection: \(error.localizedDescription)"
                                            }
                                        }
                                    }
                                } else {
                                    print("⚠️ GoogleAuthManager: Success callback but no authorization code found")
                                    // Backend may have handled the callback directly (redirect-based flow)
                                    // Still mark as connected if backend says success
                                    self?.isConnected = true
                                    self?.errorMessage = "✅ Google Calendar connected successfully!"
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                        self?.errorMessage = nil
                                    }
                                    
                                    // Post notification to trigger sync
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("GoogleCalendarConnected"),
                                        object: nil
                                    )
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
                                    print("✅ GoogleAuthManager: Success status in query parameters")
                                    
                                    // Try to extract authorization code
                                    if let code = authCode {
                                        print("🔗 GoogleAuthManager: Extracted authorization code: \(code.prefix(10))...")
                                        print("🔗 GoogleAuthManager: Calling backend to complete OAuth flow...")
                                        
                                        Task {
                                            do {
                                                let apiService = APIService()
                                                try await apiService.completeGoogleOAuth(code: code)
                                                print("✅ GoogleAuthManager: Backend OAuth completion successful!")
                                                
                                                await MainActor.run {
                                                    self?.isConnected = true
                                                    self?.errorMessage = "✅ Google Calendar connected successfully!"
                                                    
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                                        self?.errorMessage = nil
                                                    }
                                                    
                                                    // Post notification to trigger sync
                                                    NotificationCenter.default.post(
                                                        name: NSNotification.Name("GoogleCalendarConnected"),
                                                        object: nil
                                                    )
                                                    
                                                    // Trigger sync to fetch events
                                                    Task {
                                                        do {
                                                            _ = try await apiService.syncGoogleCalendar()
                                                            print("✅ GoogleAuthManager: Events synced after connection")
                                                        } catch {
                                                            print("⚠️ GoogleAuthManager: Failed to sync events: \(error)")
                                                        }
                                                    }
                                                }
                                            } catch {
                                                print("❌ GoogleAuthManager: Failed to complete OAuth with backend: \(error.localizedDescription)")
                                                await MainActor.run {
                                                    self?.isConnected = false
                                                    self?.errorMessage = "Failed to complete connection: \(error.localizedDescription)"
                                                }
                                            }
                                        }
                                    } else {
                                        // No code but status is success - backend may have handled it
                                        print("⚠️ GoogleAuthManager: Success status but no code - assuming backend handled callback")
                                        self?.isConnected = true
                                        self?.errorMessage = "✅ Google Calendar connected successfully!"
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
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
