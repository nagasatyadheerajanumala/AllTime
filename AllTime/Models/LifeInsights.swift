import SwiftUI

// MARK: - Life Insights Response
/// Main response from the AI-generated life insights endpoint.
struct LifeInsightsResponse: Codable {
    let rangeStart: String
    let rangeEnd: String
    let mode: String // "30day" or "60day"
    let generatedAt: String?

    let headline: String?
    let yourLifePatterns: [LifeInsightItem]?
    let whatWentWell: [LifeInsightItem]?
    let patternsToWatch: [LifeInsightItem]?
    let nextWeekFocus: [LifeActionItem]?
    let recommendations: LifeRecommendations?
    let keyMetrics: [LifeKeyMetric]?

    // New enhanced insight sections
    let futureImpact: FutureImpact?
    let recoveryDebt: RecoveryDebt?
    let cognitiveForecast: CognitiveForecast?

    enum CodingKeys: String, CodingKey {
        case rangeStart = "range_start"
        case rangeEnd = "range_end"
        case mode
        case generatedAt = "generated_at"
        case headline
        case yourLifePatterns = "your_life_patterns"
        case whatWentWell = "what_went_well"
        case patternsToWatch = "patterns_to_watch"
        case nextWeekFocus = "next_week_focus"
        case recommendations
        case keyMetrics = "key_metrics"
        case futureImpact = "future_impact"
        case recoveryDebt = "recovery_debt"
        case cognitiveForecast = "cognitive_forecast"
    }
}

// MARK: - Life Insight Item
struct LifeInsightItem: Codable, Identifiable {
    var id: String { title }

    let title: String
    let detail: String?
    let icon: String?
    let sentiment: String? // "positive", "neutral", "negative"

    // Enhanced insight fields - decisive, not descriptive
    let severity: String? // "critical", "moderate", "mild"
    let consequence: String? // What happens if ignored
    let prescription: String? // What to do about it
    let trend: String? // "worsening", "improving", "stable", "new"
    let vsBaseline: String? // Comparison to normal
    let trendDetail: String? // How long this has been happening

    enum CodingKeys: String, CodingKey {
        case title, detail, icon, sentiment
        case severity, consequence, prescription, trend
        case vsBaseline = "vs_baseline"
        case trendDetail = "trend_detail"
    }

    var displayIcon: String {
        icon ?? "lightbulb.fill"
    }

    var sentimentColor: Color {
        switch sentiment {
        case "positive":
            return DesignSystem.Colors.emerald // Green
        case "negative":
            return DesignSystem.Colors.errorRed // Red
        default:
            return DesignSystem.Colors.blue // Blue
        }
    }

    var severityColor: Color {
        switch severity {
        case "critical":
            return DesignSystem.Colors.errorRed
        case "moderate":
            return DesignSystem.Colors.amber
        default:
            return DesignSystem.Colors.blue
        }
    }

    var trendIcon: String? {
        switch trend {
        case "worsening": return "arrow.up.right"
        case "improving": return "arrow.down.right"
        case "stable": return "arrow.right"
        case "new": return "sparkles"
        default: return nil
        }
    }

    var hasPrescription: Bool {
        prescription != nil && !prescription!.isEmpty
    }

    var hasConsequence: Bool {
        consequence != nil && !consequence!.isEmpty
    }
}

// MARK: - Life Action Item
struct LifeActionItem: Codable, Identifiable {
    var id: String { title }

    let title: String
    let detail: String?
    let icon: String?
    let priority: String? // "high", "medium", "low"
    let actionType: String? // "protect_time", "add_buffer", "reduce_load", "schedule_activity"

    enum CodingKeys: String, CodingKey {
        case title, detail, icon, priority
        case actionType = "action_type"
    }

    var displayIcon: String {
        icon ?? "arrow.right.circle.fill"
    }

    var priorityColor: Color {
        switch priority {
        case "high":
            return DesignSystem.Colors.errorRed // Red
        case "medium":
            return DesignSystem.Colors.amber // Orange
        default:
            return DesignSystem.Colors.emerald // Green
        }
    }
}

// MARK: - Life Recommendations
struct LifeRecommendations: Codable {
    let lunch: [LifeRecommendationItem]?
    let walks: [LifeRecommendationItem]?
    let activities: [LifeRecommendationItem]?
    let scheduleChanges: [LifeRecommendationItem]?
    let placesCategories: [String]?

