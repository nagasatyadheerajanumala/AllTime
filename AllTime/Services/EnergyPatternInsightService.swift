import Foundation

/// Service for providing energy pattern insights in notifications
/// Caches patterns and generates contextual messages based on user's historical data
@MainActor
class EnergyPatternInsightService {
    static let shared = EnergyPatternInsightService()

    private let apiService = APIService()
    private let cacheService = CacheService.shared

    private let cacheKey = "energy_patterns_cache"
    private let cacheExpiryHours: Double = 24 // Refresh daily

    private var cachedPatterns: [EnergyPatternInsight] = []
    private var lastFetchDate: Date?

    private init() {
        loadCachedPatterns()
    }

    // MARK: - Cache Management

    private func loadCachedPatterns() {
        if let cached = cacheService.loadJSONSync(EnergyPatternsResponse.self, filename: cacheKey) {
            cachedPatterns = cached.patterns
            print("[EnergyPatternInsight] Loaded \(cachedPatterns.count) patterns from cache")
        }
    }

    /// Refresh patterns from API (call periodically or on app launch)
    func refreshPatterns() async {
        do {
            let response = try await apiService.fetchEnergyPatterns()
            cachedPatterns = response.patterns
            lastFetchDate = Date()

            // Cache to disk
            await cacheService.saveJSON(response, filename: cacheKey)
            print("[EnergyPatternInsight] Refreshed \(cachedPatterns.count) patterns")
        } catch {
            print("[EnergyPatternInsight] Failed to refresh: \(error.localizedDescription)")
        }
    }

    // MARK: - Pattern Lookups

    /// Get all patterns for a specific metric (sleep, steps, heart_rate, hrv)
    func patterns(for metric: String) -> [EnergyPatternInsight] {
        cachedPatterns.filter { $0.metric == metric }
    }

    /// Get patterns related to meeting load
    func meetingLoadPatterns() -> [EnergyPatternInsight] {
        cachedPatterns.filter { pattern in
            pattern.pattern.lowercased().contains("meeting")
        }
    }

    /// Get the strongest pattern (highest significance)
    func strongestPattern() -> EnergyPatternInsight? {
        cachedPatterns.first { $0.significance == "strong" } ??
        cachedPatterns.first { $0.significance == "moderate" }
    }

    /// Find pattern matching current day's meeting count
    func patternForMeetingCount(_ count: Int) -> EnergyPatternInsight? {
        // Match patterns like "5+ meetings", "Back-to-back meetings", etc.
        if count >= 5 {
            return cachedPatterns.first { $0.pattern.contains("5+") || $0.pattern.lowercased().contains("heavy") }
        }
        if count >= 3 {
            return cachedPatterns.first { $0.pattern.lowercased().contains("back-to-back") || $0.pattern.lowercased().contains("multiple") }
        }
        return nil
    }

    /// Find pattern for late meetings
    func lateMessagePattern() -> EnergyPatternInsight? {
        cachedPatterns.first { $0.pattern.lowercased().contains("late") }
    }

    /// Find sleep pattern related to heavy meetings
    private func findHeavyMeetingSleepPattern() -> EnergyPatternInsight? {
        cachedPatterns.first { pattern in
            let lowercased = pattern.pattern.lowercased()
            let isMeetingRelated = lowercased.contains("5+") || lowercased.contains("heavy") || lowercased.contains("meeting")
            return isMeetingRelated && pattern.metric == "sleep"
        }
    }

    /// Find steps pattern related to meetings
    private func findMeetingStepsPattern() -> EnergyPatternInsight? {
        cachedPatterns.first { pattern in
            pattern.pattern.lowercased().contains("meeting") && pattern.metric == "steps"
        }
    }

    /// Find back-to-back pattern for a specific metric
    private func findBackToBackPattern(metric: String) -> EnergyPatternInsight? {
        cachedPatterns.first { pattern in
            pattern.pattern.lowercased().contains("back-to-back") && pattern.metric == metric
        }
    }

    /// Find any pattern containing keyword for a metric
    private func findPattern(containing keyword: String, metric: String) -> EnergyPatternInsight? {
        cachedPatterns.first { pattern in
            pattern.pattern.lowercased().contains(keyword.lowercased()) && pattern.metric == metric
        }
    }

    /// Find moderate significance pattern for a metric
    private func findModeratePattern(metric: String) -> EnergyPatternInsight? {
        cachedPatterns.first { pattern in
            pattern.significance == "moderate" && pattern.metric == metric
        }
    }

    /// Find pattern related to light days for a metric
    private func findLightDayPattern(metric: String) -> EnergyPatternInsight? {
        cachedPatterns.first { pattern in
            pattern.comparison.lowercased().contains("light") && pattern.metric == metric
        }
    }

    /// Find positive (non-negative) pattern for a metric
    private func findPositivePattern(metric: String) -> EnergyPatternInsight? {
        cachedPatterns.first { pattern in
            pattern.metric == metric && !pattern.isNegativeImpact
        }
    }

    // MARK: - Morning Notification Insights

