import Foundation

/// Week Drift Status - The forward-looking intelligence that makes Clara non-optional.
///
/// Philosophy: Burnout doesn't come from bad days. It comes from weeks that drift quietly.
/// Clara exists to prevent bad weeks before they happen.
struct WeekDriftStatus: Codable {
    let driftScore: Int          // 0-100 (0=on track, 100=off course)
    let severity: String          // "on_track", "watch", "drifting", "critical"
    let severityLabel: String     // Human-readable severity
    let dayOfWeek: Int            // 1=Monday, 7=Sunday
    let dayLabel: String          // "MONDAY", etc.
    let headline: String          // Main message - the opinionated statement
    let subheadline: String       // Supporting context
    let signals: DriftSignals     // Raw signals that drove the score
    let interventions: [DriftIntervention]  // Specific actions to take
    let weekProjection: String    // What happens if nothing changes

    enum CodingKeys: String, CodingKey {
        case driftScore = "drift_score"
        case severity
        case severityLabel = "severity_label"
        case dayOfWeek = "day_of_week"
        case dayLabel = "day_label"
        case headline
        case subheadline
        case signals
        case interventions
        case weekProjection = "week_projection"
    }
}

/// Drift severity levels
enum DriftSeverity: String, Codable {
    case onTrack = "on_track"
    case watch = "watch"
    case drifting = "drifting"
    case critical = "critical"

    var displayName: String {
        switch self {
        case .onTrack: return "On Track"
        case .watch: return "Watch"
        case .drifting: return "Drifting"
        case .critical: return "Critical"
        }
    }

    var color: String {
        switch self {
        case .onTrack: return "10B981"  // Green
        case .watch: return "F59E0B"     // Amber
        case .drifting: return "F97316"  // Orange
        case .critical: return "EF4444"  // Red
        }
    }

    var icon: String {
        switch self {
        case .onTrack: return "checkmark.circle.fill"
        case .watch: return "eye.fill"
        case .drifting: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
}

/// Raw signals that contribute to drift detection
struct DriftSignals: Codable {
    // Meeting pressure
    let meetingHoursThisWeek: Double
    let meetingHoursRemaining: Double
    let meetingCount: Int
    let backToBackCount: Int
    let eveningEncroachment: Int

    // Baseline comparison
    let baselineMeetingHoursPerWeek: Double
    let varianceFromBaseline: Int  // Percentage

    // Task pressure
    let taskDeferrals: Int
    let overdueCount: Int

    // Health signals
    let sleepDebtHours: Double
    let activityGapPercent: Int

    enum CodingKeys: String, CodingKey {
        case meetingHoursThisWeek = "meeting_hours_this_week"
        case meetingHoursRemaining = "meeting_hours_remaining"
        case meetingCount = "meeting_count"
        case backToBackCount = "back_to_back_count"
        case eveningEncroachment = "evening_encroachment"
        case baselineMeetingHoursPerWeek = "baseline_meeting_hours_per_week"
        case varianceFromBaseline = "variance_from_baseline"
        case taskDeferrals = "task_deferrals"
        case overdueCount = "overdue_count"
        case sleepDebtHours = "sleep_debt_hours"
        case activityGapPercent = "activity_gap_percent"
    }
}

/// Specific intervention - NOT a vague suggestion, but a concrete action
struct DriftIntervention: Codable, Identifiable {
    let id: String           // "reduce_meetings", "protect_evening", etc.
    let action: String       // "Decline or shorten one meeting"
    let detail: String       // Specific context
    let icon: String         // SF Symbol
    let deepLink: String     // Deep link to take action
    let impact: Int          // 1-25 (how much this would help)

    enum CodingKeys: String, CodingKey {
        case id
        case action
        case detail
        case icon
        case deepLink = "deep_link"
        case impact
    }
}
