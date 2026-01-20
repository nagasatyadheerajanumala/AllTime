import SwiftUI

/// Clara branded loading view shown while data loads
/// Displays "clara" with light purple background and rotating taglines
struct ClaraLoadingView: View {
    // Taglines that rotate
    private let taglines = [
        "always one step ahead",
        "plan less, live more",
        "ahead of your schedule"
    ]

    @State private var currentTaglineIndex = 0
    @State private var taglineOpacity: Double = 1.0
    @State private var logoScale: CGFloat = 0.9
    @State private var logoOpacity: Double = 0

    // Light purple gradient for background
    private var lightGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "E9E4F0"),  // Very light purple/lavender
                Color(hex: "DDD6E8"),  // Slightly deeper lavender
                Color(hex: "D4CCE3")   // Soft purple
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Dark mode gradient
    private var darkGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "1E1B4B"),  // Deep indigo
                Color(hex: "171533"),  // Darker indigo
                Color(hex: "0F0D24")   // Very dark
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Background gradient
            (colorScheme == .dark ? darkGradient : lightGradient)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // Clara logo/text
                VStack(spacing: 12) {
                    Text("clara")
                        .font(.system(size: 56, weight: .light, design: .rounded))
                        .tracking(6)
                        .foregroundColor(colorScheme == .dark ? .white : Color(hex: "4A3B5C"))
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    // Subtle dot accent
                    Circle()
                        .fill(DesignSystem.Colors.violet)
                        .frame(width: 6, height: 6)
                        .opacity(logoOpacity)
                }

                Spacer()
                    .frame(height: 30)

                // Tagline
                Text(taglines[currentTaglineIndex])
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : Color(hex: "6B5B7A"))
                    .opacity(taglineOpacity)
                    .animation(.easeInOut(duration: 0.4), value: taglineOpacity)

                Spacer()

                // Subtle loading indicator
                LoadingDotsView()
                    .opacity(logoOpacity * 0.5)
                    .padding(.bottom, 80)
            }
        }
        .onAppear {
            // Animate logo in
            withAnimation(.easeOut(duration: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }

            // Start tagline rotation
            startTaglineRotation()
        }
    }

    private func startTaglineRotation() {
        // Rotate taglines every 2 seconds
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            // Fade out
            withAnimation(.easeInOut(duration: 0.25)) {
                taglineOpacity = 0
            }

            // Change tagline and fade in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                currentTaglineIndex = (currentTaglineIndex + 1) % taglines.count
                withAnimation(.easeInOut(duration: 0.25)) {
                    taglineOpacity = 1.0
                }
            }
        }
    }
}

// MARK: - Loading Dots Animation
struct LoadingDotsView: View {
    @State private var animatingDot = 0

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(DesignSystem.Colors.violet.opacity(animatingDot == index ? 1.0 : 0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDot == index ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.4), value: animatingDot)
            }
        }
        .onAppear {
            // Animate dots in sequence
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                animatingDot = (animatingDot + 1) % 3
            }
        }
    }
}

// MARK: - Preview
#Preview("Light Mode") {
    ClaraLoadingView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    ClaraLoadingView()
        .preferredColorScheme(.dark)
}
