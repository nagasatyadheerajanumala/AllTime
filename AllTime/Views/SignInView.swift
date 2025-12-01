import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Official Chrona Dark Theme - Pure Black Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                // Subtle radial gradient under icon for depth
                VStack {
                    Spacer()
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    DesignSystem.Colors.glowBlue,
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 50,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .blur(radius: 80)
                        .offset(y: -100)
                }
                
                // Subtle accent line at top
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    DesignSystem.Colors.primary.opacity(0.6),
                                    DesignSystem.Colors.primary.opacity(0.3)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                    Spacer()
                }
                
                // Main content
                VStack(spacing: 0) {
                    Spacer()
                    
                    // App branding - Professional & Elegant
                    VStack(spacing: 32) {
                        // Refined icon with premium styling and subtle glow
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            DesignSystem.Colors.primary,
                                            DesignSystem.Colors.primaryDark
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: DesignSystem.Colors.glowBlueStrong, radius: 30, x: 0, y: 0)
                                .shadow(color: Color.black.opacity(0.3), radius: 25, x: 0, y: 12)
                            
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 44, weight: .light))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                        
                        VStack(spacing: 16) {
                            Text("Chrona")
                                .font(.system(size: 52, weight: .ultraLight, design: .default))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .tracking(2)
                            
                            Text("Your unified calendar experience")
                                .font(.system(size: 16, weight: .light, design: .default))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 50)
                                .lineSpacing(4)
                        }
                    }
                    .padding(.bottom, 80)
                    
                    Spacer()
                    
                    // Sign in section
                    VStack(spacing: 24) {
                        // Error message - Refined styling
                        if let errorMessage = authService.errorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 15, weight: .light))
                                    .foregroundColor(.red.opacity(0.8))
                                
                                Text(errorMessage)
                                    .font(.system(size: 13, weight: .light, design: .default))
                                    .foregroundColor(.red.opacity(0.9))
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(Color.red.opacity(0.06))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red.opacity(0.15), lineWidth: 1)
                            )
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
                            .frame(height: 58)
                            .frame(maxWidth: 320)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.12), radius: 15, x: 0, y: 6)
                            .disabled(authService.isLoading)
                            .opacity(authService.isLoading ? 0.6 : 1.0)
                            
                            // Loading indicator
                            if authService.isLoading {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primary))
                                    
                                    Text("Signing in...")
                                        .font(.system(size: 14, weight: .light, design: .default))
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                        .tracking(0.5)
                                }
                                .padding(.top, 6)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                        .frame(height: 80)
                    
                    // Footer - Professional & Understated
                    VStack(spacing: 10) {
                        Text("Secure authentication with Apple")
                            .font(.system(size: 12, weight: .light, design: .default))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .tracking(0.3)
                        
                        HStack(spacing: 5) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 10, weight: .light))
                            Text("Your privacy is protected")
                                .font(.system(size: 11, weight: .light, design: .default))
                                .tracking(0.2)
                        }
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    .padding(.bottom, 50)
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
