import Foundation

/// Service for day review API calls
class DayReviewService {
    static let shared = DayReviewService()
    private let baseURL = Constants.API.baseURL

    private init() {}

    // MARK: - Get Day Review

    /// Get day review data comparing planned vs actual activities
    func getDayReview(date: Date? = nil, timezone: String? = nil) async throws -> DayReviewResponse {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw DayReviewError.unauthorized
        }

        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/review/day")!
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

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
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

        let url = URL(string: "\(baseURL)/api/v1/review/day/reflection")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
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
