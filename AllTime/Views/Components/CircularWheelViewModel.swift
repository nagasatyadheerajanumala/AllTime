import Foundation
import Combine
import UIKit
import SwiftUI

/// ViewModel for circular wheel - caches all heavy calculations
@MainActor
class CircularWheelViewModel: ObservableObject {
    @Published var highlightedIndex: Int = 0
    @Published var centerDate: Date = Date()
    @Published var isDragging: Bool = false
    
    // Cached data (computed once, never recalculated)
    private(set) var days: [Date] = []
    private(set) var dayPositions: [CGPoint] = []
    private(set) var eventFlags: [Bool] = []
    private(set) var angleToIndexMap: [Double: Int] = [:]
    
    private let calendar = Calendar.current
    private var events: [Event] = []
    private var displayLink: CADisplayLink?
    private var pendingAngle: Double?
    
    // Apple-grade: Display link for 120fps updates
    init() {
        setupDisplayLink()
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    // MARK: - Display Link
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: DisplayLinkTarget { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateFromDisplayLink()
            }
        }, selector: #selector(DisplayLinkTarget.tick))
        displayLink?.preferredFramesPerSecond = 120 // 120fps
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func updateFromDisplayLink() {
        guard let angle = pendingAngle else { return }
        applyAngleUpdate(angle: angle, animated: false)
        pendingAngle = nil
    }
    
    // MARK: - Data Setup
    
    func setupDays(_ days: [Date], events: [Event]) {
        self.days = days
        self.events = events
        
        // Precompute positions - EXACT same formula as used in view
        // Formula: angle = (index / total) * 2π - π/2
        let radius: CGFloat = 140
        let total = Double(days.count)
        dayPositions = []
        for (index, _) in days.enumerated() {
            // This is the EXACT positioning formula
            let angle = (Double(index) / total) * 2 * Double.pi - Double.pi / 2
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            dayPositions.append(CGPoint(x: x, y: y))
        }
        
        // Precompute event flags
        eventFlags = days.map { date in
            hasEvents(for: date)
        }
        
        // Precompute angle to index mapping (simplified - not needed for current implementation)
        // rebuildAngleMap()
        
        // Initialize highlighted index
        if let selectedIndex = days.firstIndex(where: { calendar.isDate($0, inSameDayAs: centerDate) }) {
            highlightedIndex = selectedIndex
        }
    }
    
    
    // MARK: - Drag Handling
    
    func updateFromDrag(value: DragGesture.Value, center: CGPoint) -> Date? {
        isDragging = true
        
        let touchLocation = value.location
        let relativeX = touchLocation.x - center.x
        let relativeY = touchLocation.y - center.y
        
        // Calculate distance
        let distanceSquared = relativeX * relativeX + relativeY * relativeY
        let distanceFromCenter = sqrt(distanceSquared)
        
        // Hit region check
        let inner: CGFloat = 140 - 35
        let outer: CGFloat = 140 + 35
        guard distanceFromCenter >= inner && distanceFromCenter <= outer else {
            return nil
        }
        
        // Calculate angle from touch - MUST match positioning formula exactly
        // Use standard atan2 (not inverted)
        let touchAngle = atan2(relativeY, relativeX)
        
        // Normalize to 0-2π range
        var angle = touchAngle
        if angle < 0 {
            angle += 2 * .pi
        }
        
        // Store for display link to apply (120fps updates)
        pendingAngle = angle
        
        // Calculate new index (use floor during drag for stability)
        let newIndex = indexFromAngle(angle, useFloor: true)
        
        // Update instantly if changed (no animation during drag)
        if newIndex != highlightedIndex && newIndex >= 0 && newIndex < days.count {
            highlightedIndex = newIndex
            centerDate = days[newIndex]
            return days[newIndex]
        }
        
        return nil
    }
    
    func finishDrag(value: DragGesture.Value, center: CGPoint) -> Date? {
        isDragging = false
        pendingAngle = nil
        
        let touchLocation = value.location
        let relativeX = touchLocation.x - center.x
        let relativeY = touchLocation.y - center.y
        
        let distanceSquared = relativeX * relativeX + relativeY * relativeY
        let distanceFromCenter = sqrt(distanceSquared)
        
        let inner: CGFloat = 140 - 35
        let outer: CGFloat = 140 + 35
        guard distanceFromCenter >= inner && distanceFromCenter <= outer else {
            return nil
        }
        
        // Calculate angle from touch - MUST match positioning formula exactly
        let touchAngle = atan2(relativeY, relativeX)
        
        // Normalize to 0-2π range
        var angle = touchAngle
        if angle < 0 {
            angle += 2 * .pi
        }
        
        // Use round for final snap
        let finalIndex = indexFromAngle(angle, useFloor: false)
        
        if finalIndex != highlightedIndex && finalIndex >= 0 && finalIndex < days.count {
            highlightedIndex = finalIndex
            centerDate = days[finalIndex]
            return days[finalIndex]
        }
        
        return nil
    }
    
