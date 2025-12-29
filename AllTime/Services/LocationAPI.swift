import Foundation
import CoreLocation

class LocationAPI {
    private let baseURL = Constants.API.baseURL
    private let apiService = APIService()
    
    // MARK: - Update Location
    
    func updateLocation(latitude: Double, longitude: Double,
                       address: String?, city: String?, country: String?) async throws {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw LocationError.unauthorized
        }
        
        let url = URL(string: "\(baseURL)/api/v1/location")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any?] = [
            "latitude": latitude,
            "longitude": longitude,
            "address": address,
            "city": city,
            "country": country
        ]
        
        let jsonData = try JSONSerialization.data(
            withJSONObject: body.compactMapValues { $0 }
        )
        request.httpBody = jsonData
        
        print("📤 LocationAPI: Updating location: \(latitude), \(longitude)")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocationError.invalidResponse
        }
        
        print("📥 LocationAPI: Location update response: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw LocationError.updateFailed(httpResponse.statusCode)
        }
    }
    
    // MARK: - Get Lunch Recommendations
    
    func getLunchRecommendations(for date: Date) async throws -> LunchRecommendations {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw LocationError.unauthorized
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        
        let urlString = "\(baseURL)/api/v1/location/lunch-recommendations?date=\(dateStr)"
        guard let url = URL(string: urlString) else {
            throw LocationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("📤 LocationAPI: Fetching lunch recommendations for \(dateStr)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocationError.invalidResponse
        }
        
        print("📥 LocationAPI: Lunch recommendations response: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 400 {
                throw LocationError.locationNotAvailable
            }
            throw LocationError.fetchFailed(httpResponse.statusCode)
        }
        
        // Log the raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 LocationAPI: Lunch recommendations JSON:")
            print(responseString)
        }
        
        let decoder = JSONDecoder()
        do {
            let recommendations = try decoder.decode(LunchRecommendations.self, from: data)
            print("✅ LocationAPI: Found \(recommendations.nearbySpots.count) lunch spots")
            return recommendations
        } catch {
            print("❌ LocationAPI: Failed to decode lunch recommendations")
            print("❌ LocationAPI: Decoding error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ LocationAPI: Raw response was:")
                print(responseString)
            }
            throw error
        }
    }
    
    // MARK: - Get Walk Routes
    
    func getWalkRoutes(for date: Date) async throws -> WalkRoutes {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw LocationError.unauthorized
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        
        let urlString = "\(baseURL)/api/v1/location/walk-routes?date=\(dateStr)"
        guard let url = URL(string: urlString) else {
            throw LocationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("📤 LocationAPI: Fetching walk routes for \(dateStr)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocationError.invalidResponse
        }
        
        print("📥 LocationAPI: Walk routes response: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 400 {
                throw LocationError.locationNotAvailable
            }
            throw LocationError.fetchFailed(httpResponse.statusCode)
        }
        
        // Log the raw response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 LocationAPI: Walk routes JSON:")
            print(responseString)
        }
        
        let decoder = JSONDecoder()
        do {
            let routes = try decoder.decode(WalkRoutes.self, from: data)
            print("✅ LocationAPI: Found \(routes.routes.count) walk routes")
            return routes
        } catch {
            print("❌ LocationAPI: Failed to decode walk routes")
            print("❌ LocationAPI: Decoding error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ LocationAPI: Raw response was:")
                print(responseString)
            }
            throw error
        }
    }

    // MARK: - Record Place Visit

    func recordVisit(
        googlePlaceId: String?,
        placeName: String,
        placeCategory: String?,
        latitude: Double,
        longitude: Double,
        address: String?
    ) async throws -> PlaceVisitResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw LocationError.unauthorized
        }

        let url = URL(string: "\(baseURL)/api/v1/places/visits")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any?] = [
            "google_place_id": googlePlaceId,
            "place_name": placeName,
            "place_category": placeCategory,
            "latitude": latitude,
            "longitude": longitude,
            "address": address
        ]

        let jsonData = try JSONSerialization.data(
            withJSONObject: body.compactMapValues { $0 }
        )
        request.httpBody = jsonData

        print("📍 LocationAPI: Recording visit to \(placeName)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw LocationError.updateFailed(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(PlaceVisitResponse.self, from: data)
    }

    // MARK: - Check Proximity to Suggested Places

    func checkProximity(latitude: Double, longitude: Double) async throws -> ProximityCheckResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw LocationError.unauthorized
        }

        let url = URL(string: "\(baseURL)/api/v1/places/check-proximity")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw LocationError.fetchFailed(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ProximityCheckResponse.self, from: data)
    }

    // MARK: - Auto-Record Visit if Near Suggested Place

    func autoRecordVisit(latitude: Double, longitude: Double) async throws -> AutoRecordResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw LocationError.unauthorized
        }

        let url = URL(string: "\(baseURL)/api/v1/places/auto-record")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw LocationError.updateFailed(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(AutoRecordResponse.self, from: data)
    }

    // MARK: - Get Today's Suggestions

    func getTodaySuggestions() async throws -> [SuggestedPlace] {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw LocationError.unauthorized
        }

        let url = URL(string: "\(baseURL)/api/v1/places/suggestions/today")!

        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw LocationError.fetchFailed(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(SuggestionsResponse.self, from: data)
        return result.suggestions
    }

    // MARK: - Mark Suggestion as Clicked

    func markSuggestionClicked(suggestionId: Int64) async throws {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw LocationError.unauthorized
        }

        let url = URL(string: "\(baseURL)/api/v1/places/suggestions/\(suggestionId)/click")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LocationError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw LocationError.updateFailed(httpResponse.statusCode)
        }
    }
}

// MARK: - Place Visit Models

struct PlaceVisitResponse: Codable {
    let success: Bool
    let visitId: Int64?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case visitId = "visitId"
        case message
    }
}

struct ProximityCheckResponse: Codable {
    let nearSuggestedPlace: Bool
    let placeId: String?
    let placeName: String?
    let category: String?
    let suggestionId: Int64?
}

struct AutoRecordResponse: Codable {
    let recorded: Bool
    let visitId: Int64?
    let placeName: String?
}

struct SuggestedPlace: Codable, Identifiable {
    let id: Int64
    let googlePlaceId: String
    let name: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let category: String?
    let subCategory: String?
    let rating: Double?
    let priceLevel: Int?
    let suggestionType: String
    let suggestedForDate: String?
    let wasClicked: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case googlePlaceId = "googlePlaceId"
        case name
        case address
        case latitude
        case longitude
        case category
        case subCategory = "subCategory"
        case rating
        case priceLevel = "priceLevel"
        case suggestionType = "suggestionType"
        case suggestedForDate = "suggestedForDate"
        case wasClicked = "wasClicked"
    }
}

struct SuggestionsResponse: Codable {
    let suggestions: [SuggestedPlace]
    let count: Int
}

enum LocationError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case updateFailed(Int)
    case fetchFailed(Int)
    case locationNotAvailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication required"
        case .updateFailed(let code):
            return "Failed to update location (HTTP \(code))"
        case .fetchFailed(let code):
            return "Failed to fetch recommendations (HTTP \(code))"
        case .locationNotAvailable:
            return "Location not available. Please enable location services."
        }
    }
}

