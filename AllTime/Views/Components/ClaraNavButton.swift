import SwiftUI

// MARK: - Clara Navigation Bar Button
/// A reusable Clara AI button for navigation bars across all tabs
/// Provides consistent access to Clara from anywhere in the app

struct ClaraNavButton: View {
    @Binding var showingClara: Bool

    private let claraGradient = LinearGradient(
        colors: [DesignSystem.Colors.violet, DesignSystem.Colors.claraPurpleLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingClara = true
        }) {
            ZStack {
                // Gradient background
                Circle()
                    .fill(claraGradient)
                    .frame(width: 32, height: 32)

                // Sparkle icon
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - View Modifier for Easy Integration
/// Use this modifier to add Clara button and sheet to any view
struct ClaraNavigationModifier: ViewModifier {
    @State private var showingClara = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    ClaraNavButton(showingClara: $showingClara)
                }
            }
            .sheet(isPresented: $showingClara) {
                ClaraChatView()
            }
    }
}

// MARK: - View Extension
extension View {
    /// Adds a Clara AI button to the navigation bar with sheet presentation
    func withClaraButton() -> some View {
        modifier(ClaraNavigationModifier())
    }
}
