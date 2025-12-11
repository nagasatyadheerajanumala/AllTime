import SwiftUI
import AuthenticationServices

// MARK: - Premium Sign-In View

struct SignInView: View {
    @EnvironmentObject var authService: AuthenticationService

    var body: some View {
        ClassySignInView()
            .environmentObject(authService)
    }
}

// MARK: - Classy Minimal Design
// Inspired by Apple Watch, Apple TV+, and luxury brand aesthetics

struct ClassySignInView: View {
    @EnvironmentObject var authService: AuthenticationService

    // Animation states
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.85
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var glowIntensity: Double = 0.3

    var body: some View {
        ZStack {
            // Deep, rich black background
            Color.black
                .ignoresSafeArea()

            // Subtle ambient glow - very refined
            GeometryReader { geo in
                // Top subtle blue wash
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "3B82F6").opacity(0.06),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.6
                        )
                    )
                    .frame(width: geo.size.width, height: geo.size.width * 0.8)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.28)
                    .blur(radius: 60)
            }
            .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                Spacer()

                // Hero section - Icon + Brand unified
                VStack(spacing: 28) {
                    // Premium app icon with refined glow
                    ZStack {
                        // Soft glow behind icon
                        RoundedRectangle(cornerRadius: 32)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(hex: "3B82F6").opacity(glowIntensity),
                                        Color(hex: "3B82F6").opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 180, height: 180)
                            .blur(radius: 40)

                        // Icon container with glass effect
                        RoundedRectangle(cornerRadius: 32)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "4A90F2"),
                                        Color(hex: "3B82F6"),
                                        Color(hex: "2563EB")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay(
                                // Inner highlight
                                RoundedRectangle(cornerRadius: 32)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.05)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: Color(hex: "3B82F6").opacity(0.5), radius: 30, x: 0, y: 15)
                            .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)

                        // Calendar icon
                        Image(systemName: "calendar")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                    // Brand name - elegant typography
                    VStack(spacing: 12) {
                        Text("Clara")
                            .font(.system(size: 44, weight: .light, design: .default))
                            .tracking(6)
                            .foregroundColor(.white)

                        // Elegant divider
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 60, height: 1)

                        // Tagline
                        Text("Your time, elevated")
                            .font(.system(size: 15, weight: .light, design: .default))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .opacity(textOpacity)
                }

                Spacer()
                    .frame(minHeight: 60, maxHeight: 100)

                // Sign in section
                VStack(spacing: 24) {
                    // Error message
                    if let errorMessage = authService.errorMessage {
                        errorBanner(message: errorMessage)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    // Sign in button
                    VStack(spacing: 16) {
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: configureAppleRequest,
                            onCompletion: handleAppleCompletion
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .frame(maxWidth: 280)
                        .cornerRadius(26)
                        .shadow(color: Color.white.opacity(0.08), radius: 20, x: 0, y: 8)
                        .disabled(authService.isLoading)
                        .opacity(authService.isLoading ? 0.5 : 1.0)

                        // Loading state
                        if authService.isLoading {
                            loadingIndicator
                        }
                    }
                }
                .opacity(buttonOpacity)
                .padding(.horizontal, 50)

                Spacer()
                    .frame(minHeight: 50, maxHeight: 80)

                // Footer - minimal and elegant
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .medium))
                        Text("Private & Secure")
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .tracking(1)
                    }
                    .foregroundColor(.white.opacity(0.25))
                }
                .opacity(buttonOpacity)

                Spacer()
                    .frame(height: 50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            animateEntrance()
        }
        .animation(.easeInOut(duration: 0.35), value: authService.isLoading)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: authService.errorMessage)
    }

    // MARK: - Animations

    private func animateEntrance() {
        // Logo animation - smooth spring
        withAnimation(.spring(response: 1.0, dampingFraction: 0.75).delay(0.1)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Text fade in
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
            textOpacity = 1.0
        }

        // Button fade in
        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
            buttonOpacity = 1.0
        }

        // Subtle glow pulse
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(1.0)) {
            glowIntensity = 0.45
        }
    }

    // MARK: - Components

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: "EF4444"))
                .frame(width: 6, height: 6)

            Text(message)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color(hex: "EF4444").opacity(0.9))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "EF4444").opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "EF4444").opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var loadingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                .scaleEffect(0.8)

            Text("Signing in")
                .font(.system(size: 13, weight: .light))
                .tracking(0.5)
                .foregroundColor(.white.opacity(0.4))
        }
        .transition(.opacity)
    }

    // MARK: - Apple Sign In

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        authService.isLoading = true
        authService.errorMessage = nil
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let identityToken = credential.identityToken,
               let tokenString = String(data: identityToken, encoding: .utf8) {
                let authorizationCode = credential.authorizationCode != nil ? String(data: credential.authorizationCode!, encoding: .utf8) : nil
                Task {
                    await authService.handleAppleSignInSuccess(
                        identityToken: tokenString,
                        authorizationCode: authorizationCode,
                        userIdentifier: credential.user,
                        email: credential.email,
                        fullName: credential.fullName
                    )
                }
            } else {
                authService.errorMessage = "Failed to retrieve Apple identity token"
                authService.isLoading = false
            }
        case .failure(let error):
            authService.errorMessage = error.localizedDescription
            authService.isLoading = false
        }
    }
}

// MARK: - Preview

#Preview {
    ClassySignInView()
        .environmentObject(AuthenticationService())
}