    /// Generate a morning insight message based on today's schedule
    func morningInsight(meetingCount: Int, hasLateMeeting: Bool, hasBackToBack: Bool) -> String? {
        // Priority 1: Late meeting warning - most actionable
        if hasLateMeeting, let pattern = lateMessagePattern() {
            let impact = pattern.impact.replacingOccurrences(of: "-", with: "")
            return [
                "Late meeting today. Your data: \(impact) less sleep on these nights. Plan accordingly.",
                "Evening meeting alert. Pattern: \(pattern.impact) sleep. Front-load your hard work.",
                "Late call today. History shows \(impact) sleep impact. Protect your morning energy."
            ].randomElement()!
        }

        // Priority 2: Heavy meeting day (5+ meetings)
        if meetingCount >= 5 {
            if let sleepPattern = findHeavyMeetingSleepPattern() {
                let impact = sleepPattern.impact.replacingOccurrences(of: "-", with: "")
                return [
                    "\(meetingCount) meetings ahead. Your pattern: \(impact) less sleep on heavy days. Pace yourself.",
                    "Heavy day (\(meetingCount) meetings). Data shows \(sleepPattern.comparison). Prioritize rest tonight.",
                    "\(meetingCount) meetings = historically \(impact) less sleep. Don't overcommit today."
                ].randomElement()!
            }
            if let stepsPattern = findMeetingStepsPattern() {
                return [
                    "\(meetingCount) meetings typically cost you \(stepsPattern.impact) steps. Walk between calls?",
                    "Heavy day ahead. Pattern: \(stepsPattern.impact) steps on meeting days. Schedule a walk.",
                    "\(meetingCount) meetings. Your data: \(stepsPattern.comparison). Move when you can."
                ].randomElement()!
            }
        }

        // Priority 3: Back-to-back meetings
        if hasBackToBack {
            if let hrvPattern = findBackToBackPattern(metric: "hrv") {
                return [
                    "Back-to-back meetings detected. Pattern: \(hrvPattern.impact) HRV. Build in 5-min buffers.",
                    "Consecutive meetings today. Your HRV drops \(hrvPattern.impact) on these days. Breathe.",
                    "Back-to-back schedule. History: \(hrvPattern.impact) recovery. Quick breaks matter."
                ].randomElement()!
            }
            if let pattern = findPattern(containing: "back-to-back", metric: "sleep") ?? findPattern(containing: "back-to-back", metric: "steps") {
                return "Back-to-back meetings ahead. Pattern: \(pattern.impact) \(pattern.metricDisplayName.lowercased()). Take breaks."
            }
        }

        // Priority 4: Moderate meeting load (3-4) with pattern context
        if meetingCount >= 3 && meetingCount < 5 {
            if let pattern = cachedPatterns.first(where: { $0.metric == "sleep" && ($0.significance == "moderate" || $0.significance == "strong") }) {
                return [
                    "\(meetingCount) meetings today. Your data: \(pattern.comparison).",
                    "Moderate load (\(meetingCount) meetings). Pattern insight: \(pattern.impact) sleep impact.",
                    "\(meetingCount) meetings. History shows: \(pattern.comparison). Plan your energy."
                ].randomElement()!
            }
        }

        // Priority 5: Any strong pattern as a general heads-up
        if let strongPattern = cachedPatterns.first(where: { $0.significance == "strong" && $0.isNegativeImpact }) {
            if meetingCount >= 4 {
                return "Pattern alert: \(strongPattern.pattern) → \(strongPattern.impact) \(strongPattern.metricDisplayName.lowercased()). Today qualifies."
            }
        }

        return nil
    }

    /// Generate insight for a specific sleep deficit
    func sleepDeficitInsight(sleepHours: Double) -> String? {
        guard sleepHours < 7 else { return nil }

        // Find sleep-related pattern
        if let sleepPattern = cachedPatterns.first(where: { $0.metric == "sleep" && $0.significance == "strong" }) {
            return "Running on \(String(format: "%.1f", sleepHours))h sleep. Your pattern: \(sleepPattern.comparison)."
        }

        return nil
    }

    // MARK: - Evening Notification Insights

