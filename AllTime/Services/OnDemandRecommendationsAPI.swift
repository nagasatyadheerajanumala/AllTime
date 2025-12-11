import Foundation

enum OnDemandAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .unauthorized: return "Not authorized"
        case .serverError: return "Server error"
        }
    }
}

class OnDemandRecommendationsAPI {
    private let baseURL = Constants.API.baseURL
    
    // MARK: - Food Recommendations (On-Demand)

    func getFoodRecommendations(
        category: String = "all",
        radiusMiles: Double = 1.5,
        maxResults: Int = 10,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws -> FoodRecommendationsResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw OnDemandAPIError.unauthorized
        }

        // Build URL with query parameters - MUST include latitude, longitude, and radius_miles
        var urlString = "\(baseURL)/api/v1/recommendations/food?radius_miles=\(radiusMiles)&category=\(category)&max_results=\(maxResults)"

        // Add location parameters (required for results)
        if let lat = latitude, let lon = longitude {
            urlString += "&latitude=\(lat)&longitude=\(lon)"
        }

        guard let url = URL(string: urlString) else {
            throw OnDemandAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        print("📤 OnDemandAPI: Fetching food recommendations (category: \(category), radius: \(radiusMiles) miles, lat: \(latitude ?? 0), lon: \(longitude ?? 0))")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OnDemandAPIError.invalidResponse
        }
        
        print("📥 OnDemandAPI: Food response: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw OnDemandAPIError.serverError
        }
        
        // Log response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 OnDemandAPI: Food JSON: \(responseString)")
        }
        
        let decoder = JSONDecoder()
        // Note: Food API uses camelCase, not snake_case!
        let foodResponse = try decoder.decode(FoodRecommendationsResponse.self, from: data)
        print("✅ OnDemandAPI: Found \(foodResponse.healthyOptions?.count ?? 0) healthy + \(foodResponse.regularOptions?.count ?? 0) regular options")
        
        return foodResponse
    }
    
    // MARK: - Walk Recommendations (On-Demand)
    
    func getWalkRecommendations(
        distanceMiles: Double = 1.0,
        difficulty: String = "easy"
    ) async throws -> WalkRecommendationsResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw OnDemandAPIError.unauthorized
        }
        
        let urlString = "\(baseURL)/api/v1/recommendations/walk?distance_miles=\(distanceMiles)&difficulty=\(difficulty)"
        guard let url = URL(string: urlString) else {
            throw OnDemandAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("📤 OnDemandAPI: Fetching walk recommendations (distance: \(distanceMiles) miles, difficulty: \(difficulty))")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OnDemandAPIError.invalidResponse
        }
        
        print("📥 OnDemandAPI: Walk response: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw OnDemandAPIError.serverError
        }
        
        // Log response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 OnDemandAPI: Walk JSON: \(responseString)")
        }
        
        let decoder = JSONDecoder()
        let walkResponse = try decoder.decode(WalkRecommendationsResponse.self, from: data)
        print("✅ OnDemandAPI: Found \(walkResponse.routes?.count ?? 0) walk routes")
        
        return walkResponse
    }
}

