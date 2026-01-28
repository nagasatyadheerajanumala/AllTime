import SwiftUI
import UIKit

// MARK: - Haptic Feedback Manager

/// Centralized haptic feedback manager for consistent tactile responses
final class HapticManager {
    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        // Prepare generators for faster response
        prepareGenerators()
    }

    func prepareGenerators() {
        lightImpact.prepare()
        mediumImpact.prepare()
        selectionFeedback.prepare()
    }

    /// Light tap feedback - for toggles, selections
    func lightTap() {
        lightImpact.impactOccurred()
    }

    /// Medium tap feedback - for button presses
    func mediumTap() {
        mediumImpact.impactOccurred()
    }

    /// Heavy tap feedback - for significant actions
    func heavyTap() {
        heavyImpact.impactOccurred()
    }

    /// Soft tap feedback - for gentle interactions
    func softTap() {
        softImpact.impactOccurred()
    }

    /// Rigid tap feedback - for firm interactions
    func rigidTap() {
        rigidImpact.impactOccurred()
    }

    /// Selection changed feedback - for picker changes
    func selectionChanged() {
        selectionFeedback.selectionChanged()
    }

    /// Success notification - for successful actions
    func success() {
        notificationFeedback.notificationOccurred(.success)
    }

    /// Warning notification - for warnings
    func warning() {
        notificationFeedback.notificationOccurred(.warning)
    }

    /// Error notification - for errors
    func error() {
        notificationFeedback.notificationOccurred(.error)
    }

    /// Custom intensity impact
    func impact(intensity: CGFloat) {
        mediumImpact.impactOccurred(intensity: intensity)
    }
}

// MARK: - Smooth Animation Presets

extension Animation {
    /// Smooth spring for most UI interactions
    static let smoothSpring = Animation.spring(response: 0.35, dampingFraction: 0.75)

    /// Quick spring for buttons and toggles
    static let quickSpring = Animation.spring(response: 0.25, dampingFraction: 0.7)

    /// Bouncy spring for fun interactions
    static let bouncySpring = Animation.spring(response: 0.4, dampingFraction: 0.6)

    /// Gentle spring for subtle animations
    static let gentleSpring = Animation.spring(response: 0.5, dampingFraction: 0.8)

    /// Snappy animation for immediate feedback
    static let snappy = Animation.easeOut(duration: 0.2)

    /// Smooth fade
    static let smoothFade = Animation.easeInOut(duration: 0.25)

    /// Card presentation animation
    static let cardPresent = Animation.spring(response: 0.4, dampingFraction: 0.78)

    /// List item animation with stagger support
    static func staggered(index: Int, baseDelay: Double = 0.03) -> Animation {
        Animation.spring(response: 0.35, dampingFraction: 0.75)
            .delay(Double(index) * baseDelay)
    }
}

// MARK: - View Modifiers for Smooth Interactions

/// Adds press effect to any view
struct PressEffectModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
            .animation(.quickSpring, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticManager.shared.lightTap()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

/// Adds bounce effect on tap
struct BounceEffectModifier: ViewModifier {
    @State private var isBouncing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isBouncing ? 0.92 : 1.0)
            .animation(.bouncySpring, value: isBouncing)
            .onTapGesture {
                isBouncing = true
                HapticManager.shared.mediumTap()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isBouncing = false
                }
            }
    }
}

/// Smooth fade-in animation on appear
struct FadeInModifier: ViewModifier {
    @State private var appeared = false
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .onAppear {
                withAnimation(.smoothSpring.delay(delay)) {
                    appeared = true
                }
            }
    }
}

/// Slide up animation on appear
struct SlideUpModifier: ViewModifier {
    @State private var appeared = false
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(.cardPresent.delay(delay)) {
                    appeared = true
                }
            }
    }
}

// MARK: - Enhanced Staggered Appear Animation

/// Comprehensive staggered appear animation with accessibility support
/// Use this for choreographed content reveals where items appear sequentially
struct StaggeredAppearModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let index: Int
    let baseDelay: Double
    let duration: Double
    let offset: CGFloat
    let scale: CGFloat
    @State private var isVisible = false

    init(index: Int, baseDelay: Double = 0.05, duration: Double = 0.03, offset: CGFloat = 15, scale: CGFloat = 0.97) {
        self.index = index
        self.baseDelay = baseDelay
        self.duration = duration
        self.offset = offset
        self.scale = scale
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (isVisible ? 0 : offset))
            .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : scale))
            .animation(
                reduceMotion ? .none : .spring(response: 0.28, dampingFraction: 0.85)
                    .delay(baseDelay + Double(index) * duration),
                value: isVisible
            )
            .onAppear {
                Task { @MainActor in
                    isVisible = true
                }
            }
            .onDisappear {
                isVisible = false
            }
    }
}

