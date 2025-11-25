import SwiftUI

// MARK: - Centralized Animation System
struct AppAnimations {
    
    // MARK: - Spring Animations (Apple-like)
    
    /// Quick, snappy spring (for buttons, taps)
    static let quickSpring = Animation.spring(
        response: 0.3,
        dampingFraction: 0.7,
        blendDuration: 0.2
    )
    
    /// Smooth, fluid spring (for card transitions)
    static let smoothSpring = Animation.spring(
        response: 0.4,
        dampingFraction: 0.8,
        blendDuration: 0.3
    )
    
    /// Gentle, bouncy spring (for hero animations)
    static let gentleSpring = Animation.spring(
        response: 0.5,
        dampingFraction: 0.75,
        blendDuration: 0.4
    )
    
    /// Slow, elegant spring (for page transitions)
    static let elegantSpring = Animation.spring(
        response: 0.6,
        dampingFraction: 0.85,
        blendDuration: 0.5
    )
    
    // MARK: - Easing Animations
    
    /// Ease out (for exits)
    static let easeOut = Animation.easeOut(duration: 0.3)
    
    /// Ease in (for entries)
    static let easeIn = Animation.easeIn(duration: 0.3)
    
    /// Ease in-out (for general transitions)
    static let easeInOut = Animation.easeInOut(duration: 0.35)
    
    // MARK: - Specialized Animations
    
    /// Card enter animation (fade + slide up)
    static let cardEnter = Animation.spring(
        response: 0.4,
        dampingFraction: 0.8
    )
    
    /// Card exit animation (fade + slide down)
    static let cardExit = Animation.easeOut(duration: 0.25)
    
    /// Hero animation (scale + fade)
    static let hero = Animation.spring(
        response: 0.5,
        dampingFraction: 0.75
    )
    
    /// Parallax animation (smooth scroll-based)
    static let parallax = Animation.easeOut(duration: 0.5)
    
    /// Pulse animation (for attention)
    static let pulse = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    
    /// Shimmer animation (for loading)
    static let shimmer = Animation.linear(duration: 1.5).repeatForever(autoreverses: false)
    
    /// Bounce animation (for playful interactions)
    static let bounce = Animation.spring(
        response: 0.4,
        dampingFraction: 0.5
    )
}

// MARK: - Animation Timing Constants
struct AnimationTiming {
    static let quick: Double = 0.2
    static let standard: Double = 0.3
    static let smooth: Double = 0.4
    static let slow: Double = 0.6
    
    // Stagger delays for choreography
    static let stagger: Double = 0.05
    static let cardStagger: Double = 0.1
}

// MARK: - View Extensions for Easy Animation
extension View {
    /// Apply quick spring animation
    func quickSpring() -> some View {
        self.animation(AppAnimations.quickSpring, value: UUID())
    }
    
    /// Apply smooth spring animation
    func smoothSpring() -> some View {
        self.animation(AppAnimations.smoothSpring, value: UUID())
    }
    
    /// Apply gentle spring animation
    func gentleSpring() -> some View {
        self.animation(AppAnimations.gentleSpring, value: UUID())
    }
    
    /// Apply card enter animation
    func cardEnter(delay: Double = 0) -> some View {
        self
            .opacity(0)
            .offset(y: 20)
            .onAppear {
                withAnimation(AppAnimations.cardEnter.delay(delay)) {
                    // Animation applied via state change
                }
            }
    }
}

// MARK: - Haptic Feedback Helper
struct HapticFeedback {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

