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
    
    func getLunchRecommendations(for date: Date) async throws -> [LunchPlace] {
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
            let recommendations = try decoder.decode([LunchPlace].self, from: data)
            print("✅ LocationAPI: Found \(recommendations.count) lunch spots")
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
    
    func getWalkRoutes(for date: Date) async throws -> [WalkRoute] {
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
            let routes = try decoder.decode([WalkRoute].self, from: data)
            print("✅ LocationAPI: Found \(routes.count) walk routes")
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

