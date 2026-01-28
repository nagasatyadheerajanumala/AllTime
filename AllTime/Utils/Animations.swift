import SwiftUI
import UIKit

// MARK: - Centralized Animation System
struct AppAnimations {

    // MARK: - Ultra-Fast Animations (60fps feel)

    /// Instant response (for immediate feedback - button presses)
    static let instant = Animation.spring(
        response: 0.15,
        dampingFraction: 0.9,
        blendDuration: 0
    )

    /// Snappy response (for taps, selections)
    static let snappy = Animation.spring(
        response: 0.2,
        dampingFraction: 0.85,
        blendDuration: 0
    )

    // MARK: - Spring Animations (Apple-like)

    /// Quick, snappy spring (for buttons, taps)
    static let quickSpring = Animation.spring(
        response: 0.25,
        dampingFraction: 0.8,
        blendDuration: 0
    )

    /// Smooth, fluid spring (for card transitions)
    static let smoothSpring = Animation.spring(
        response: 0.35,
        dampingFraction: 0.82,
        blendDuration: 0
    )

    /// Gentle, bouncy spring (for hero animations)
    static let gentleSpring = Animation.spring(
        response: 0.4,
        dampingFraction: 0.78,
        blendDuration: 0
    )

    /// Slow, elegant spring (for page transitions)
    static let elegantSpring = Animation.spring(
        response: 0.5,
        dampingFraction: 0.85,
        blendDuration: 0
    )

    // MARK: - Easing Animations

    /// Ease out (for exits) - faster
    static let easeOut = Animation.easeOut(duration: 0.2)

    /// Ease in (for entries) - faster
    static let easeIn = Animation.easeIn(duration: 0.2)

    /// Ease in-out (for general transitions) - faster
    static let easeInOut = Animation.easeInOut(duration: 0.25)
    
    // MARK: - Specialized Animations

    /// Card enter animation (fade + slide up) - faster
    static let cardEnter = Animation.spring(
        response: 0.3,
        dampingFraction: 0.85
    )

    /// Card exit animation (fade + slide down) - faster
    static let cardExit = Animation.easeOut(duration: 0.15)

    /// Hero animation (scale + fade) - snappier
    static let hero = Animation.spring(
        response: 0.35,
        dampingFraction: 0.8
    )

    /// Parallax animation (smooth scroll-based)
    static let parallax = Animation.easeOut(duration: 0.3)

    /// Pulse animation (for attention)
    static let pulse = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)

    /// Shimmer animation (for loading) - faster
    static let shimmer = Animation.linear(duration: 1.0).repeatForever(autoreverses: false)

    /// Bounce animation (for playful interactions)
    static let bounce = Animation.spring(
        response: 0.3,
        dampingFraction: 0.5
    )

    /// Sheet presentation animation
    static let sheet = Animation.spring(
        response: 0.35,
        dampingFraction: 0.88
    )

    /// Tab switch animation
    static let tabSwitch = Animation.spring(
        response: 0.25,
        dampingFraction: 0.9
    )

    /// List item animation (for ForEach)
    static let listItem = Animation.spring(
        response: 0.2,
        dampingFraction: 0.85
    )
}

// MARK: - Animation Timing Constants
struct AnimationTiming {
    static let instant: Double = 0.1
    static let quick: Double = 0.15
    static let standard: Double = 0.25
    static let smooth: Double = 0.35
    static let slow: Double = 0.5

    // Stagger delays for choreography - faster
    static let stagger: Double = 0.03
    static let cardStagger: Double = 0.05
}

// MARK: - View Extensions for Easy Animation
extension View {
    /// Apply instant animation for immediate feedback
    func instantAnimation<V: Equatable>(value: V) -> some View {
        self.animation(AppAnimations.instant, value: value)
    }

    /// Apply snappy animation for quick interactions
    func snappyAnimation<V: Equatable>(value: V) -> some View {
        self.animation(AppAnimations.snappy, value: value)
    }

    /// Apply quick spring animation with value binding
    func quickSpringAnimation<V: Equatable>(value: V) -> some View {
        self.animation(AppAnimations.quickSpring, value: value)
    }

    /// Apply smooth spring animation with value binding
    func smoothSpringAnimation<V: Equatable>(value: V) -> some View {
        self.animation(AppAnimations.smoothSpring, value: value)
    }

    /// Apply gentle spring animation with value binding
    func gentleSpringAnimation<V: Equatable>(value: V) -> some View {
        self.animation(AppAnimations.gentleSpring, value: value)
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

// MARK: - Motion Accessibility Support
/// Respects user's "Reduce Motion" accessibility setting
struct MotionManager {
    /// Returns the animation if motion is enabled, nil if reduced motion is preferred
    static func animation(_ animation: Animation, reducedMotion: Bool) -> Animation? {
        reducedMotion ? nil : animation
    }

    /// Returns a simple opacity transition if reduced motion is enabled
    static func transition(_ transition: AnyTransition, reducedMotion: Bool) -> AnyTransition {
        reducedMotion ? .opacity : transition
    }

    /// Returns appropriate spring animation based on motion preference
    static func spring(response: Double = 0.4, dampingFraction: Double = 0.8, reducedMotion: Bool) -> Animation? {
        reducedMotion ? nil : .spring(response: response, dampingFraction: dampingFraction)
    }
}

// MARK: - Motion-Aware View Modifier
/// Applies animation only when user hasn't enabled "Reduce Motion"
struct MotionAwareAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

/// Applies transition only when user hasn't enabled "Reduce Motion"
struct MotionAwareTransitionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let transition: AnyTransition

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? .opacity : transition)
    }
}

extension View {
    /// Apply animation that respects "Reduce Motion" accessibility setting
    func motionAwareAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionAwareAnimationModifier(animation: animation, value: value))
    }

    /// Apply transition that respects "Reduce Motion" accessibility setting
    func motionAwareTransition(_ transition: AnyTransition) -> some View {
        modifier(MotionAwareTransitionModifier(transition: transition))
    }
}

// MARK: - Counting Animation for Numbers
/// Animates a number counting up from 0 to target value
struct CountingAnimation: Animatable, View {
    var value: Double
    let formatter: (Double) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    init(value: Double, formatter: @escaping (Double) -> String = { String(format: "%.0f", $0) }) {
        self.value = value
        self.formatter = formatter
    }

    var body: some View {
        Text(formatter(value))
    }
}

extension View {
    /// Animate a number counting up with the specified duration
    func countingAnimation(from: Double = 0, to: Double, duration: Double = 0.8) -> some View {
        self.modifier(CountingModifier(from: from, to: to, duration: duration))
    }
}

struct CountingModifier: ViewModifier {
    let from: Double
    let to: Double
    let duration: Double
    @State private var currentValue: Double

    init(from: Double, to: Double, duration: Double) {
        self.from = from
        self.to = to
        self.duration = duration
        self._currentValue = State(initialValue: from)
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                withAnimation(.easeOut(duration: duration)) {
                    currentValue = to
                }
            }
    }
}

