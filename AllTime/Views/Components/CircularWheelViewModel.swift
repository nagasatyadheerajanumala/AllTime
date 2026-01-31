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
    @Published var severityLoaded: Bool = false
    @Published var problemDay: ProblemDay?

    // Cached data (computed once, never recalculated)
    private(set) var days: [Date] = []
    private(set) var dayPositions: [CGPoint] = []
    private(set) var eventFlags: [Bool] = []
    private(set) var eventCounts: [Int] = []  // Number of events per day
    private(set) var daySeverities: [String: DayMetrics] = [:]  // Day severity data by date string
    private(set) var problemDayDate: String?  // The most problematic day's date string
    private(set) var angleToIndexMap: [Double: Int] = [:]

    private let calendar = Calendar.current
    private var events: [Event] = []
    private var displayLink: CADisplayLink?
    private var pendingAngle: Double?
    private let apiService = APIService()
    
    // Apple-grade: Display link for 120fps updates (only active during drag)
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
        displayLink?.preferredFramesPerSecond = 120
        displayLink?.isPaused = true  // Start paused - only run during drag
        displayLink?.add(to: .main, forMode: .common)
    }

    private func updateFromDisplayLink() {
        guard let angle = pendingAngle else { return }
        applyAngleUpdate(angle: angle, animated: false)
        pendingAngle = nil
    }

    /// Resume display link during drag
    private func resumeDisplayLink() {
        displayLink?.isPaused = false
    }

    /// Pause display link when idle
    private func pauseDisplayLink() {
        displayLink?.isPaused = true
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
        
        // Precompute event flags and counts
        eventFlags = days.map { date in
            hasEvents(for: date)
        }
        eventCounts = days.map { date in
            countEvents(for: date)
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
        // Resume display link on first drag
        if !isDragging {
            isDragging = true
            resumeDisplayLink()
        }

        let touchLocation = value.location
        let relativeX = touchLocation.x - center.x
        let relativeY = touchLocation.y - center.y

        // Calculate distance using squared values (avoid expensive sqrt)
        let distanceSquared = relativeX * relativeX + relativeY * relativeY

        // Hit region check using squared distances
        let innerSquared: CGFloat = 105 * 105  // (140 - 35)²
        let outerSquared: CGFloat = 175 * 175  // (140 + 35)²
        guard distanceSquared >= innerSquared && distanceSquared <= outerSquared else {
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
        pauseDisplayLink()  // Stop 120fps updates immediately

        let touchLocation = value.location
        let relativeX = touchLocation.x - center.x
        let relativeY = touchLocation.y - center.y

        // Use squared distance (avoid sqrt)
        let distanceSquared = relativeX * relativeX + relativeY * relativeY
        let innerSquared: CGFloat = 105 * 105
        let outerSquared: CGFloat = 175 * 175
        guard distanceSquared >= innerSquared && distanceSquared <= outerSquared else {
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

        // Use squared distance (avoid sqrt)
        let distanceSquared = relativeX * relativeX + relativeY * relativeY
        let innerSquared: CGFloat = 105 * 105
        let outerSquared: CGFloat = 175 * 175
        guard distanceSquared >= innerSquared && distanceSquared <= outerSquared else {
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

    private func countEvents(for date: Date) -> Int {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return events.filter { event in
            guard let eventDate = event.startDate else { return false }
            return eventDate >= startOfDay && eventDate < endOfDay
        }.count
    }

    func hasEvents(at index: Int) -> Bool {
        guard index >= 0 && index < eventFlags.count else { return false }
        return eventFlags[index]
    }

    func eventCount(at index: Int) -> Int {
        guard index >= 0 && index < eventCounts.count else { return 0 }
        return eventCounts[index]
    }

    func position(at index: Int) -> CGPoint {
        guard index >= 0 && index < dayPositions.count else { return .zero }
        return dayPositions[index]
    }

    // MARK: - Day Severity

    /// Get severity for a specific date
    func severity(at index: Int) -> DayMetrics? {
        guard index >= 0 && index < days.count else { return nil }
        let dateString = formatDateString(days[index])
        return daySeverities[dateString]
    }

    /// Get severity level for a specific date
    func severityLevel(at index: Int) -> SeverityLevel {
        guard let metrics = severity(at: index) else { return .balanced }
        return metrics.severityLevel
    }

    /// Fetch day severity data from API
    func loadSeverityData() async {
        do {
            let timezone = TimeZone.current.identifier
            let response = try await apiService.getDaySeverity(days: 45, timezone: timezone)
            daySeverities = response.days
            problemDay = response.problemDay
            problemDayDate = response.problemDay?.date
            severityLoaded = true
            print("✅ Loaded severity for \(daySeverities.count) days, problem day: \(problemDayDate ?? "none")")
        } catch {
            print("⚠️ Failed to load day severity: \(error)")
            // Don't block UI on failure - severity is enhancement, not critical
        }
    }

    /// Check if the date at index is the problem day
    func isProblemDay(at index: Int) -> Bool {
        guard let problemDate = problemDayDate,
              index >= 0 && index < days.count else { return false }
        let dateString = formatDateString(days[index])
        return dateString == problemDate
    }

    private func formatDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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