    enum CodingKeys: String, CodingKey {
        case lunch, walks, activities
        case scheduleChanges = "schedule_changes"
        case placesCategories = "places_categories"
    }
}

// MARK: - Life Recommendation Item
struct LifeRecommendationItem: Codable, Identifiable {
    var id: String { label }

    let label: String
    let detail: String?
    let icon: String?
    let timeSuggestion: String?
    let locationHint: String?

    enum CodingKeys: String, CodingKey {
        case label, detail, icon
        case timeSuggestion = "time_suggestion"
        case locationHint = "location_hint"
    }

    var displayIcon: String {
        icon ?? "mappin.circle.fill"
    }
}

// MARK: - Life Key Metric
struct LifeKeyMetric: Codable, Identifiable {
    var id: String { label }

    let label: String
    let value: String
    let icon: String?
    let trend: String? // "up", "down", "stable"
    let colorHex: String?

    enum CodingKeys: String, CodingKey {
        case label, value, icon, trend
        case colorHex = "color_hex"
    }

    var displayIcon: String {
        icon ?? "chart.bar.fill"
    }

    var displayColor: Color {
        if let hex = colorHex {
            return Color(hex: hex)
        }
        return DesignSystem.Colors.blue
    }

    var trendIcon: String? {
        switch trend {
        case "up": return "arrow.up"
        case "down": return "arrow.down"
        case "stable": return "minus"
        default: return nil
        }
    }
}

// MARK: - Future Impact
/// Predicts what current patterns mean for the coming days.
struct FutureImpact: Codable {
    let headline: String?
    let detail: String?
    let tomorrowPrediction: String?
    let thisWeekOutlook: String?
    let recoveryNeeded: String?
    let highestRiskDay: String?
    let riskLevel: String? // "high", "moderate", "low"

    enum CodingKeys: String, CodingKey {
        case headline, detail
        case tomorrowPrediction = "tomorrow_prediction"
        case thisWeekOutlook = "this_week_outlook"
        case recoveryNeeded = "recovery_needed"
        case highestRiskDay = "highest_risk_day"
        case riskLevel = "risk_level"
    }

    var riskColor: Color {
        switch riskLevel {
        case "high":
            return DesignSystem.Colors.errorRed
        case "moderate":
            return DesignSystem.Colors.amber
        default:
            return DesignSystem.Colors.emerald
        }
    }