    private func applyAngleUpdate(angle: Double, animated: Bool) {
        let newIndex = indexFromAngle(angle, useFloor: true)
        
        guard newIndex != highlightedIndex && newIndex >= 0 && newIndex < days.count else {
            return
        }
        
        if animated {
            withAnimation(.interpolatingSpring(stiffness: 120, damping: 12)) {
                highlightedIndex = newIndex
                centerDate = days[newIndex]
            }
        } else {
            highlightedIndex = newIndex
            centerDate = days[newIndex]
        }
    }
    
    private func indexFromAngle(_ angle: Double, useFloor: Bool) -> Int {
        // CRITICAL: Reverse the EXACT positioning formula
        // Positioning formula: angle = (index / total) * 2π - π/2
        // This means:
        //   index 0 → angle = -π/2 (top, 12 o'clock) → normalized: 3π/2
        //   index total/4 → angle = 0 (right, 3 o'clock) → normalized: 0
        //   index total/2 → angle = π/2 (bottom, 6 o'clock) → normalized: π/2
        //   index 3*total/4 → angle = π (left, 9 o'clock) → normalized: π
        //
        // atan2(relativeY, relativeX) gives:
        //   Top (relativeY < 0, relativeX ≈ 0) → -π/2 → normalized: 3π/2
        //   Right (relativeY ≈ 0, relativeX > 0) → 0 → normalized: 0
        //   Bottom (relativeY > 0, relativeX ≈ 0) → π/2 → normalized: π/2
        //   Left (relativeY ≈ 0, relativeX < 0) → π → normalized: π
        //
        // Reverse formula: index = (angle + π/2) * total / (2π)
        // But we need to convert normalized angle (0-2π) to positioning angle (-π/2 to 3π/2)
        // When angle is 3π/2 to 2π, it represents -π/2 to 0 (top region)
        
        let total = Double(days.count)
        let anglePerDay = 2 * .pi / total
        
        // Convert normalized touch angle (0-2π) to positioning angle (-π/2 to 3π/2)
        var positionAngle: Double
        if angle >= 3 * .pi / 2 {
            // Top region: 3π/2 to 2π → convert to -π/2 to 0
            positionAngle = angle - 2 * .pi
        } else {
            // Other regions: 0 to 3π/2 → keep as is
            positionAngle = angle
        }
        
        // Reverse the positioning formula: index = (positionAngle + π/2) * total / (2π)
        var rawIndex = (positionAngle + .pi / 2) / anglePerDay
        
        // Handle wrap-around to ensure index is in valid range
        rawIndex = rawIndex.truncatingRemainder(dividingBy: total)
        if rawIndex < 0 {
            rawIndex += total
        }
        
        let index = useFloor ? Int(floor(rawIndex)) : Int(rawIndex.rounded())
        return max(0, min(index, days.count - 1))
    }
    
    // MARK: - Tap Gesture Support
    
    /// Handle tap gesture - instantly select the tapped date
    func handleTap(at location: CGPoint, center: CGPoint) -> Date? {
        let relativeX = location.x - center.x
        let relativeY = location.y - center.y
        
        // Calculate distance from center
        let distanceSquared = relativeX * relativeX + relativeY * relativeY
        let distanceFromCenter = sqrt(distanceSquared)
        
        // Hit region check (same as drag)
        let inner: CGFloat = 140 - 35
        let outer: CGFloat = 140 + 35
        guard distanceFromCenter >= inner && distanceFromCenter <= outer else {
            return nil
        }
        
        // Calculate angle from tap
        let touchAngle = atan2(relativeY, relativeX)
        
        // Normalize to 0-2π range
        var angle = touchAngle
        if angle < 0 {
            angle += 2 * .pi
        }
        
        // Get index from angle (use round for tap - exact selection)
        let tappedIndex = indexFromAngle(angle, useFloor: false)
        
        guard tappedIndex >= 0 && tappedIndex < days.count else {
            return nil
        }
        
        // Instantly update highlight
        highlightedIndex = tappedIndex
        centerDate = days[tappedIndex]
        
        return days[tappedIndex]
    }
    
    private func hasEvents(for date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return events.contains { event in
            guard let eventDate = event.startDate else { return false }
            return eventDate >= startOfDay && eventDate < endOfDay
        }
    }
    
    func hasEvents(at index: Int) -> Bool {
        guard index >= 0 && index < eventFlags.count else { return false }
        return eventFlags[index]
    }
    
    func position(at index: Int) -> CGPoint {
        guard index >= 0 && index < dayPositions.count else { return .zero }
        return dayPositions[index]
    }
}

// Helper class for CADisplayLink target
private class DisplayLinkTarget: NSObject {
    let callback: () -> Void
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
        super.init()
    }
    
    @objc func tick() {
        callback()
    }
}

