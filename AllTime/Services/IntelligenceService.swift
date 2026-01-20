import Foundation
import CoreLocation

/// Service for fetching compound intelligence predictions
class IntelligenceService {
    static let shared = IntelligenceService()

    private let baseURL = Constants.API.baseURL
    private let session = URLSession.shared
    private let timeout: TimeInterval = Constants.API.timeout
    private let locationManager = CLLocationManager()

    private var accessToken: String? {
        KeychainManager.shared.getAccessToken()
    }

    private init() {}

    /// Creates URLComponents from the given string, throwing an error if invalid
    private func makeURLComponents(_ path: String) throws -> URLComponents {
        guard let components = URLComponents(string: path) else {
            throw IntelligenceError.invalidResponse
        }
        return components
    }

    // MARK: - Daily Forecast

    /// Get comprehensive daily forecast combining all signals
    func getDailyForecast() async throws -> DailyForecast {
        guard let token = accessToken, !token.isEmpty else {
            throw IntelligenceError.notAuthenticated
        }

        var urlComponents = try makeURLComponents("\(baseURL)/api/intelligence/forecast/daily")

        // Add location if available
        if let location = getCurrentLocation() {
            urlComponents.queryItems = [
                URLQueryItem(name: "lat", value: String(location.latitude)),
                URLQueryItem(name: "lng", value: String(location.longitude))
            ]
        }

        guard let url = urlComponents.url else {
            throw IntelligenceError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntelligenceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw IntelligenceError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(DailyForecast.self, from: data)
    }

    // MARK: - Event Prediction

    /// Get prediction for a specific event
    func getEventPrediction(eventId: Int64) async throws -> EventPrediction {
        guard let token = accessToken, !token.isEmpty else {
            throw IntelligenceError.notAuthenticated
        }

        var urlComponents = try makeURLComponents("\(baseURL)/api/intelligence/event/\(eventId)")

        // Add location if available
        if let location = getCurrentLocation() {
            urlComponents.queryItems = [
                URLQueryItem(name: "lat", value: String(location.latitude)),
                URLQueryItem(name: "lng", value: String(location.longitude))
            ]
        }

        guard let url = urlComponents.url else {
            throw IntelligenceError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntelligenceError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw IntelligenceError.eventNotFound
        }

        guard httpResponse.statusCode == 200 else {
            throw IntelligenceError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(EventPrediction.self, from: data)
    }

    // MARK: - Remaining Events

    /// Get predictions for all remaining events today
    func getRemainingEventPredictions() async throws -> [EventPrediction] {
        guard let token = accessToken, !token.isEmpty else {
            throw IntelligenceError.notAuthenticated
        }

        var urlComponents = try makeURLComponents("\(baseURL)/api/intelligence/events/remaining")

        // Add location if available
        if let location = getCurrentLocation() {
            urlComponents.queryItems = [
                URLQueryItem(name: "lat", value: String(location.latitude)),
                URLQueryItem(name: "lng", value: String(location.longitude))
            ]
        }

        guard let url = urlComponents.url else {
            throw IntelligenceError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw IntelligenceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw IntelligenceError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode([EventPrediction].self, from: data)
    }

    // MARK: - Location Helper

    private func getCurrentLocation() -> CLLocationCoordinate2D? {
        // Return last known location if available
        return locationManager.location?.coordinate
    }
}

// MARK: - Errors

enum IntelligenceError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case serverError(Int)
    case eventNotFound
    case decodingError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to access predictions"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .eventNotFound:
            return "Event not found"
        case .decodingError:
            return "Failed to parse prediction data"
        }
    }
}
