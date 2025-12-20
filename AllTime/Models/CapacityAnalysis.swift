import Foundation
import SwiftUI

// MARK: - Capacity Analysis Response

struct CapacityAnalysisResponse: Codable {
    let generatedAt: String
    let timezone: String
    let analysisPeriodDays: Int
    let summary: CapacityAnalysisSummary
    let meetingPatterns: MeetingPatternsSummary
    let healthImpact: HealthImpactSummary
    let insights: [CapacityInsight]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case timezone
        case analysisPeriodDays = "analysis_period_days"
        case summary
        case meetingPatterns = "meeting_patterns"
        case healthImpact = "health_impact"
        case insights
    }
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

    enum CodingKeys: String, CodingKey {
        case totalMeetings = "total_meetings"
        case avgMeetingsPerDay = "avg_meetings_per_day"
        case totalMeetingHours = "total_meeting_hours"
        case highIntensityDays = "high_intensity_days"
        case healthImpactedDays = "health_impacted_days"
        case overallCapacityStatus = "overall_capacity_status"
        case capacityScore = "capacity_score"
    }

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

    enum CodingKeys: String, CodingKey {
        case totalMeetings = "total_meetings"
        case daysWithMeetings = "days_with_meetings"
        case avgMeetingsPerDay = "avg_meetings_per_day"
        case weeklyTrends = "weekly_trends"
        case busiestDay = "busiest_day"
        case avgMeetingsOnBusiestDay = "avg_meetings_on_busiest_day"
        case topRepetitiveMeetings = "top_repetitive_meetings"
        case recentHighIntensityDays = "recent_high_intensity_days"
        case backToBackStats = "back_to_back_stats"
        case durationAnalysis = "duration_analysis"
        case insights
    }
}

struct WeeklyTrendData: Codable, Identifiable {
    let weekNumber: Int
    let weekStartDate: String
    let meetingCount: Int
    let meetingHours: Double
    let highIntensityDays: Int

    var id: Int { weekNumber }

    enum CodingKeys: String, CodingKey {
        case weekNumber = "week_number"
        case weekStartDate = "week_start_date"
        case meetingCount = "meeting_count"
        case meetingHours = "meeting_hours"
        case highIntensityDays = "high_intensity_days"
    }
}

struct RepetitiveMeetingInfo: Codable, Identifiable {
    let title: String
    let occurrenceCount: Int
    let totalHours: Double
    let avgDurationMinutes: Int
    let frequencyPattern: String

    var id: String { title }

    enum CodingKeys: String, CodingKey {
        case title
        case occurrenceCount = "occurrence_count"
        case totalHours = "total_hours"
        case avgDurationMinutes = "avg_duration_minutes"
        case frequencyPattern = "frequency_pattern"
    }

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

    enum CodingKeys: String, CodingKey {
        case date
        case meetingCount = "meeting_count"
        case meetingHours = "meeting_hours"
        case backToBackCount = "back_to_back_count"
        case intensityScore = "intensity_score"
    }
}

struct BackToBackStatsInfo: Codable {
    let totalBackToBackPairs: Int
    let daysWithBackToBack: Int
    let avgGapMinutes: Double

    enum CodingKeys: String, CodingKey {
        case totalBackToBackPairs = "total_back_to_back_pairs"
        case daysWithBackToBack = "days_with_back_to_back"
        case avgGapMinutes = "avg_gap_minutes"
    }
}

struct DurationAnalysisInfo: Codable {
    let totalMeetingHours: Double
    let avgMeetingDurationMinutes: Int
    let shortMeetings: Int
    let mediumMeetings: Int
    let longMeetings: Int

    enum CodingKeys: String, CodingKey {
        case totalMeetingHours = "total_meeting_hours"
        case avgMeetingDurationMinutes = "avg_meeting_duration_minutes"
        case shortMeetings = "short_meetings"
        case mediumMeetings = "medium_meetings"
        case longMeetings = "long_meetings"
    }
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

    enum CodingKeys: String, CodingKey {
        case dataPointsAnalyzed = "data_points_analyzed"
        case correlations
        case sleepCorrelation = "sleep_correlation"
        case stressCorrelation = "stress_correlation"
        case activityCorrelation = "activity_correlation"
        case recentImpactDays = "recent_impact_days"
        case insights
    }
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

    enum CodingKeys: String, CodingKey {
        case avgSleepHighMeetingDays = "avg_sleep_high_meeting_days"
        case avgSleepLowMeetingDays = "avg_sleep_low_meeting_days"
        case sleepDifference = "sleep_difference"
        case hasSignificantCorrelation = "has_significant_correlation"
    }

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

    enum CodingKeys: String, CodingKey {
        case avgHrvHighIntensityDays = "avg_hrv_high_intensity_days"
        case avgHrvNormalDays = "avg_hrv_normal_days"
        case avgHrHighIntensityDays = "avg_hr_high_intensity_days"
        case avgHrNormalDays = "avg_hr_normal_days"
        case hasSignificantStressCorrelation = "has_significant_stress_correlation"
    }
}

struct ActivityCorrelationInfo: Codable {
    let avgStepsMeetingDays: Int
    let avgStepsNonMeetingDays: Int
    let stepsDifference: Int
    let hasSignificantActivityImpact: Bool

    enum CodingKeys: String, CodingKey {
        case avgStepsMeetingDays = "avg_steps_meeting_days"
        case avgStepsNonMeetingDays = "avg_steps_non_meeting_days"
        case stepsDifference = "steps_difference"
        case hasSignificantActivityImpact = "has_significant_activity_impact"
    }

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

    enum CodingKeys: String, CodingKey {
        case date
        case meetingCount = "meeting_count"
        case meetingHours = "meeting_hours"
        case healthMetrics = "health_metrics"
        case impactLevel = "impact_level"
    }
}

struct HealthMetricsSummary: Codable {
    let sleepHours: Double?
    let steps: Int?
    let avgHr: Int?
    let avgHrv: Int?

    enum CodingKeys: String, CodingKey {
        case sleepHours = "sleep_hours"
        case steps
        case avgHr = "avg_hr"
        case avgHrv = "avg_hrv"
    }
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
