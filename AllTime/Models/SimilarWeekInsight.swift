import Foundation
import SwiftUI

// MARK: - Similar Week Insight

/// Response from GET /api/v1/health/similar-week
struct SimilarWeekInsight: Codable {
    let hasSimilarWeek: Bool
    let currentPattern: String?
    let similarWeek: SimilarWeekMatch?
    let thatWeekOutcomes: HealthOutcome?
    let prediction: String?
    let recommendation: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case hasSimilarWeek = "has_similar_week"
        case currentPattern = "current_pattern"
        case similarWeek = "similar_week"
        case thatWeekOutcomes = "that_week_outcomes"
        case prediction, recommendation, message
    }
}

struct SimilarWeekMatch: Codable {
    let weekOf: String
    let weekStart: String?
    let similarity: Double
    let pattern: String
    let totalMeetings: Int
    let totalHours: Double

    enum CodingKeys: String, CodingKey {
        case weekOf = "week_of"
        case weekStart = "week_start"
        case similarity, pattern
        case totalMeetings = "total_meetings"
        case totalHours = "total_hours"
    }

    var similarityPercentage: String {
        String(format: "%.0f%%", similarity * 100)
    }
}

struct HealthOutcome: Codable {
    let avgSleep: Double?
    let avgSteps: Int?
    let sleepVsBaseline: String?
    let stepsVsBaseline: String?
    let stressIndicator: String?

    enum CodingKeys: String, CodingKey {
        case avgSleep = "avg_sleep"
        case avgSteps = "avg_steps"
        case sleepVsBaseline = "sleep_vs_baseline"
        case stepsVsBaseline = "steps_vs_baseline"
        case stressIndicator = "stress_indicator"
    }

    var formattedSleep: String {
        guard let sleep = avgSleep else { return "" }
        return String(format: "%.1fh", sleep)
    }

    var formattedSteps: String {
        guard let steps = avgSteps else { return "" }
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }

    var stressColor: Color {
        switch stressIndicator {
        case "elevated": return Color(hex: "EF4444")  // Red
        case "moderate": return Color(hex: "F59E0B")  // Orange
        case "normal", "low": return Color(hex: "10B981")  // Green
        default: return Color(hex: "6B7280")  // Gray
        }
    }
}
