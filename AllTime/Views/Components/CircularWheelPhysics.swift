import SwiftUI
import Combine

/// Physics engine for circular wheel with inertia and deceleration
class CircularWheelPhysics: ObservableObject {
    private var velocity: Double = 0
    private var decelerationTimer: Timer?
    private var onRotationUpdate: ((Double) -> Void)?
    private var onComplete: (() -> Void)?
    
    private let friction: Double = 0.95 // Deceleration factor
    private let minVelocity: Double = 0.01 // Minimum velocity to continue
    
    func updateVelocity(velocity: Double) {
        self.velocity = velocity
    }
    
    func startDeceleration(initialVelocity: Double, onRotationUpdate: @escaping (Double) -> Void, onComplete: @escaping () -> Void) {
        stopDeceleration()
        
        self.velocity = initialVelocity
        self.onRotationUpdate = onRotationUpdate
        self.onComplete = onComplete
        
        decelerationTimer = Timer.scheduledTimer(withTimeInterval: 0.008, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Apply friction with cubic easing for smooth deceleration
            self.velocity *= self.friction
            
            // Update rotation with frame time (120fps = 0.008s)
            let deltaRotation = self.velocity * 0.008
            onRotationUpdate(deltaRotation)
            
            // Stop when velocity is too low
            if abs(self.velocity) < self.minVelocity {
                self.stopDeceleration()
                onComplete()
            }
        }
    }
    
    func stopDeceleration() {
        decelerationTimer?.invalidate()
        decelerationTimer = nil
        velocity = 0
        onRotationUpdate = nil
        onComplete = nil
    }
}