    var riskIcon: String {
        switch riskLevel {
        case "high": return "exclamationmark.triangle.fill"
        case "moderate": return "exclamationmark.circle.fill"
        default: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Recovery Debt
/// Tracks cumulative sleep/rest deficit.
struct RecoveryDebt: Codable {
    let debtLevel: String? // "critical", "elevated", "manageable", "clear"
    let debtHours: Double?
    let debtTrend: String? // "accumulating", "stable", "recovering"
    let detail: String?
    let paybackEstimate: String?
    let performanceImpact: String?
    let daysAccumulated: Int?

    enum CodingKeys: String, CodingKey {
        case debtLevel = "debt_level"
        case debtHours = "debt_hours"
        case debtTrend = "debt_trend"
        case detail
        case paybackEstimate = "payback_estimate"
        case performanceImpact = "performance_impact"
        case daysAccumulated = "days_accumulated"
    }

    var debtColor: Color {
        switch debtLevel {
        case "critical":
            return DesignSystem.Colors.errorRed
        case "elevated":
            return DesignSystem.Colors.amber
        case "manageable":
            return DesignSystem.Colors.blue
        default:
            return DesignSystem.Colors.emerald
        }
    }

    var debtIcon: String {
        switch debtLevel {
        case "critical": return "battery.0"
        case "elevated": return "battery.25"
        case "manageable": return "battery.75"
        default: return "battery.100"
        }
    }

    var trendIcon: String? {
        switch debtTrend {
        case "accumulating": return "arrow.up.right"
        case "recovering": return "arrow.down.right"
        case "stable": return "arrow.right"
        default: return nil
        }
    }

    var formattedDebtHours: String {
        guard let hours = debtHours else { return "Unknown" }
        return String(format: "%.1fh", hours)
    }
}

// MARK: - Cognitive Forecast
/// Predicts cognitive capacity based on patterns.
struct CognitiveForecast: Codable {
    let currentCapacity: String? // "65%"
    let capacityLevel: String? // "impaired", "reduced", "normal", "peak"
    let peakHoursToday: String?
    let avoidComplexWork: String?
    let bestForMeetings: String?
    let decisionQuality: String?
    let contributingFactors: [String]?
    let prescription: String?

    enum CodingKeys: String, CodingKey {
        case currentCapacity = "current_capacity"
        case capacityLevel = "capacity_level"
        case peakHoursToday = "peak_hours_today"
        case avoidComplexWork = "avoid_complex_work"
        case bestForMeetings = "best_for_meetings"
        case decisionQuality = "decision_quality"
        case contributingFactors = "contributing_factors"
        case prescription
    }

    var capacityColor: Color {
        switch capacityLevel {
        case "impaired":
            return DesignSystem.Colors.errorRed
        case "reduced":
            return DesignSystem.Colors.amber
        case "peak":
            return DesignSystem.Colors.emerald
        default:
            return DesignSystem.Colors.blue
        }
    }

    var capacityIcon: String {
        switch capacityLevel {
        case "impaired": return "brain.head.profile"
        case "reduced": return "brain"
        case "peak": return "brain.fill"
        default: return "brain"
        }
    }

    var capacityPercentage: Int? {
        guard let capacity = currentCapacity else { return nil }
        let numericString = capacity.replacingOccurrences(of: "%", with: "")
        return Int(numericString)
    }
}

// MARK: - Places Recommendations
struct PlacesRecommendationResponse: Codable {
    let categories: [PlaceCategory]?
    let suggestions: [PlaceSuggestion]?
    let userPreferences: UserPlacePreferences?
    let generatedAt: String?

    enum CodingKeys: String, CodingKey {
        case categories, suggestions
        case userPreferences = "user_preferences"
        case generatedAt = "generated_at"
    }
}

struct PlaceCategory: Codable, Identifiable {
    var id: String { categoryId }

    let categoryId: String
    let name: String
    let icon: String?
    let description: String?
    let searchQuery: String?

    enum CodingKeys: String, CodingKey {
        case categoryId = "id"
        case name, icon, description
        case searchQuery = "search_query"
    }

    var displayIcon: String {
        icon ?? "mappin.circle.fill"
    }
}

struct PlaceSuggestion: Codable, Identifiable {
    var id: String { suggestionId }

    let suggestionId: String
    let name: String
    let category: String?
    let icon: String?
    let description: String?
    let distanceHint: String?
    let timeSuggestion: String?
    let whySuggested: String?
    let actionUrl: String?
    let placeId: String?
    let lat: Double?
    let lng: Double?
    let rating: Double?
    let priceLevel: Int?

    enum CodingKeys: String, CodingKey {
        case suggestionId = "id"
        case name, category, icon, description
        case distanceHint = "distance_hint"
        case timeSuggestion = "time_suggestion"
        case whySuggested = "why_suggested"
        case actionUrl = "action_url"
        case placeId = "place_id"
        case lat, lng, rating
        case priceLevel = "price_level"
    }

    var displayIcon: String {
        icon ?? "mappin.circle.fill"
    }
}

struct UserPlacePreferences: Codable {
    let inferredCuisines: [String]?
    let typicalDiningDays: [String]?
    let typicalDiningTimes: [String]?
    let locationHint: String?

    enum CodingKeys: String, CodingKey {
        case inferredCuisines = "inferred_cuisines"
        case typicalDiningDays = "typical_dining_days"
        case typicalDiningTimes = "typical_dining_times"
        case locationHint = "location_hint"
    }
}

// MARK: - Rate Limit Status
struct RateLimitStatus: Codable {
    let remaining: Int
    let maxPerDay: Int
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case remaining
        case maxPerDay = "max_per_day"
        case resetsAt = "resets_at"
    }
}

// MARK: - Life Insights Mode
enum LifeInsightsMode: String, CaseIterable {
    case thirtyDay = "30day"
    case sixtyDay = "60day"

    var displayName: String {
        switch self {
        case .thirtyDay:
            return "30 Days"
        case .sixtyDay:
            return "60 Days"
        }
    }

    var description: String {
        switch self {
        case .thirtyDay:
            return "Last month"
        case .sixtyDay:
            return "Last 2 months"
        }
    }
}