    /// Generate evening insight based on today's activity
    func eveningInsight(meetingCount: Int, hadLateMeeting: Bool, hadBackToBack: Bool) -> String? {
        // Priority 1: Heavy meeting day recovery advice (most important)
        if meetingCount >= 5 {
            let sleepPattern = findHeavyMeetingSleepPattern()
            if let pattern = sleepPattern {
                let impact = pattern.impact.replacingOccurrences(of: "-", with: "")
                return [
                    "\(meetingCount) meetings done. Pattern: \(impact) less sleep tonight. Wind down early — you've earned it.",
                    "Heavy day survived (\(meetingCount) meetings). Your data: \(impact) sleep impact. Skip the late-night scroll.",
                    "\(meetingCount)-meeting day complete. History: \(pattern.comparison). Bed early = better tomorrow."
                ].randomElement()!
            }
            let stepsPattern = findMeetingStepsPattern()
            if let pattern = stepsPattern {
                let impact = pattern.impact.replacingOccurrences(of: "-", with: "")
                return [
                    "\(meetingCount) meetings = \(impact) fewer steps today. Quick walk before dinner?",
                    "Meeting marathon done. Pattern: \(impact) steps lost. 10-min walk recovers some.",
                    "Heavy day (\(meetingCount) meetings). You typically miss \(impact) steps. Move before winding down."
                ].randomElement()!
            }
        }

        // Priority 2: Late meeting impact — immediate recovery advice
        if hadLateMeeting, let pattern = lateMessagePattern() {
            let impact = pattern.impact.replacingOccurrences(of: "-", with: "")
            return [
                "Late meeting today. Pattern: \(impact) less sleep. Skip screens, start wind-down now.",
                "Evening call done. Your data: \(impact) sleep impact. Blue light off, relax mode on.",
                "Late meeting night. History: \(impact) less rest. Melatonin-friendly activities only."
            ].randomElement()!
        }

        // Priority 3: Back-to-back recovery — stress relief
        if hadBackToBack {
            if let hrvPattern = findBackToBackPattern(metric: "hrv") {
                return [
                    "Back-to-back day done. HRV impact: \(hrvPattern.impact). Recovery mode: no screens for 30min.",
                    "Consecutive meetings drain recovery (\(hrvPattern.impact) HRV). Tonight: early bed, no doom-scrolling.",
                    "Back-to-back survived. Pattern: \(hrvPattern.impact) HRV drop. Breathwork or walk recommended."
                ].randomElement()!
            }
            if let pattern = findPattern(containing: "back-to-back", metric: "sleep") ?? findPattern(containing: "back-to-back", metric: "steps") {
                return "Back-to-back meetings done. Pattern: \(pattern.impact) \(pattern.metricDisplayName.lowercased()). Recovery time."
            }
        }

        // Priority 4: Moderate day with pattern context (4 meetings)
        if meetingCount == 4 {
            if let pattern = findModeratePattern(metric: "sleep") {
                return [
                    "\(meetingCount) meetings done. Pattern: \(pattern.comparison). Normal rest tonight.",
                    "Moderate day (\(meetingCount) meetings). Your data: \(pattern.impact) sleep. Standard wind-down.",
                    "\(meetingCount)-meeting day. History: \(pattern.comparison). Nothing special needed."
                ].randomElement()!
            }
        }

        // Priority 5: Light day celebration — reinforce positive patterns
        if meetingCount <= 2 {
            if let pattern = findLightDayPattern(metric: "sleep") {
                return [
                    "Light day (\(meetingCount) meetings). Pattern: better sleep tonight. \(pattern.comparison).",
                    "Easy schedule today. Your data: \(pattern.comparison). Enjoy the quality rest.",
                    "\(meetingCount) meetings = prime recovery night. Pattern: \(pattern.impact) better sleep."
                ].randomElement()!
            }
            if let pattern = findPositivePattern(metric: "steps") {
                return "Light meeting day. Pattern: \(pattern.comparison). Your body thanks you."
            }
        }

        return nil
    }

    /// Get a proactive health tip based on patterns
    func proactiveHealthTip() -> String? {
        // Find the strongest negative impact pattern
        guard let strongPattern = cachedPatterns.first(where: { $0.significance == "strong" && $0.isNegativeImpact }) else {
            return nil
        }

        switch strongPattern.metric {
        case "sleep":
            return "Pattern insight: \(strongPattern.pattern) → \(strongPattern.impact) sleep. Protect your evenings."
        case "steps":
            return "Pattern: \(strongPattern.pattern) costs \(strongPattern.impact) steps. Schedule walking meetings?"
        case "heart_rate":
            return "Your HR spikes (\(strongPattern.impact)) on \(strongPattern.pattern.lowercased()) days. Breathing breaks help."
        case "hrv":
            return "HRV drops (\(strongPattern.impact)) on \(strongPattern.pattern.lowercased()) days. Recovery matters."
        default:
            return nil
        }
    }

    // MARK: - Summary Stats for Notifications

    /// Get a compelling pattern stat for notifications
    func compellingPatternStat() -> (title: String, detail: String)? {
        guard let pattern = strongestPattern() else { return nil }

        let title: String
        switch pattern.metric {
        case "sleep":
            title = "Sleep Impact"
        case "steps":
            title = "Activity Impact"
        case "heart_rate":
            title = "Stress Signal"
        case "hrv":
            title = "Recovery Impact"
        default:
            title = "Pattern Found"
        }

        let detail = "\(pattern.pattern): \(pattern.impact)"
        return (title, detail)
    }

    /// Check if user has any strong negative patterns (for urgent notifications)
    var hasStrongNegativePattern: Bool {
        cachedPatterns.contains { $0.significance == "strong" && $0.isNegativeImpact }
    }

    /// Get all patterns formatted for display
    func allPatternsFormatted() -> [String] {
        cachedPatterns.map { "\($0.pattern): \($0.impact) (\($0.metricDisplayName))" }
    }
}
