import Foundation

/// Service for check-in API calls to collect data for predictions
class CheckInService {
    static let shared = CheckInService()
    private let baseURL = Constants.API.baseURL
    private let timeout: TimeInterval = Constants.API.timeout

    private init() {}

    /// Creates a URL from the given string, throwing an error if invalid
    private func makeURL(_ path: String) throws -> URL {
        guard let url = URL(string: path) else {
            throw CheckInError.networkError
        }
        return url
    }

    /// Creates URLComponents from the given string, throwing an error if invalid
    private func makeURLComponents(_ path: String) throws -> URLComponents {
        guard let components = URLComponents(string: path) else {
            throw CheckInError.networkError
        }
        return components
    }

    // MARK: - Get Check-In Status

    /// Get today's check-in status
    func getCheckInStatus() async throws -> CheckInStatusResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw CheckInError.unauthorized
        }

        let url = try makeURL("\(baseURL)/api/v1/checkin/status")
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CheckInError.networkError
        }

        if httpResponse.statusCode == 401 {
            throw CheckInError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw CheckInError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(CheckInStatusResponse.self, from: data)
    }

    // MARK: - Submit Mood Check-In

    /// Submit a mood/energy check-in
    func submitMoodCheckIn(_ request: MoodCheckInRequest) async throws -> CheckInResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw CheckInError.unauthorized
        }

        let url = try makeURL("\(baseURL)/api/v1/checkin/mood")
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = timeout
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CheckInError.networkError
        }

        if httpResponse.statusCode == 401 {
            throw CheckInError.unauthorized
        }

        guard httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            throw CheckInError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(CheckInResponse.self, from: data)
    }

    // MARK: - Quick Check-In

    /// Quick mood check-in (simplified)
    func quickCheckIn(energyLevel: Int, mood: String?) async throws -> CheckInResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw CheckInError.unauthorized
        }

        let url = try makeURL("\(baseURL)/api/v1/checkin/quick")
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = timeout
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["energy_level": energyLevel]
        if let mood = mood {
            body["mood"] = mood
        }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CheckInError.networkError
        }

        if httpResponse.statusCode == 401 {
            throw CheckInError.unauthorized
        }

        guard httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            throw CheckInError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(CheckInResponse.self, from: data)
    }

    // MARK: - Event Feedback

    /// Submit event feedback
    func submitEventFeedback(_ request: EventFeedbackRequest) async throws -> CheckInResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw CheckInError.unauthorized
        }

        let url = try makeURL("\(baseURL)/api/v1/checkin/event-feedback")
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = timeout
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CheckInError.networkError
        }

        if httpResponse.statusCode == 401 {
            throw CheckInError.unauthorized
        }

        guard httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            throw CheckInError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(CheckInResponse.self, from: data)
    }

    // MARK: - Travel Feedback

    /// Submit travel feedback
    func submitTravelFeedback(_ request: TravelFeedbackRequest) async throws -> CheckInResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw CheckInError.unauthorized
        }

        let url = try makeURL("\(baseURL)/api/v1/checkin/travel-feedback")
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = timeout
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CheckInError.networkError
        }

        if httpResponse.statusCode == 401 {
            throw CheckInError.unauthorized
        }

        guard httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            throw CheckInError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(CheckInResponse.self, from: data)
    }

    // MARK: - Learning Data

    /// Get patterns summary (data quality for predictions)
    func getPatternsSummary() async throws -> PatternsSummary {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw CheckInError.unauthorized
        }

        let url = try makeURL("\(baseURL)/api/v1/predictions/learning/summary")
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CheckInError.networkError
        }

        if httpResponse.statusCode == 401 {
            throw CheckInError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw CheckInError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(PatternsSummary.self, from: data)
    }

    /// Get energy prediction for a time of day
    func getEnergyPrediction(timeOfDay: String) async throws -> EnergyPrediction {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw CheckInError.unauthorized
        }

        let url = try makeURL("\(baseURL)/api/v1/predictions/learning/energy?time_of_day=\(timeOfDay)")
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CheckInError.networkError
        }

        if httpResponse.statusCode == 401 {
            throw CheckInError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw CheckInError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(EnergyPrediction.self, from: data)
    }

    // MARK: - Personalized Suggestions

    /// Get personalized suggestions based on current energy and mood
    func getSuggestions(energyLevel: Int, mood: String?, timeOfDay: String?) async throws -> MoodSuggestionsResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw CheckInError.unauthorized
        }

        var urlComponents = try makeURLComponents("\(baseURL)/api/v1/checkin/suggestions")
        var queryItems = [URLQueryItem(name: "energy_level", value: String(energyLevel))]

        if let mood = mood {
            queryItems.append(URLQueryItem(name: "mood", value: mood))
        }
        if let timeOfDay = timeOfDay {
            queryItems.append(URLQueryItem(name: "time_of_day", value: timeOfDay))
        }
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw CheckInError.networkError
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CheckInError.networkError
        }

        if httpResponse.statusCode == 401 {
            throw CheckInError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw CheckInError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(MoodSuggestionsResponse.self, from: data)
    }
}

// MARK: - Errors

enum CheckInError: LocalizedError {
    case unauthorized
    case networkError
    case serverError(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to continue"
        case .networkError:
            return "Network error. Please check your connection."
        case .serverError(let statusCode):
            return "Server error (\(statusCode)). Please try again."
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}
