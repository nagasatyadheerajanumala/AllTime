import Foundation
import SwiftUI

// MARK: - Capacity Analysis Response

struct CapacityAnalysisResponse: Codable {
    let generatedAt: String
    let timezone: String
    let analysisPeriodDays: Int
    let summary: CapacityAnalysisSummary
    let meetingPatterns: MeetingPatternsSummary
    let healthImpact: HealthImpactSummary?
    let insights: [CapacityInsight]?

    // No CodingKeys needed - API returns camelCase which matches Swift property names
}

// MARK: - Capacity Summary

struct CapacityAnalysisSummary: Codable {
    let totalMeetings: Int
    let avgMeetingsPerDay: Double
    let totalMeetingHours: Double
    let highIntensityDays: Int
    let healthImpactedDays: Int
    let overallCapacityStatus: String
    let capacityScore: Int

    // No CodingKeys needed - API returns camelCase

    // Computed properties for display
    var scoreColor: Color {
        if capacityScore >= 70 {
            return Color(hex: "10B981") // Green
        } else if capacityScore >= 40 {
            return Color(hex: "F59E0B") // Orange
        } else {
            return Color(hex: "EF4444") // Red
        }
    }

    var statusText: String {
        switch overallCapacityStatus {
        case "healthy": return "Healthy"
        case "moderate": return "Needs Attention"
        case "overloaded": return "Overloaded"
        default: return overallCapacityStatus.capitalized
        }
    }

    var statusIcon: String {
        switch overallCapacityStatus {
        case "healthy": return "checkmark.shield.fill"
        case "moderate": return "exclamationmark.shield.fill"
        case "overloaded": return "xmark.shield.fill"
        default: return "shield.fill"
        }
    }

