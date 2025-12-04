import SwiftUI

struct ManualOAuthView: View {
    @EnvironmentObject var oauthManager: OAuthManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var googleAuthManager = GoogleAuthManager.shared
    @State private var authorizationCode = ""
    let provider: String
    
    init(provider: String) {
        self.provider = provider
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: provider == "google" ? "g.circle.fill" : "m.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(provider == "google" ? .red : .blue)
                    
                    Text("Connect \(provider == "google" ? "Google Calendar" : "Microsoft Outlook")")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Tap the button below to connect your calendar. You'll be redirected to sign in and authorize access.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Native OAuth Button
                VStack(spacing: 20) {
                    if provider == "google" {
                        // Google Calendar - Native OAuth
                        Button(action: {
                            googleAuthManager.startGoogleOAuth()
                        }) {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                    .font(.title2)
                                Text("Connect Google Calendar")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(googleAuthManager.isAuthenticating)
                        
                        if googleAuthManager.isConnected {
                            Button(action: {
                                Task {
                                    await googleAuthManager.disconnectGoogle()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                    Text("Disconnect Google Calendar")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        
                        Text("Tap to connect your Google Calendar. You'll be redirected to sign in and authorize access.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        // Microsoft Outlook - Manual OAuth (fallback)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Authorization Code")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Paste authorization code here", text: $authorizationCode)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                oauthManager.startMicrosoftOAuth()
                            }) {
                                HStack {
                                    Image(systemName: "safari")
                                        .font(.title2)
                                    Text("Open Browser & Get Code")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(oauthManager.isAuthenticating)
                            
                            Button(action: {
                                if !authorizationCode.isEmpty {
                                    oauthManager.handleMicrosoftOAuthCallback(url: URL(string: "https://example.com?code=\(authorizationCode)")!)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "checkmark")
                                        .font(.title2)
                                    Text("Complete Connection")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(authorizationCode.isEmpty ? Color.gray : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(authorizationCode.isEmpty)
                            
                            Text("1. Tap 'Open Browser' to get authorization code\n2. Copy the code from the browser\n3. Paste it above and tap 'Complete Connection'")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Status Messages
                if let errorMessage = provider == "google" ? googleAuthManager.errorMessage : oauthManager.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(errorMessage.contains("successfully") ? .green : .red)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(errorMessage.contains("successfully") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                }
                
                if (provider == "google" ? googleAuthManager.isAuthenticating : oauthManager.isAuthenticating) {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(provider == "google" ? "Opening Google OAuth..." : "Opening browser...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
            }
            .navigationTitle("Connect Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ManualOAuthView(provider: "google")
        .environmentObject(OAuthManager())
}
