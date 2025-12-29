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
    }
}

// MARK: - Life Insight Item
struct LifeInsightItem: Codable, Identifiable {
    var id: String { title }

    let title: String
    let detail: String?
    let icon: String?
    let sentiment: String? // "positive", "neutral", "negative"

    var displayIcon: String {
        icon ?? "lightbulb.fill"
    }

    var sentimentColor: Color {
        switch sentiment {
        case "positive":
            return Color(hex: "10B981") // Green
        case "negative":
            return Color(hex: "EF4444") // Red
        default:
            return Color(hex: "3B82F6") // Blue
        }
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
            return Color(hex: "EF4444") // Red
        case "medium":
            return Color(hex: "F59E0B") // Orange
        default:
            return Color(hex: "10B981") // Green
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
        return Color(hex: "3B82F6")
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
