import Foundation

/// Service for day review API calls
class DayReviewService {
    static let shared = DayReviewService()
    private let baseURL = Constants.API.baseURL
    private let timeout: TimeInterval = Constants.API.timeout

    private init() {}

    /// Creates a URL from the given string, throwing an error if invalid
    private func makeURL(_ path: String) throws -> URL {
        guard let url = URL(string: path) else {
            throw DayReviewError.networkError
        }
        return url
    }

    /// Creates URLComponents from the given string, throwing an error if invalid
    private func makeURLComponents(_ path: String) throws -> URLComponents {
        guard let components = URLComponents(string: path) else {
            throw DayReviewError.networkError
        }
        return components
    }

    // MARK: - Get Day Review

    /// Get day review data comparing planned vs actual activities
    func getDayReview(date: Date? = nil, timezone: String? = nil) async throws -> DayReviewResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw DayReviewError.unauthorized
        }

        var urlComponents = try makeURLComponents("\(baseURL)/api/v1/review/day")
        var queryItems: [URLQueryItem] = []

        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            queryItems.append(URLQueryItem(name: "date", value: formatter.string(from: date)))
        }

        if let timezone = timezone {
            queryItems.append(URLQueryItem(name: "timezone", value: timezone))
        } else {
            queryItems.append(URLQueryItem(name: "timezone", value: TimeZone.current.identifier))
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw DayReviewError.networkError
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        print("🔄 DayReviewService: Fetching day review...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DayReviewError.networkError
        }

        if httpResponse.statusCode == 401 {
            throw DayReviewError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ DayReviewService: Server error \(httpResponse.statusCode)")
            throw DayReviewError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let reviewResponse = try decoder.decode(DayReviewResponse.self, from: data)
        print("✅ DayReviewService: Got review with \(reviewResponse.totalPlanned) planned activities")
        return reviewResponse
    }

    // MARK: - Save Reflection

    /// Save a day reflection (rating and notes)
    func saveReflection(request: ReflectionRequest) async throws -> ReflectionSaveResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw DayReviewError.unauthorized
        }

        let url = try makeURL("\(baseURL)/api/v1/review/day/reflection")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeout
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)

        print("🔄 DayReviewService: Saving reflection...")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DayReviewError.networkError
        }

        if httpResponse.statusCode == 401 {
            throw DayReviewError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ DayReviewService: Server error \(httpResponse.statusCode)")
            throw DayReviewError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let saveResponse = try decoder.decode(ReflectionSaveResponse.self, from: data)
        print("✅ DayReviewService: Reflection saved successfully")
        return saveResponse
    }
}

// MARK: - Error Types

enum DayReviewError: Error, LocalizedError {
    case unauthorized
    case networkError
    case serverError(statusCode: Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to view your day review"
        case .networkError:
            return "Network error. Please check your connection."
        case .serverError(let code):
            return "Server error (\(code)). Please try again."
        case .decodingError:
            return "Error processing response"
        }
    }
}

// MARK: - Response Models

struct DayReviewResponse: Codable {
    let date: String
    let summaryMessage: String
    let activities: [ActivityStatus]
    let totalPlanned: Int
    let totalCompleted: Int
    let completionPercentage: Int

    // Health metrics (optional)
    let steps: Int?
    let sleepHours: Double?
    let activeMinutes: Int?

    // Existing reflection if already submitted
    let existingRating: String?
    let existingNotes: String?
}

struct ActivityStatus: Codable, Identifiable {
    let activityId: String
    let title: String
    let category: String?
    let plannedTime: String?
    let location: String?
    let isCompleted: Bool
    let matchedEventTitle: String?

    var id: String { activityId }
}

struct ReflectionRequest: Codable {
    let date: String?
    let rating: String  // "great", "okay", "rough"
    let notes: String?
    let plannedCount: Int?
    let completedCount: Int?
    let steps: Int?
    let sleepHours: Double?
    let activeMinutes: Int?
}

struct ReflectionSaveResponse: Codable {
    let success: Bool
    let message: String?
    let reflectionId: Int?
}

// MARK: - Daily Insights Summary (for evening notifications)

struct DailyInsightsSummary: Codable {
    let date: String
    let dayOfWeek: String
    let summaryMessage: String
    let shortSummary: String
    let dayTone: String
    let timeBreakdown: TimeBreakdown?
    let eventStats: EventStats?
    let health: HealthSummary?
    let highlights: [DayHighlight]?
    let completion: CompletionStats?

    struct CompletionStats: Codable {
        let hasActivities: Bool
        let totalPlanned: Int
        let totalCompleted: Int
        let completionPercentage: Int
        let summaryMessage: String?
    }

    struct TimeBreakdown: Codable {
        let meetingHours: Double
        let focusHours: Double
        let personalHours: Double
        let freeHours: Double
        let totalScheduledHours: Double
    }

    struct EventStats: Codable {
        let totalEvents: Int
        let meetings: Int
        let focusBlocks: Int
        let personalEvents: Int
        let backToBackCount: Int
        let longestMeetingMinutes: Int
    }

    struct HealthSummary: Codable {
        let hasData: Bool
        let steps: Int?
        let sleepMinutes: Int?
        let activeMinutes: Int?
        let restingHeartRate: Int?
        let stepsGoalPercent: Int?
        let stepsGoalMet: Bool?
        let sleepGoalPercent: Int?
        let sleepGoalMet: Bool?
        let activeGoalPercent: Int?
        let activeGoalMet: Bool?
    }

    struct DayHighlight: Codable {
        let category: String
        let label: String
        let detail: String
        let icon: String
    }
}

extension DayReviewService {
    /// Get comprehensive daily insights summary for evening notifications
    func getDailyInsightsSummary(date: Date? = nil, timezone: String? = nil) async throws -> DailyInsightsSummary {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw DayReviewError.unauthorized
        }

        var urlComponents = try makeURLComponents("\(baseURL)/api/v1/insights/daily")
        var queryItems: [URLQueryItem] = []

        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            queryItems.append(URLQueryItem(name: "date", value: formatter.string(from: date)))
        }

        if let timezone = timezone {
            queryItems.append(URLQueryItem(name: "timezone", value: timezone))
        } else {
            queryItems.append(URLQueryItem(name: "timezone", value: TimeZone.current.identifier))
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw DayReviewError.networkError
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        print("🔄 DayReviewService: Fetching daily insights summary...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DayReviewError.networkError
        }

        if httpResponse.statusCode == 401 {
            throw DayReviewError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ DayReviewService: Server error \(httpResponse.statusCode)")
            throw DayReviewError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let summaryResponse = try decoder.decode(DailyInsightsSummary.self, from: data)
        print("✅ DayReviewService: Got daily insights - \(summaryResponse.shortSummary)")
        return summaryResponse
    }
}
