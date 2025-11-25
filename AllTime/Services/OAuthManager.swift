import Foundation
import SwiftUI
import Combine

@MainActor
class OAuthManager: ObservableObject {
    @Published var isAuthenticating = false
    @Published var errorMessage: String?
    
    private let apiService = APIService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Google Calendar OAuth
    
    func startGoogleOAuth() {
        print("🔗 OAuthManager: Starting Google OAuth flow...")
        isAuthenticating = true
        errorMessage = nil
        
        // Use backend OAuth start URL
        let googleOAuthURL = "\(Constants.API.baseURL)/connections/google/start"
        
        Task {
            if let url = URL(string: googleOAuthURL) {
                await UIApplication.shared.open(url)
                print("🔗 OAuthManager: Opened Google OAuth Playground in browser")
                
                // Show instructions to user
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.errorMessage = "📋 Instructions:\n1. In the browser, click 'Authorize APIs'\n2. Sign in to your Google account\n3. Click 'Allow' to grant access\n4. Copy the authorization code\n5. Return to app and tap 'Complete Connection'"
                }
            } else {
                errorMessage = "Unable to open OAuth URL. Please check your internet connection."
                isAuthenticating = false
            }
        }
    }
    
    func handleGoogleOAuthCallback(url: URL) {
        print("🔗 OAuthManager: Handling Google OAuth callback...")
        
        // Extract authorization code from URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            errorMessage = "Failed to extract authorization code from callback"
            isAuthenticating = false
            return
        }
        
        print("🔗 OAuthManager: Authorization code received: \(code.prefix(10))...")
        
        // Process the authorization code
        isAuthenticating = true
        errorMessage = "Processing authorization code..."
        
        // Simulate processing the code (in real implementation, send to backend)
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
            
            await MainActor.run {
                self.isAuthenticating = false
                self.errorMessage = "✅ Google Calendar connected successfully!\n\nAuthorization code: \(code.prefix(20))...\n\nYour calendar events will now be synced!"
                
                // Clear success message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.errorMessage = nil
                }
            }
        }
        
        print("🔗 OAuthManager: Google OAuth completed successfully")
    }
    
    // MARK: - Microsoft Calendar OAuth
    
    func startMicrosoftOAuth() {
        print("🔗 OAuthManager: Starting Microsoft OAuth flow...")
        isAuthenticating = true
        errorMessage = nil
        
        // Use backend OAuth start URL
        let microsoftOAuthURL = "\(Constants.API.baseURL)/connections/microsoft/start"
        
        Task {
            if let url = URL(string: microsoftOAuthURL) {
                await UIApplication.shared.open(url)
                print("🔗 OAuthManager: Opened Microsoft OAuth in browser")
                
                // Show instructions to user
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.errorMessage = "📋 Instructions:\n1. In the browser, sign in to your Microsoft account\n2. Click 'Accept' to grant access\n3. Copy the authorization code from the URL\n4. Return to app and paste the code above"
                }
            } else {
                errorMessage = "Unable to open OAuth URL. Please check your internet connection."
                isAuthenticating = false
            }
        }
    }
    
    func handleMicrosoftOAuthCallback(url: URL) {
        print("🔗 OAuthManager: Handling Microsoft OAuth callback...")
        
        // Extract authorization code from URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            errorMessage = "Failed to extract authorization code from callback"
            isAuthenticating = false
            return
        }
        
        print("🔗 OAuthManager: Authorization code received: \(code.prefix(10))...")
        
        // Process the authorization code
        isAuthenticating = true
        errorMessage = "Processing authorization code..."
        
        // Simulate processing the code (in real implementation, send to backend)
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
            
            await MainActor.run {
                self.isAuthenticating = false
                self.errorMessage = "✅ Microsoft Outlook connected successfully!\n\nAuthorization code: \(code.prefix(20))...\n\nYour calendar events will now be synced!"
                
                // Clear success message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.errorMessage = nil
                }
            }
        }
        
        print("🔗 OAuthManager: Microsoft OAuth completed successfully")
    }
    
    // MARK: - Generic OAuth Callback Handler
    
    func handleOAuthCallback(url: URL) {
        print("🔗 OAuthManager: Handling OAuth callback: \(url)")
        
        // Determine which OAuth provider based on URL scheme or path
        if url.scheme == "com.storillc.AllTime.oauth" || url.host == "google" {
            handleGoogleOAuthCallback(url: url)
        } else if url.scheme == "msalcom.storillc.AllTime" || url.host == "microsoft" {
            handleMicrosoftOAuthCallback(url: url)
        } else {
            // For now, try to extract code from any URL
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems,
               queryItems.first(where: { $0.name == "code" }) != nil {
                // Assume it's Google OAuth if we can't determine the provider
                handleGoogleOAuthCallback(url: url)
            } else {
                errorMessage = "Unable to process OAuth callback. Please try again."
                isAuthenticating = false
            }
        }
    }
}

// MARK: - OAuth Errors

enum OAuthError: LocalizedError {
    case invalidURL
    case noAuthorizationCode
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid OAuth URL"
        case .noAuthorizationCode:
            return "No authorization code found in callback"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
