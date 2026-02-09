import Foundation

// MARK: - Unified Today Response
struct UnifiedTodayResponse: Codable {
    let date: String
    let generatedAt: String
    let timezone: String

    // Feature 1: Commitment
    let commitment: DailyCommitmentResponse?

    // Feature 2: Tone
    let toneState: String?

    // Primary insight
    let primaryInsight: PrimaryInsight?

    // Primary recommendation (with commitment UI)
    let primaryRecommendation: PrimaryRecommendation?

    // Feature 3: Calibrated scores
    let energyCalibration: ScoreCalibration?
    let driftCalibration: ScoreCalibration?

    // Core data
    let energyBudget: EnergyBudget?
    let quickStats: QuickStats?
    let suggestions: [BriefingSuggestion]?
    let weekDriftSummary: WeekDriftSummary?

    // Context
    let greeting: String?
    let summaryLine: String?
    let dayType: String?
    let isRestDay: Bool?
    let dataSources: [String: String]?

    enum CodingKeys: String, CodingKey {
        case date, timezone, greeting, suggestions
        case generatedAt = "generated_at"
        case commitment
        case toneState = "tone_state"
        case primaryInsight = "primary_insight"
        case primaryRecommendation = "primary_recommendation"
        case energyCalibration = "energy_calibration"
        case driftCalibration = "drift_calibration"
        case energyBudget = "energy_budget"
        case quickStats = "quick_stats"
        case weekDriftSummary = "week_drift_summary"
        case summaryLine = "summary_line"
        case dayType = "day_type"
        case isRestDay = "is_rest_day"
        case dataSources = "data_sources"
    }
}

// MARK: - Daily Commitment Response
struct DailyCommitmentResponse: Codable {
    let id: Int?
    let date: String?
    let action: String?
    let reason: String?
    let category: String?
    let deepLink: String?
    let confidence: Int?
    let response: String?
    let showCommitmentUI: Bool?

    enum CodingKeys: String, CodingKey {
        case id, date, action, reason, category, confidence, response
        case deepLink = "deep_link"
        case showCommitmentUI = "show_commitment_ui"
    }
}

// MARK: - Primary Insight
struct PrimaryInsight: Codable {
    let headline: String?
    let body: String?
    let severity: String?  // "positive", "info", "warning", "critical"
    let icon: String?
}

// MARK: - Week Drift Summary
struct WeekDriftSummary: Codable {
    let driftScore: Int?
    let severity: String?
    let headline: String?
    let driftCalibration: ScoreCalibration?

    enum CodingKeys: String, CodingKey {
        case driftScore = "drift_score"
        case severity, headline
        case driftCalibration = "drift_calibration"
    }
}
