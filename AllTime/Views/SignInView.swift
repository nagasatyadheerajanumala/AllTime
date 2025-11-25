import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Modern gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.98, green: 0.96, blue: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Subtle animated circles in background
                Circle()
                    .fill(Color.blue.opacity(0.05))
                    .frame(width: 300, height: 300)
                    .offset(x: -100, y: -200)
                
                Circle()
                    .fill(Color.purple.opacity(0.05))
                    .frame(width: 250, height: 250)
                    .offset(x: 150, y: 300)
                
                // Main content
                VStack(spacing: 0) {
                    Spacer()
                    
                    // App branding
                    VStack(spacing: 20) {
                        // Modern icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue,
                                            Color.blue.opacity(0.8)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 90, height: 90)
                                .shadow(color: Color.blue.opacity(0.3), radius: 20, x: 0, y: 10)
                            
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 42, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 12) {
                            Text("AllTime")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Your unified calendar experience")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    .padding(.bottom, 60)
                    
                    Spacer()
                    
                    // Sign in section
                    VStack(spacing: 24) {
                        // Error message
                        if let errorMessage = authService.errorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.red)
                                
                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(12)
                            .padding(.horizontal, 32)
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Sign in with Apple button
                        VStack(spacing: 16) {
                            SignInWithAppleButton(
                                .signIn,
                                onRequest: { request in
                                    request.requestedScopes = [.fullName, .email]
                                    authService.isLoading = true
                                    authService.errorMessage = nil
                                },
                                onCompletion: { result in
                                    print("🍎 SignInView: Apple Sign-In completion received")
                                    switch result {
                                    case .success(let authorization):
                                        print("🍎 SignInView: Apple Sign-In successful, processing credential...")
                                        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                           let identityToken = credential.identityToken,
                                           let tokenString = String(data: identityToken, encoding: .utf8) {
                                            print("🍎 SignInView: Identity token extracted, calling auth service...")
                                            
                                            let authorizationCode = credential.authorizationCode != nil ? String(data: credential.authorizationCode!, encoding: .utf8) : nil
                                            let userIdentifier = credential.user
                                            let email = credential.email
                                            let fullName = credential.fullName
                                            
                                            Task {
                                                await authService.handleAppleSignInSuccess(
                                                    identityToken: tokenString,
                                                    authorizationCode: authorizationCode,
                                                    userIdentifier: userIdentifier,
                                                    email: email,
                                                    fullName: fullName
                                                )
                                            }
                                        } else {
                                            print("🍎 SignInView: Failed to extract identity token")
                                            authService.errorMessage = "Failed to retrieve Apple identity token"
                                            authService.isLoading = false
                                        }
                                    case .failure(let error):
                                        print("🍎 SignInView: Apple Sign-In failed: \(error.localizedDescription)")
                                        authService.errorMessage = error.localizedDescription
                                        authService.isLoading = false
                                    }
                                }
                            )
                            .signInWithAppleButtonStyle(.black)
                            .frame(height: 56)
                            .frame(maxWidth: 340)
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                            .disabled(authService.isLoading)
                            .opacity(authService.isLoading ? 0.6 : 1.0)
                            
                            // Loading indicator
                            if authService.isLoading {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    
                                    Text("Signing in...")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 4)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                        .frame(height: 80)
                    
                    // Footer
                    VStack(spacing: 8) {
                        Text("Secure authentication with Apple")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 11))
                            Text("Your privacy is protected")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.bottom, 40)
                }
                .frame(width: geometry.size.width)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isLoading)
        .animation(.easeInOut(duration: 0.3), value: authService.errorMessage)
        .onAppear {
            print("🔍 SignInView: Appeared")
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthenticationService())
}
