import Foundation

/// ClaraVoice - Canonical voice constants for Clara's communication.
///
/// All Clara-facing text (fallbacks, directives, errors) must come from this file.
/// This ensures consistent, authoritative voice across the app.
///
/// RULES:
/// 1. No hedging: "might", "could", "perhaps", "maybe" are forbidden
/// 2. No passive closings: "Let me know if you have questions"
/// 3. No apologies: "I'm sorry" / "Unfortunately"
/// 4. Consequence language: "This will cost you X" not "This might affect Y"
/// 5. Verdicts: "You are overloaded" not "You seem busy"
/// 6. Directives end with action: "Protect your time" not "Consider protecting"
struct ClaraVoice {

    // MARK: - Fallback Messages (when API fails)

    /// Use when Clara cannot connect or analyze
    static let analysisUnavailable = "Analysis unavailable. Protect your time today. Do not add commitments without purpose."

    /// Use when data is missing
    static let dataUnavailable = "Data not available. Sync required for full analysis."

    /// Use when health data is missing
    static let healthDataUnavailable = "Health data not synced. Connect HealthKit for cognitive capacity assessment."

    /// Use when calendar is empty
    static let clearCalendar = "Clear calendar. This is rare capacity. Use it for your hardest work."

    // MARK: - Capacity Status

    static func capacityStatus(percent: Int) -> String {
        if percent >= 120 {
            return "Critically overloaded at \(percent)%. Remove commitments immediately."
        } else if percent >= 100 {
            return "Overloaded at \(percent)%. Something must be removed."
        } else if percent >= 80 {
            return "At \(percent)% capacity. One more meeting breaks your day."
        } else if percent >= 60 {
            return "Moderate load at \(percent)%. Guard remaining gaps."
        } else {
            return "Healthy capacity at \(percent)%. Execute your priorities."
        }
    }

    // MARK: - Directive Messages

    /// General daily directive
    static let protectYourTime = "Protect your time. Execute your priorities."

    /// When overloaded
    static let doNotAddMeetings = "Do not add meetings without removing others."

    /// When calendar is clear
    static let useForDeepWork = "Use this time for deep work. Do not let it become drift."

    /// When fatigued
    static let prioritizeRecovery = "Prioritize recovery. Cognitive capacity is compromised."

    // MARK: - Decline Messages

    /// Default professional decline
    static let defaultDecline = """
        I need to decline this meeting. I have conflicting priorities that require my focus during this time.

        If rescheduling is needed, suggest times next week.
        """

    /// Decline due to back-to-back meetings
    static func declineBackToBack(count: Int) -> String {
        return "I need to decline. I have \(count) back-to-back commitments and cannot give this proper attention."
    }

    /// Decline due to capacity
    static func declineCapacity(percent: Int) -> String {
        return "I need to decline. I'm at \(percent)% capacity and cannot add more without compromising quality."
    }

    // MARK: - Summary Messages

    /// For heavy meeting days
    static func heavyMeetingDay(hours: Double, focusPossible: Bool) -> String {
        if focusPossible {
            return String(format: "%.1f hours in meetings. Focus blocks exist—protect them.", hours)
        } else {
            return String(format: "%.1f hours in meetings. No deep work possible today.", hours)
        }
    }

    /// For light days
    static func lightDay(meetings: Int) -> String {
        if meetings == 0 {
            return "Clear day. Execute your hardest work."
        } else {
            return "\(meetings) meetings. Capacity available for focused work."
        }
    }

    // MARK: - Validation

    /// Check if text contains forbidden hedging language
    static func containsHedging(_ text: String) -> Bool {
        let lower = text.lowercased()
        let hedgingPatterns = [
            "might want",
            "could consider",
            "perhaps",
            "maybe you",
            "you may want",
            "i think",
            "it seems like",
            "let me know if",
            "i hope this helps",
            "please try again"
        ]
        return hedgingPatterns.contains { lower.contains($0) }
    }
}
