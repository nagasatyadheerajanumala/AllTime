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

        let decoder = APIService.sharedDecoder
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

        let decoder = APIService.sharedDecoder
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

        let decoder = APIService.sharedDecoder
        let promptsResponse = try decoder.decode(ClaraSuggestedPromptsResponse.self, from: data)
        print("✅ ClaraService: Got \(promptsResponse.prompts.count) suggested prompts")
        return promptsResponse.prompts
    }

    // MARK: - Chat History

    /// Get list of user's chat sessions.
    func getConversations() async throws -> [ConversationSession] {
        let url = try makeURL("\(baseURL)/api/v1/clara/conversations")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("📜 ClaraService: Fetching conversation history...")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaraError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ClaraError.serverError(statusCode: httpResponse.statusCode, message: "Failed to get conversations")
        }

        let decoder = APIService.sharedDecoder
        let conversationsResponse = try decoder.decode(ConversationsResponse.self, from: data)
        print("✅ ClaraService: Got \(conversationsResponse.conversations.count) conversations")
        return conversationsResponse.conversations
    }

    /// Get messages for a specific conversation.
    func getConversation(sessionId: String) async throws -> [ConversationMessage] {
        let url = try makeURL("\(baseURL)/api/v1/clara/conversations/\(sessionId)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("📜 ClaraService: Fetching conversation \(sessionId)...")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaraError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ClaraError.serverError(statusCode: httpResponse.statusCode, message: "Failed to get conversation")
        }

        let decoder = APIService.sharedDecoder
        let messagesResponse = try decoder.decode(ConversationMessagesResponse.self, from: data)
        print("✅ ClaraService: Got \(messagesResponse.messages.count) messages")
        return messagesResponse.messages
    }

    /// Delete a conversation.
    func deleteConversation(sessionId: String) async throws {
        let url = try makeURL("\(baseURL)/api/v1/clara/conversations/\(sessionId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🗑️ ClaraService: Deleting conversation \(sessionId)...")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaraError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ClaraError.serverError(statusCode: httpResponse.statusCode, message: "Failed to delete conversation")
        }

        print("✅ ClaraService: Conversation deleted")
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
    var latitude: Double? = nil
    var longitude: Double? = nil

    enum CodingKeys: String, CodingKey {
        case message
        case sessionId = "session_id"
        case timezone
        case latitude
        case longitude
    }
}

struct ClaraChatResponse: Codable {
    let response: String
    let sessionId: String
    let contextDate: String
    let responseTimeMs: Int

    // Structured data for enhanced UI
    let insights: [ResponseInsight]?
    let contextMetrics: ContextMetrics?

    // Action result (if user requested an action)
    let actionResult: ActionResult?

    enum CodingKeys: String, CodingKey {
        case response
        case sessionId = "session_id"
        case contextDate = "context_date"
        case responseTimeMs = "response_time_ms"
        case insights
        case contextMetrics = "context_metrics"
        case actionResult = "action_result"
    }
}

/// Result of a Clara action (e.g., creating event, searching places)
struct ActionResult: Codable {
    let actionType: String
    let success: Bool
    let message: String
    let data: ActionData?

    enum CodingKeys: String, CodingKey {
        case actionType = "action_type"
        case success
        case message
        case data
    }
}

/// Wrapper for different action data types
struct ActionData: Codable {
    // Place search results
    let places: [PlaceData]?
    let placeType: String?

    // Task results
    let tasks: [TaskData]?

    // Event created/edited/deleted
    let eventId: String?
    let title: String?
    let date: String?
    let startTime: String?
    let endTime: String?
    let location: String?
    let restaurantName: String?
    let mapsUrl: String?

    // Event edited (rescheduled)
    let oldDate: String?
    let oldTime: String?
    let newDate: String?
    let newTime: String?

    // Itinerary
    let timeSlots: [TimeSlotData]?
    let summary: String?
    let dayType: String?

    // Blockers
    let blockers: [BlockerData]?

    // Reminders (array format)
    let reminders: [ReminderData]?

    // Reminder fields (direct format - when backend sends single reminder)
    let id: Int64?
    let dueDate: String?
    let dueTime: String?

