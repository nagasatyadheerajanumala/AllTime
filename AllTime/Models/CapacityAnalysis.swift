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
    let totalMinutes: Int?
    let totalHours: Double?
    let averageDurationMinutes: Int?
    let frequencyPattern: String?

    var id: String { title }

    var formattedTotalHours: String {
        let hours = Int(totalHours ?? 0)
        let minutes = Int(((totalHours ?? 0) - Double(hours)) * 60)
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var frequencyLabel: String {
        guard let pattern = frequencyPattern else { return "Unknown" }
        switch pattern.lowercased() {
        case "daily": return "Daily"
        case "weekly": return "Weekly"
        case "bi_weekly", "biweekly": return "Bi-weekly"
        case "monthly": return "Monthly"
        default: return pattern.capitalized
        }
    }
}

struct HighIntensityDayInfo: Codable, Identifiable {
    let date: String
    let dayOfWeek: String?
    let meetingCount: Int
    let totalMeetingMinutes: Int?
    let totalMeetingHours: Double?
    let backToBackCount: Int?
    let intensityScore: Int?

    var id: String { date }

    var meetingHours: Double {
        totalMeetingHours ?? (Double(totalMeetingMinutes ?? 0) / 60.0)
    }
}

struct BackToBackStatsInfo: Codable {
    let totalBackToBackOccurrences: Int?
    let daysWithBackToBack: Int?
    let maxBackToBackStreak: Int?
    let averageBackToBackPerDay: Double?
}

struct DurationAnalysisInfo: Codable {
    let averageDurationMinutes: Double?
    let minDurationMinutes: Int?
    let maxDurationMinutes: Int?
    let durationBuckets: [String: Int]?
    let totalMeetingMinutes: Int?
    let totalMeetingHours: Double?
}

struct MeetingPatternInsight: Codable, Identifiable {
    private let _id: String?
    let title: String?
    let description: String?
    let severity: String?

    var id: String { _id ?? UUID().uuidString }

    private enum CodingKeys: String, CodingKey {
        case _id = "id"
        case title, description, severity
    }
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
    private let _id: String?
    let title: String?
    let description: String?
    let type: String?  // "positive" or "negative"
    let strength: String?  // "weak", "moderate", "strong"

    var id: String { _id ?? UUID().uuidString }

    private enum CodingKeys: String, CodingKey {
        case _id = "id"
        case title, description, type, strength
    }

    var impactColor: Color {
        switch (type ?? "").lowercased() {
        case "positive": return Color(hex: "10B981")
        case "negative": return Color(hex: "EF4444")
        default: return Color(hex: "6B7280")
        }
    }

    var impactIcon: String {
        switch (type ?? "").lowercased() {
        case "positive": return "arrow.up.circle.fill"
        case "negative": return "arrow.down.circle.fill"
        default: return "minus.circle.fill"
        }
    }
}

struct SleepCorrelationInfo: Codable {
    let highMeetingDays: Int?
    let lowMeetingDays: Int?
    let noMeetingDays: Int?
    let avgSleepHighMeetingDays: Double?
    let avgSleepLowMeetingDays: Double?
    let avgSleepNoMeetingDays: Double?
    let sleepDifference: Double?
    let correlationStrength: String?
    let hasSignificantCorrelation: Bool?

    var formattedDifference: String {
        let hours = abs(sleepDifference ?? 0)
        return String(format: "%.1f hours", hours)
    }
}

struct StressCorrelationInfo: Codable {
    let highIntensityDays: Int?
    let lowIntensityDays: Int?
    let avgHrHighIntensity: Double?
    let avgHrLowIntensity: Double?
    let hrDifference: Double?
    let avgHrvHighIntensity: Double?
    let avgHrvLowIntensity: Double?
    let hrvDifference: Double?
    let hasHrCorrelation: Bool?
    let hasHrvCorrelation: Bool?

    // Computed property for view compatibility
    var hasSignificantStressCorrelation: Bool {
        (hasHrCorrelation ?? false) || (hasHrvCorrelation ?? false)
    }
}

struct ActivityCorrelationInfo: Codable {
    let meetingDaysCount: Int?
    let freeDaysCount: Int?
    let avgStepsOnMeetingDays: Double?
    let avgStepsOnFreeDays: Double?
    let stepsDifference: Int?
    let avgActiveMinutesOnMeetingDays: Double?
    let avgActiveMinutesOnFreeDays: Double?
    let activeMinutesDifference: Int?
    let hasSignificantActivityImpact: Bool?

    var formattedDifference: String {
        return "\(abs(stepsDifference ?? 0).formatted()) steps"
    }
}

struct HealthImpactDayInfo: Codable, Identifiable {
    let date: String
    let meetingCount: Int
    let totalMeetingMinutes: Int?
    let backToBackCount: Int?
    let healthImpacts: [String]?
    let likelyCause: String?

    var id: String { date }

    // Computed property for display
    var meetingHours: Double {
        Double(totalMeetingMinutes ?? 0) / 60.0
    }
}

struct HealthImpactInsight: Codable, Identifiable {
    private let _id: String?
    let title: String?
    let description: String?
    let category: String?  // sleep, stress, activity, schedule, general
    let priority: String?  // high, medium, low, positive, info

    var id: String { _id ?? UUID().uuidString }

    private enum CodingKeys: String, CodingKey {
        case _id = "id"
        case title, description, category, priority
    }

    var priorityColor: Color {
        switch (priority ?? "").lowercased() {
        case "high": return Color(hex: "EF4444") // Red
        case "medium": return Color(hex: "F59E0B") // Orange
        case "low": return Color(hex: "3B82F6") // Blue
        case "positive": return Color(hex: "10B981") // Green
        case "info": return Color(hex: "6B7280") // Gray
        default: return Color(hex: "6B7280")
        }
    }

    var categoryIcon: String {
        switch (category ?? "").lowercased() {
        case "sleep": return "bed.double.fill"
        case "stress": return "heart.fill"
        case "activity": return "figure.walk"
        case "schedule": return "calendar"
        case "general": return "info.circle.fill"
        default: return "circle.fill"
        }
    }
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