/// Card-specific staggered animation with more pronounced effect
struct CardStaggerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (isVisible ? 0 : 20))  // Reduced offset
            .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : 0.95))  // Less scale change
            .animation(
                reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.85)  // Faster, snappier
                    .delay(0.05 + Double(index) * 0.04),  // Faster stagger
                value: isVisible
            )
            .onAppear {
                // Use Task for cleaner async handling
                Task { @MainActor in
                    isVisible = true
                }
            }
            .onDisappear {
                isVisible = false
            }
    }
}

/// Grid item staggered animation (for LazyVGrid patterns)
struct GridStaggerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let row: Int
    let column: Int
    let totalColumns: Int
    @State private var isVisible = false

    private var index: Int {
        row * totalColumns + column
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : 0.9))
            .animation(
                reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.8)
                    .delay(0.1 + Double(index) * 0.04),
                value: isVisible
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    isVisible = true
                }
            }
            .onDisappear {
                isVisible = false
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Adds a press effect (scale down on press)
    func pressEffect() -> some View {
        modifier(PressEffectModifier())
    }

    /// Adds a bounce effect on tap
    func bounceOnTap() -> some View {
        modifier(BounceEffectModifier())
    }

    /// Fade in animation on appear
    func fadeIn(delay: Double = 0) -> some View {
        modifier(FadeInModifier(delay: delay))
    }

    /// Slide up animation on appear
    func slideUp(delay: Double = 0) -> some View {
        modifier(SlideUpModifier(delay: delay))
    }

    /// Staggered animation for list items (legacy - use staggeredAppear instead)
    func staggeredAnimation(index: Int, baseDelay: Double = 0.05) -> some View {
        self
            .opacity(0)
            .onAppear {
                withAnimation(.staggered(index: index, baseDelay: baseDelay)) {
                    // Animation handled by modifier
                }
            }
    }

    /// Enhanced staggered appear animation with accessibility support
    /// Use for choreographed content reveals where items appear sequentially
    func staggeredAppear(index: Int, baseDelay: Double = 0.1) -> some View {
        modifier(StaggeredAppearModifier(index: index, baseDelay: baseDelay))
    }

    /// Card-specific staggered animation with more pronounced effect
    /// Use for hero cards, insights cards, and featured content
    func cardStagger(index: Int) -> some View {
        modifier(CardStaggerModifier(index: index))
    }

    /// Grid item staggered animation
    /// Use for LazyVGrid layouts where items appear in a wave pattern
    func gridStagger(row: Int, column: Int, totalColumns: Int = 2) -> some View {
        modifier(GridStaggerModifier(row: row, column: column, totalColumns: totalColumns))
    }

    /// Smooth transition for content changes
    func smoothTransition() -> some View {
        self.transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    /// Add light haptic on tap
    func hapticOnTap(_ style: HapticStyle = .light) -> some View {
        self.onTapGesture {
            switch style {
            case .light:
                HapticManager.shared.lightTap()
            case .medium:
                HapticManager.shared.mediumTap()
            case .heavy:
                HapticManager.shared.heavyTap()
            case .success:
                HapticManager.shared.success()
            case .selection:
                HapticManager.shared.selectionChanged()
            }
        }
    }
}

enum HapticStyle {
    case light, medium, heavy, success, selection
}

// MARK: - Smooth Button Style

/// A button style with smooth press feedback
struct SmoothButtonStyle: ButtonStyle {
    let hapticStyle: HapticStyle

    init(haptic: HapticStyle = .light) {
        self.hapticStyle = haptic
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.quickSpring, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    switch hapticStyle {
                    case .light:
                        HapticManager.shared.lightTap()
                    case .medium:
                        HapticManager.shared.mediumTap()
                    case .heavy:
                        HapticManager.shared.heavyTap()
                    case .success:
                        HapticManager.shared.success()
                    case .selection:
                        HapticManager.shared.selectionChanged()
                    }
                }
            }
    }
}

// MARK: - Smooth Card Style

/// A card style with hover and press effects
struct SmoothCard: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(
                color: Color.black.opacity(isHovered ? 0.1 : 0.05),
                radius: isHovered ? 12 : 8,
                x: 0,
                y: isHovered ? 6 : 4
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.smoothSpring, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func smoothCard() -> some View {
        modifier(SmoothCard())
    }
}

// MARK: - Loading Overlay

/// Smooth loading overlay
struct LoadingOverlay: View {
    let isLoading: Bool
    let message: String?

    init(isLoading: Bool, message: String? = nil) {
        self.isLoading = isLoading
        self.message = message
    }

    var body: some View {
        ZStack {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.white)

                    if let message = message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
                .padding(24)
                .background(Color(.systemGray5).opacity(0.9))
                .cornerRadius(16)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.smoothSpring, value: isLoading)
    }
}

// MARK: - Previews

#Preview("Button Styles") {
    VStack(spacing: 20) {
        Button("Smooth Button") {}
            .buttonStyle(SmoothButtonStyle())
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)

        Text("Press Effect")
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
            .pressEffect()

        Text("Bounce on Tap")
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(12)
            .bounceOnTap()
    }
    .padding()
}
