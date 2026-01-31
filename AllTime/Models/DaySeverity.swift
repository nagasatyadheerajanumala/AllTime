import Foundation
import SwiftUI

/// Response from the day-severity API
struct DaySeverityResponse: Codable {
    let days: [String: DayMetrics]
    let dateRange: DateRange
    let problemDay: ProblemDay?

    enum CodingKeys: String, CodingKey {
        case days
        case dateRange = "date_range"
        case problemDay = "problem_day"
    }
}

/// The most problematic day that needs attention
struct ProblemDay: Codable {
    let date: String
    let reason: String
    let loadScore: Int
    let label: String

    enum CodingKeys: String, CodingKey {
        case date, reason, label
        case loadScore = "load_score"
    }
}

/// Metrics for a single day
struct DayMetrics: Codable {
    let date: String
    let eventCount: Int
    let meetingMinutes: Int
    let freeMinutes: Int
    let clashCount: Int
    let backToBackCount: Int
    let severity: String
    let loadScore: Int
    let indicatorIcon: String
    let indicatorColor: String
    let hasClashes: Bool
    let hasBackToBack: Bool
    let longestFocusBlock: Int
    let summary: String

    enum CodingKeys: String, CodingKey {
        case date
        case eventCount = "event_count"
        case meetingMinutes = "meeting_minutes"
        case freeMinutes = "free_minutes"
        case clashCount = "clash_count"
        case backToBackCount = "back_to_back_count"
        case severity
        case loadScore = "load_score"
        case indicatorIcon = "indicator_icon"
        case indicatorColor = "indicator_color"
        case hasClashes = "has_clashes"
        case hasBackToBack = "has_back_to_back"
        case longestFocusBlock = "longest_focus_block"
        case summary
    }

    /// SwiftUI Color from hex string
    var color: Color {
        Color(hex: indicatorColor)
    }

    /// Severity level enum
    var severityLevel: SeverityLevel {
        SeverityLevel(rawValue: severity) ?? .balanced
    }
}

/// Date range info
struct DateRange: Codable {
    let start: String
    let end: String
    let dayCount: Int

    enum CodingKeys: String, CodingKey {
        case start, end
        case dayCount = "day_count"
    }
}

/// Severity levels for days
enum SeverityLevel: String, Codable {
    case balanced = "balanced"
    case moderate = "moderate"
    case heavy = "heavy"
    case overloaded = "overloaded"

    var color: Color {
        switch self {
        case .balanced: return Color(hex: "#34C759")   // Green
        case .moderate: return Color(hex: "#FF9500")   // Orange
        case .heavy: return Color(hex: "#FF6B35")      // Dark orange
        case .overloaded: return Color(hex: "#FF3B30") // Red
        }
    }

    var icon: String {
        switch self {
        case .balanced: return "checkmark.circle.fill"
        case .moderate: return "minus.circle.fill"
        case .heavy: return "exclamationmark.circle.fill"
        case .overloaded: return "flame.fill"
        }
    }

    /// Background opacity for the day bubble based on severity
    var bubbleOpacity: Double {
        switch self {
        case .balanced: return 0.0    // No tint
        case .moderate: return 0.15   // Light tint
        case .heavy: return 0.25      // Medium tint
        case .overloaded: return 0.35 // Strong tint
        }
    }
}
