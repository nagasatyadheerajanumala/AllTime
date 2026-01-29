import Foundation
import SwiftUI

/// Next Day Forecast - Tomorrow's forecast based on pattern intelligence
///
/// Philosophy: Help users prepare for tomorrow with pattern-based predictions.
/// Clara provides:
/// - Tomorrow's calendar analysis (meetings, intensity, timing)
/// - Similar historical days and their outcomes
/// - Energy and outcome predictions based on patterns
/// - Sleep recommendations
/// - Risk signals and actionable interventions
/// - Clara's personalized insight
struct NextDayForecast: Codable {
    // Tomorrow's date info
    let date: String
    let dayOfWeek: String
    let dayLabel: String
    let isWeekend: Bool

    // Calendar metrics
    let meetingCount: Int
    let meetingHours: Double
    let focusHours: Double
    let backToBackCount: Int
    let firstMeetingTime: String?
    let lastMeetingTime: String?
    let hasEarlyMorning: Bool
    let hasLateEvening: Bool
    let intensity: String
    let intensityLabel: String

    // Comparison with today
    let comparedToToday: TomorrowComparison?

    // Pattern-based predictions
    let similarDays: [TomorrowSimilarDayMatch]?
    let prediction: TomorrowDayPrediction?
    let sleepRecommendation: TomorrowSleepRecommendation?

    // Risk signals & interventions
    let riskSignals: [TomorrowRiskSignal]?
    let interventions: [TomorrowIntervention]?

    // Clara's insight
    let claraInsight: String?
    let headline: String
    let subheadline: String?

    // Metadata
    let totalHistoricalDays: Int?
    let generatedAt: String?

    enum CodingKeys: String, CodingKey {
        case date
        case dayOfWeek = "day_of_week"
        case dayLabel = "day_label"
        case isWeekend = "is_weekend"
        case meetingCount = "meeting_count"
        case meetingHours = "meeting_hours"
        case focusHours = "focus_hours"
        case backToBackCount = "back_to_back_count"
        case firstMeetingTime = "first_meeting_time"
        case lastMeetingTime = "last_meeting_time"
        case hasEarlyMorning = "has_early_morning"
        case hasLateEvening = "has_late_evening"
        case intensity
        case intensityLabel = "intensity_label"
        case comparedToToday = "compared_to_today"
        case similarDays = "similar_days"
        case prediction
        case sleepRecommendation = "sleep_recommendation"
        case riskSignals = "risk_signals"
        case interventions
        case claraInsight = "clara_insight"
        case headline
        case subheadline
        case totalHistoricalDays = "total_historical_days"
        case generatedAt = "generated_at"
    }
}

/// Comparison with today's schedule
struct TomorrowComparison: Codable {
    let meetingCountDiff: Int
    let meetingHoursDiff: Double
    let comparisonLabel: String
    let comparisonIcon: String

    enum CodingKeys: String, CodingKey {
        case meetingCountDiff = "meeting_count_diff"
        case meetingHoursDiff = "meeting_hours_diff"
        case comparisonLabel = "comparison_label"
        case comparisonIcon = "comparison_icon"
    }

    var isLighter: Bool {
        meetingHoursDiff < -0.5
    }

    var isHeavier: Bool {
        meetingHoursDiff > 0.5
    }
}

/// Similar historical day match
struct TomorrowSimilarDayMatch: Codable, Identifiable {
    let date: String
    let dayOfWeek: String
    let similarityScore: Int
    let meetingCount: Int
    let meetingHours: Double
    let intensity: String
    let outcomeScore: Int
    let outcomeLabel: String
    let energyLevel: Int?
    let sleepHours: Double?

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case dayOfWeek = "day_of_week"
        case similarityScore = "similarity_score"
        case meetingCount = "meeting_count"
        case meetingHours = "meeting_hours"
        case intensity
        case outcomeScore = "outcome_score"
        case outcomeLabel = "outcome_label"
        case energyLevel = "energy_level"
        case sleepHours = "sleep_hours"
    }

    var outcomeColor: Color {
        if outcomeScore >= 70 {
            return .green
        } else if outcomeScore >= 55 {
            return .blue
        } else if outcomeScore >= 40 {
            return .orange
        } else {
            return .red
        }
    }
}

/// Day prediction based on similar days
struct TomorrowDayPrediction: Codable {
    let predictedOutcome: Int?
    let outcomeLabel: String?
    let outcomeIcon: String?
    let predictedEnergy: Int?
    let energyLabel: String?
    let energyIcon: String?
    let confidence: String?

    enum CodingKeys: String, CodingKey {
        case predictedOutcome = "predicted_outcome"
        case outcomeLabel = "outcome_label"
        case outcomeIcon = "outcome_icon"
        case predictedEnergy = "predicted_energy"
        case energyLabel = "energy_label"
        case energyIcon = "energy_icon"
        case confidence
    }

    var outcomeColor: Color {
        guard let score = predictedOutcome else { return .gray }
        if score >= 65 {
            return .green
        } else if score >= 45 {
            return .orange
        } else {
            return .red
        }
    }

    var energyColor: Color {
        guard let score = predictedEnergy else { return .gray }
        if score >= 65 {
            return .green
        } else if score >= 45 {
            return .orange
        } else {
            return .red
        }
    }
}

/// Sleep recommendation based on historical patterns
struct TomorrowSleepRecommendation: Codable {
    let optimalHours: Double?
    let recommendation: String
    let reason: String?
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case optimalHours = "optimal_hours"
        case recommendation
        case reason
        case icon
    }
}

/// Risk signal for tomorrow
struct TomorrowRiskSignal: Codable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let severity: String

    var severityColor: Color {
        switch severity {
        case "high":
            return .red
        case "medium":
            return .orange
        default:
            return .yellow
        }
    }
}

/// Intervention action for tomorrow
struct TomorrowIntervention: Codable, Identifiable {
    let id: String
    let action: String
    let detail: String
    let icon: String
    let deepLink: String?
    let impact: Int

    enum CodingKeys: String, CodingKey {
        case id
        case action
        case detail
        case icon
        case deepLink = "deep_link"
        case impact
    }
}

// MARK: - Intensity Helpers
extension NextDayForecast {
    var intensityColor: Color {
        switch intensity {
        case "heavy":
            return .red
        case "full":
            return .orange
        case "moderate":
            return .yellow
        case "light":
            return .green
        case "open":
            return .blue
        default:
            return .gray
        }
    }

    var intensityIcon: String {
        switch intensity {
        case "heavy":
            return "flame.fill"
        case "full":
            return "calendar.badge.exclamationmark"
        case "moderate":
            return "calendar"
        case "light":
            return "sun.max.fill"
        case "open":
            return "leaf.fill"
        default:
            return "calendar"
        }
    }

    var hasRisks: Bool {
        (riskSignals?.count ?? 0) > 0
    }

    var hasSimilarDays: Bool {
        (similarDays?.count ?? 0) > 0
    }
}
