import Foundation

/// Service for communicating with Clara AI chat backend.
/// Clara is opinionated and data-grounded - responses are based on REAL user data.
class ClaraService {
    static let shared = ClaraService()

    private let baseURL = Constants.API.baseURL
    private let session = URLSession.shared
    private let timeout: TimeInterval = Constants.API.timeout

    private var accessToken: String? {
        KeychainManager.shared.getAccessToken()
    }

    private init() {}

    /// Creates a URL from the given string, throwing an error if invalid
    private func makeURL(_ path: String) throws -> URL {
        guard let url = URL(string: path) else {
            throw ClaraError.invalidResponse
        }
        return url
    }

    // MARK: - Chat with Clara

    /// Send a message to Clara and get an intelligent, data-grounded response.
    /// Clara ONLY knows what's in the context - she never makes up information.
    ///
    /// - Parameters:
    ///   - message: The user's message/question
    ///   - sessionId: Optional session ID for conversation continuity
    /// - Returns: Clara's response with session info
    func chat(message: String, sessionId: String? = nil) async throws -> ClaraChatResponse {
        let url = try makeURL("\(baseURL)/api/v1/clara/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let timezone = TimeZone.current.identifier
        let body = ClaraChatRequest(message: message, sessionId: sessionId, timezone: timezone)

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        print("💬 ClaraService: Sending message to Clara: \(message.prefix(50))...")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaraError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ ClaraService: Error \(httpResponse.statusCode): \(errorMessage)")
            throw ClaraError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let decoder = JSONDecoder()
        let chatResponse = try decoder.decode(ClaraChatResponse.self, from: data)

        print("✅ ClaraService: Got response in \(chatResponse.responseTimeMs)ms")
        return chatResponse
    }

    /// Get a quick context summary (for debug/UI purposes).
    /// Returns what Clara currently knows about the user.
    func getContextSummary() async throws -> ClaraContextSummary {
        let timezone = TimeZone.current.identifier
        let url = try makeURL("\(baseURL)/api/v1/clara/context?timezone=\(timezone)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🧠 ClaraService: Fetching Clara context summary...")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaraError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ClaraError.serverError(statusCode: httpResponse.statusCode, message: "Failed to get context")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ClaraContextSummary.self, from: data)
    }

    /// Get dynamic suggested prompts based on user's context.
    /// Returns prompts that are relevant to the user's current situation.
    func getSuggestedPrompts() async throws -> [ClaraSuggestedPrompt] {
        let timezone = TimeZone.current.identifier
        let url = try makeURL("\(baseURL)/api/v1/clara/prompts?timezone=\(timezone)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("💡 ClaraService: Fetching suggested prompts...")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaraError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ ClaraService: Failed to fetch prompts - \(httpResponse.statusCode)")
            throw ClaraError.serverError(statusCode: httpResponse.statusCode, message: "Failed to get prompts")
        }

        let decoder = JSONDecoder()
        let promptsResponse = try decoder.decode(ClaraSuggestedPromptsResponse.self, from: data)
        print("✅ ClaraService: Got \(promptsResponse.prompts.count) suggested prompts")
        return promptsResponse.prompts
    }
}

// MARK: - Suggested Prompts Models

struct ClaraSuggestedPromptsResponse: Codable {
    let prompts: [ClaraSuggestedPrompt]
}

struct ClaraSuggestedPrompt: Codable, Identifiable {
    let id: String
    let icon: String
    let prompt: String
}

// MARK: - Request/Response Models

struct ClaraChatRequest: Codable {
    let message: String
    let sessionId: String?
    let timezone: String?
}

struct ClaraChatResponse: Codable {
    let response: String
    let sessionId: String
    let contextDate: String
    let responseTimeMs: Int
}

struct ClaraContextSummary: Codable {
    let date: String?
    let dayType: String?
    let meetingCount: Int?
    let taskCount: Int?
    let overdueTaskCount: Int?
    let sleepHours: Double?
    let hasSleepData: Bool?
    let hasCalendarData: Bool?
    let hasTaskData: Bool?
    let statusLine: String?
}

// MARK: - Errors

enum ClaraError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case noAccessToken

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Clara"
        case .serverError(let code, let message):
            return "Clara error (\(code)): \(message)"
        case .noAccessToken:
            return "Not authenticated"
        }
    }
}