    var formattedMeetingHours: String {
        let hours = Int(totalMeetingHours)
        let minutes = Int((totalMeetingHours - Double(hours)) * 60)
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Meeting Patterns Summary

struct MeetingPatternsSummary: Codable {
    let totalMeetings: Int
    let daysWithMeetings: Int
    let avgMeetingsPerDay: Double
    let weeklyTrends: [WeeklyTrendData]?
    let busiestDay: String?
    let avgMeetingsOnBusiestDay: Double?
    let topRepetitiveMeetings: [RepetitiveMeetingInfo]?
    let recentHighIntensityDays: [HighIntensityDayInfo]?
    let backToBackStats: BackToBackStatsInfo?
    let durationAnalysis: DurationAnalysisInfo?
    let insights: [MeetingPatternInsight]?

    // No CodingKeys needed - API returns camelCase
}

struct WeeklyTrendData: Codable, Identifiable {
    let weekNumber: Int
    let weekStartDate: String
    let meetingCount: Int
    let totalMinutes: Int?
    let totalHours: Double?
    let highIntensityDays: Int?

    var id: Int { weekNumber }

    // No CodingKeys needed - API returns camelCase

    var meetingHours: Double {
        totalHours ?? (Double(totalMinutes ?? 0) / 60.0)
    }
}

struct RepetitiveMeetingInfo: Codable, Identifiable {
    let title: String
    let occurrenceCount: Int
    let totalHours: Double
    let avgDurationMinutes: Int
    let frequencyPattern: String

    var id: String { title }

    // No CodingKeys needed - API returns camelCase

    var formattedTotalHours: String {
        let hours = Int(totalHours)
        let minutes = Int((totalHours - Double(hours)) * 60)
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var frequencyLabel: String {
        switch frequencyPattern.lowercased() {
        case "daily": return "Daily"
        case "weekly": return "Weekly"
        case "bi_weekly", "biweekly": return "Bi-weekly"
        case "monthly": return "Monthly"
        default: return frequencyPattern.capitalized
        }
    }
}

struct HighIntensityDayInfo: Codable, Identifiable {
    let date: String
    let meetingCount: Int
    let meetingHours: Double
    let backToBackCount: Int
    let intensityScore: Int

    var id: String { date }

    // No CodingKeys needed - API returns camelCase
}

struct BackToBackStatsInfo: Codable {
    let totalBackToBackPairs: Int
    let daysWithBackToBack: Int
    let avgGapMinutes: Double

    // No CodingKeys needed - API returns camelCase
}

struct DurationAnalysisInfo: Codable {
    let totalMeetingHours: Double
    let avgMeetingDurationMinutes: Int
    let shortMeetings: Int
    let mediumMeetings: Int
    let longMeetings: Int

    // No CodingKeys needed - API returns camelCase
}

struct MeetingPatternInsight: Codable, Identifiable {
    let type: String
    let message: String
    let severity: String

    var id: String { type + message }
}

// MARK: - Health Impact Summary

struct HealthImpactSummary: Codable {
    let dataPointsAnalyzed: Int
    let correlations: [HealthCorrelationInfo]?
    let sleepCorrelation: SleepCorrelationInfo?
    let stressCorrelation: StressCorrelationInfo?
    let activityCorrelation: ActivityCorrelationInfo?
    let recentImpactDays: [HealthImpactDayInfo]?
    let insights: [HealthImpactInsight]?

    // No CodingKeys needed - API returns camelCase
}

struct HealthCorrelationInfo: Codable, Identifiable {
    let factor: String
    let impact: String
    let strength: String
    let description: String

    var id: String { factor }

    var impactColor: Color {
        switch impact.lowercased() {
        case "positive": return Color(hex: "10B981")
        case "negative": return Color(hex: "EF4444")
        default: return Color(hex: "6B7280")
        }
    }

    var impactIcon: String {
        switch impact.lowercased() {
        case "positive": return "arrow.up.circle.fill"
        case "negative": return "arrow.down.circle.fill"
        default: return "minus.circle.fill"
        }
    }
}

struct SleepCorrelationInfo: Codable {
    let avgSleepHighMeetingDays: Double
    let avgSleepLowMeetingDays: Double
    let sleepDifference: Double
    let hasSignificantCorrelation: Bool

    // No CodingKeys needed - API returns camelCase

    var formattedDifference: String {
        let hours = abs(sleepDifference)
        return String(format: "%.1f hours", hours)
    }
}

struct StressCorrelationInfo: Codable {
    let avgHrvHighIntensityDays: Double?
    let avgHrvNormalDays: Double?
    let avgHrHighIntensityDays: Double?
    let avgHrNormalDays: Double?
    let hasSignificantStressCorrelation: Bool

    // No CodingKeys needed - API returns camelCase
}

struct ActivityCorrelationInfo: Codable {
    let avgStepsMeetingDays: Int
    let avgStepsNonMeetingDays: Int
    let stepsDifference: Int
    let hasSignificantActivityImpact: Bool

    // No CodingKeys needed - API returns camelCase

    var formattedDifference: String {
        return "\(abs(stepsDifference).formatted()) steps"
    }
}

struct HealthImpactDayInfo: Codable, Identifiable {
    let date: String
    let meetingCount: Int
    let meetingHours: Double
    let healthMetrics: HealthMetricsSummary?
    let impactLevel: String

    var id: String { date }

    // No CodingKeys needed - API returns camelCase
}

struct HealthMetricsSummary: Codable {
    let sleepHours: Double?
    let steps: Int?
    let avgHr: Int?
    let avgHrv: Int?

    // No CodingKeys needed - API returns camelCase
}

struct HealthImpactInsight: Codable, Identifiable {
    let type: String
    let message: String
    let severity: String

    var id: String { type + message }
}

// MARK: - Capacity Insight

struct CapacityInsight: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let category: String
    let severity: String
    let actionable: String?
    let icon: String?

    var severityColor: Color {
        switch severity.lowercased() {
        case "positive": return Color(hex: "10B981") // Green
        case "info": return Color(hex: "3B82F6") // Blue
        case "warning": return Color(hex: "F59E0B") // Orange
        case "critical": return Color(hex: "EF4444") // Red
        default: return Color(hex: "6B7280") // Gray
        }
    }

    var severityIcon: String {
        if let customIcon = icon, !customIcon.isEmpty {
            return customIcon
        }
        switch severity.lowercased() {
        case "positive": return "checkmark.circle.fill"
        case "info": return "info.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        case "critical": return "xmark.octagon.fill"
        default: return "circle.fill"
        }
    }

    var categoryIcon: String {
        switch category.lowercased() {
        case "meetings": return "calendar"
        case "health": return "heart.fill"
        case "balance": return "scale.3d"
        case "suggestion": return "lightbulb.fill"
        default: return "star.fill"
        }
    }

    var categoryColor: Color {
        switch category.lowercased() {
        case "meetings": return Color(hex: "3B82F6") // Blue
        case "health": return Color(hex: "EC4899") // Pink
        case "balance": return Color(hex: "8B5CF6") // Purple
        case "suggestion": return Color(hex: "10B981") // Green
        default: return Color(hex: "6B7280") // Gray
        }
    }
}