    enum CodingKeys: String, CodingKey {
        case places
        case placeType = "place_type"
        case tasks
        case eventId = "event_id"
        case title
        case date
        case startTime = "start_time"
        case endTime = "end_time"
        case location
        case restaurantName = "restaurant_name"
        case mapsUrl = "maps_url"
        case oldDate = "old_date"
        case oldTime = "old_time"
        case newDate = "new_date"
        case newTime = "new_time"
        case timeSlots = "time_slots"
        case summary
        case dayType = "day_type"
        case blockers
        case reminders
        case id
        case dueDate = "due_date"
        case dueTime = "due_time"
    }
}

struct PlaceData: Codable, Identifiable {
    let name: String
    let address: String?
    let rating: Double?
    let priceLevel: String?
    let distanceKm: Double?
    let latitude: Double?
    let longitude: Double?
    let googlePlaceId: String?
    let mapsUrl: String?
    let icon: String?

    var id: String { googlePlaceId ?? name }

    enum CodingKeys: String, CodingKey {
        case name, address, rating, latitude, longitude, icon
        case priceLevel = "price_level"
        case distanceKm = "distance_km"
        case googlePlaceId = "google_place_id"
        case mapsUrl = "maps_url"
    }
}

struct TaskData: Codable, Identifiable {
    let id: Int64?
    let title: String
    let dueDate: String?
    let priority: String?
    let completed: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, priority, completed
        case dueDate = "due_date"
    }
}

struct TimeSlotData: Codable, Identifiable {
    let startTime: String
    let endTime: String
    let activity: String
    let category: String?
    let isExisting: Bool?

    var id: String { "\(startTime)-\(activity)" }

    enum CodingKeys: String, CodingKey {
        case activity, category
        case startTime = "start_time"
        case endTime = "end_time"
        case isExisting = "is_existing"
    }
}

struct BlockerData: Codable, Identifiable {
    let type: String
    let title: String
    let detail: String
    let severity: String

    var id: String { "\(type)-\(title)" }
}

struct ReminderData: Codable, Identifiable {
    let id: Int64?
    let title: String
    let dueDate: String?
    let dueTime: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case dueDate = "due_date"
        case dueTime = "due_time"
    }
}

/// Structured insight card from Clara's analysis
struct ResponseInsight: Codable, Identifiable {
    let type: String       // "meeting_load", "sleep", "focus_time", "overloaded", "opportunity"
    let title: String      // "Heavy Meeting Day"
    let detail: String     // "7 meetings, 285 minutes total"
    let severity: String   // "critical", "warning", "info", "positive"
    let icon: String       // SF Symbol name

    var id: String { type }
}

/// Key metrics extracted from Clara's context
struct ContextMetrics: Codable {
    let meetingCount: Int?
    let totalMeetingMinutes: Int?
    let freeMinutes: Int?
    let longestFocusBlockMinutes: Int?
    let sleepHours: Double?
    let sleepStatus: String?
    let steps: Int?
    let capacityPercent: Int?

    enum CodingKeys: String, CodingKey {
        case meetingCount = "meeting_count"
        case totalMeetingMinutes = "total_meeting_minutes"
        case freeMinutes = "free_minutes"
        case longestFocusBlockMinutes = "longest_focus_block_minutes"
        case sleepHours = "sleep_hours"
        case sleepStatus = "sleep_status"
        case steps
        case capacityPercent = "capacity_percent"
    }
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

    enum CodingKeys: String, CodingKey {
        case date
        case dayType = "day_type"
        case meetingCount = "meeting_count"
        case taskCount = "task_count"
        case overdueTaskCount = "overdue_task_count"
        case sleepHours = "sleep_hours"
        case hasSleepData = "has_sleep_data"
        case hasCalendarData = "has_calendar_data"
        case hasTaskData = "has_task_data"
        case statusLine = "status_line"
    }
}

// MARK: - Chat History Models

struct ConversationSession: Codable, Identifiable {
    let sessionId: String
    let preview: String
    let createdAt: String
    let topic: String?

    var id: String { sessionId }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case preview
        case createdAt = "created_at"
        case topic
    }
}

struct ConversationMessage: Codable, Identifiable {
    let role: String
    let content: String?
    let createdAt: String
    let messageIndex: Int?

    var id: String { "\(createdAt)-\(messageIndex ?? 0)" }

    var isClara: Bool { role == "assistant" }
    var isUser: Bool { role == "user" }

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case createdAt = "created_at"
        case messageIndex = "message_index"
    }
}

struct ConversationsResponse: Codable {
    let conversations: [ConversationSession]
}

struct ConversationMessagesResponse: Codable {
    let sessionId: String
    let messages: [ConversationMessage]

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case messages
    }
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
