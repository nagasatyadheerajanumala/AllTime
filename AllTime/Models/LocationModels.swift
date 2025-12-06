import Foundation

// MARK: - Complete Daily Summary Response (from /api/v1/daily-summary)
struct DailySummaryResponse: Codable {
    // Arrays are ALWAYS present (guaranteed by backend) - can be empty but never null
    let daySummary: [String]
    let healthSummary: [String]
    let focusRecommendations: [String]
    let alerts: [String]
    let healthBasedSuggestions: [HealthBasedSuggestion]
    
    // Objects can be null (optional)
    let locationRecommendations: LocationRecommendations?
    let breakRecommendations: BreakRecommendations?
    
    enum CodingKeys: String, CodingKey {
        case daySummary = "day_summary"
        case healthSummary = "health_summary"
        case focusRecommendations = "focus_recommendations"
        case alerts
        case healthBasedSuggestions = "health_based_suggestions"
        case locationRecommendations = "location_recommendations"
        case breakRecommendations = "break_recommendations"
    }
}

// MARK: - Health Based Suggestion
struct HealthBasedSuggestion: Codable, Identifiable {
    var id: String { type + (timestamp ?? "") }
    let type: String
    let priority: String
    let message: String
    let action: String
    let timestamp: String?
}

// MARK: - Location Recommendations
struct LocationRecommendations: Codable {
    let userCity: String?
    let userCountry: String?
    let latitude: Double?
    let longitude: Double?
    let lunchRecommendation: LunchRecommendation?
    let walkRoutes: [WalkRoute]?
    let lunchMessage: String?
    let walkMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case userCity = "user_city"
        case userCountry = "user_country"
        case latitude, longitude
        case lunchRecommendation = "lunch_recommendation"
        case walkRoutes = "walk_routes"
        case lunchMessage = "lunch_message"
        case walkMessage = "walk_message"
    }
}

// MARK: - Lunch Recommendation
struct LunchRecommendation: Codable {
    let recommendationTime: String?
    let minutesUntilLunch: Int?
    let message: String?
    let nearbySpots: [LunchSpot]?
    
    enum CodingKeys: String, CodingKey {
        case recommendationTime = "recommendation_time"
        case minutesUntilLunch = "minutes_until_lunch"
        case message
        case nearbySpots = "nearby_spots"
    }
}

// MARK: - Lunch Spot
struct LunchSpot: Codable, Identifiable {
    var id: String { name + (address ?? "") }
    let name: String
    let address: String?
    let distanceKm: Double
    let walkingMinutes: Int
    let rating: Double?
    let priceLevel: String?
    let cuisine: String?
    let openNow: Bool?
    let photoUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case name, address, rating, cuisine
        case distanceKm = "distance_km"
        case walkingMinutes = "walking_minutes"
        case priceLevel = "price_level"
        case openNow = "open_now"
        case photoUrl = "photo_url"
    }
}

// MARK: - Walk Route
struct WalkRoute: Codable, Identifiable {
    var id: String { name }
    let name: String
    let description: String?
    let distanceKm: Double
    let durationMinutes: Int
    let difficulty: String?
    let routeType: String?
    let waypoints: [Waypoint]?
    let mapUrl: String?
    let highlights: [String]?
    let elevationGain: Double?
    let wheelchairAccessible: Bool?
    let bestTimeOfDay: String?
    
    enum CodingKeys: String, CodingKey {
        case name, description, difficulty, waypoints, highlights
        case distanceKm = "distance_km"
        case durationMinutes = "duration_minutes"
        case routeType = "route_type"
        case mapUrl = "map_url"
        case elevationGain = "elevation_gain"
        case wheelchairAccessible = "wheelchair_accessible"
        case bestTimeOfDay = "best_time_of_day"
    }
}

// MARK: - Waypoint
struct Waypoint: Codable {
    let latitude: Double
    let longitude: Double
    let name: String
    let description: String?
}

// MARK: - Break Recommendations
struct BreakRecommendations: Codable {
    let strategy: String
    let suggestedBreaks: [SuggestedBreak]
    let minutesUntilLunch: Int?
    
    enum CodingKeys: String, CodingKey {
        case strategy
        case suggestedBreaks = "suggested_breaks"
        case minutesUntilLunch = "minutes_until_lunch"
    }
}

// MARK: - Suggested Break
struct SuggestedBreak: Codable, Identifiable {
    var id: String { type + startTime }
    let type: String
    let startTime: String
    let durationMinutes: Int
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case startTime = "start_time"
        case durationMinutes = "duration_minutes"
        case reason
    }
}

// MARK: - Legacy Support (for old endpoints if needed)
struct LunchRecommendations: Codable {
    let recommendationTime: String?
    let minutesUntilLunch: Int?
    let message: String
    let nearbySpots: [LunchSpot]
    
    enum CodingKeys: String, CodingKey {
        case recommendationTime = "recommendationTime"
        case minutesUntilLunch = "minutesUntilLunch"
        case message
        case nearbySpots = "nearbySpots"
    }
}

struct WalkRoutes: Codable {
    let suggestedTime: String?
    let durationMinutes: Int
    let distanceKm: Double
    let routeType: String
    let healthBenefit: String
    let routes: [WalkRoute]
    
    enum CodingKeys: String, CodingKey {
        case suggestedTime = "suggestedTime"
        case durationMinutes = "durationMinutes"
        case distanceKm = "distanceKm"
        case routeType = "routeType"
        case healthBenefit = "healthBenefit"
        case routes
    }
}
