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
        request.timeoutInterval = 90 // Tool-based chat may need multiple OpenAI round trips
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

    // MARK: - Stream Chat with Clara (SSE)

    /// Stream a chat response from Clara via Server-Sent Events.
    /// Returns an async stream of events: status updates, tool results, text tokens, and the final done event.
    func chatStream(message: String, sessionId: String? = nil) -> AsyncThrowingStream<ClaraSSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let url = try makeURL("\(baseURL)/api/v1/clara/chat/stream")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 60
                    request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let timezone = TimeZone.current.identifier
                    let body = ClaraChatRequest(message: message, sessionId: sessionId, timezone: timezone)
                    request.httpBody = try JSONEncoder().encode(body)

                    print("🔄 ClaraService: Starting stream for: \(message.prefix(50))...")

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        continuation.finish(throwing: ClaraError.serverError(statusCode: statusCode, message: "Stream failed"))
                        return
                    }

                    var eventType: String? = nil
                    var eventDataLines: [String] = []

                    for try await line in bytes.lines {
                        if line.hasPrefix("event:") {
                            eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            // Accumulate data lines (SSE spec allows multi-line data)
                            eventDataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                        } else if line.isEmpty {
                            // Empty line = end of SSE event
                            let eventData = eventDataLines.joined(separator: "\n")
                            if let type = eventType, !eventData.isEmpty {
                                if let event = self.parseSSEEvent(type: type, data: eventData) {
                                    continuation.yield(event)
                                    if case .done = event {
                                        continuation.finish()
                                        return
                                    }
                                }
                            }
                            eventType = nil
                            eventDataLines = []
                        }
                    }

                    continuation.finish()
                } catch {
                    print("❌ ClaraService: Stream error: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Parse a single SSE event into a typed ClaraSSEEvent
    private func parseSSEEvent(type: String, data: String) -> ClaraSSEEvent? {
        guard let jsonData = data.data(using: .utf8) else {
            print("⚠️ ClaraSSE: Could not convert data to UTF-8 for event: \(type)")
            return nil
        }
        let decoder = APIService.sharedDecoder

        switch type {
        case "status":
            if let parsed = try? JSONDecoder().decode([String: String].self, from: jsonData),
               let message = parsed["message"] {
                return .status(message: message)
            }
            print("⚠️ ClaraSSE: Failed to parse status event: \(data.prefix(200))")
        case "tool_result":
            if let result = try? decoder.decode(ToolResultForUI.self, from: jsonData) {
                return .toolResult(result)
            }
            print("⚠️ ClaraSSE: Failed to parse tool_result event: \(data.prefix(200))")
        case "token":
            if let parsed = try? JSONDecoder().decode([String: String].self, from: jsonData),
               let text = parsed["text"] {
                return .token(text: text)
            }
            print("⚠️ ClaraSSE: Failed to parse token event: \(data.prefix(200))")
        case "done":
            if let doneData = try? decoder.decode(ClaraStreamDoneData.self, from: jsonData) {
                return .done(doneData)
            }
            // Log the actual error for debugging
            do {
                _ = try decoder.decode(ClaraStreamDoneData.self, from: jsonData)
            } catch {
                print("⚠️ ClaraSSE: Failed to parse done event: \(error)")
                print("⚠️ ClaraSSE: Done data: \(data.prefix(500))")
            }
        case "error":
            if let parsed = try? JSONDecoder().decode([String: String].self, from: jsonData),
               let error = parsed["error"] {
                return .error(message: error)
            }
            print("⚠️ ClaraSSE: Failed to parse error event: \(data.prefix(200))")
        default:
            print("⚠️ ClaraSSE: Unknown event type: \(type)")
        }
        return nil
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

    // Legacy action result (backward compat)
    let actionResult: ActionResult?

    // NEW: Multiple tool results from function calling
    let toolResults: [ToolResultForUI]?

    enum CodingKeys: String, CodingKey {
        case response
        case sessionId = "session_id"
        case contextDate = "context_date"
        case responseTimeMs = "response_time_ms"
        case insights
        case contextMetrics = "context_metrics"
        case actionResult = "action_result"
        case toolResults = "tool_results"
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
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id, title, priority, completed, status
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

// MARK: - Tool Result Models (Function Calling)

/// Result from a tool execution (new function calling system)
struct ToolResultForUI: Codable, Identifiable {
    let toolName: String
    let displayType: String  // "card", "confirmation", "inline"
    let data: ToolResultPayload?

    var id: String { toolName }

    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case displayType = "display_type"
        case data
    }
}

/// Unified payload covering all tool result shapes
struct ToolResultPayload: Codable {
    // Common
    let success: Bool?
    let count: Int?
    let date: String?
    let message: String?
    let error: String?
    let filter: String?

    // Events (get_events, get_upcoming_events)
    let events: [ToolEventData]?
    let endDate: String?

    // Free slots (get_free_slots)
    let freeSlots: [FreeSlotData]?
    let totalFreeMinutes: Int?

    // Tasks (get_tasks)
    let tasks: [TaskData]?

    // Day schedule (get_day_schedule)
    let eventCount: Int?
    let tasksDue: [TaskData]?
    let taskCount: Int?
    let freeBlocks: [FreeSlotData]?
    let totalMeetingMinutes: Int?

    // Reminders (get_reminders)
    let reminders: [ReminderData]?

    // Places (search_places)
    let places: [PlaceData]?
    let query: String?
    let type: String?

    // Health (get_health_summary)
    let dailyData: [HealthDayData]?
    let summary: HealthSummaryData?
    let dateRange: DateRangeData?

    // Mutation results
    let eventId: String?
    let title: String?
    let startTime: String?
    let endTime: String?
    let durationMinutes: Int?
    let location: String?
    let oldDate: String?
    let oldTime: String?
    let newDate: String?
    let newTime: String?
    let time: String?
    let id: Int64?
    let dueDate: String?
    let dueTime: String?
    let priority: String?
    let actionType: String?

    // Social scheduling (find_mutual_free_time, send_scheduling_proposal)
    let proposalId: Int64?
    let slots: [SchedulingSlotData]?
    let slotCount: Int?
    let calendarsChecked: Int?
    let alltimeParticipants: [String]?
    let externalParticipants: [String]?
    let attendeesNotified: Bool?

    // Network (get_network_connections, schedule_with_connection)
    let connections: [NetworkConnectionData]?
    let connectionName: String?

    enum CodingKeys: String, CodingKey {
        case success, count, date, message, error, filter
        case events
        case endDate = "end_date"
        case freeSlots = "free_slots"
        case totalFreeMinutes = "total_free_minutes"
        case tasks
        case eventCount = "event_count"
        case tasksDue = "tasks_due"
        case taskCount = "task_count"
        case freeBlocks = "free_blocks"
        case totalMeetingMinutes = "total_meeting_minutes"
        case reminders
        case places, query, type
        case dailyData = "daily_data"
        case summary
        case dateRange = "date_range"
        case eventId = "event_id"
        case title
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
        case location
        case oldDate = "old_date"
        case oldTime = "old_time"
        case newDate = "new_date"
        case newTime = "new_time"
        case time
        case id
        case dueDate = "due_date"
        case dueTime = "due_time"
        case priority
        case actionType = "_action_type"
        case proposalId = "proposal_id"
        case slots
        case slotCount = "slot_count"
        case calendarsChecked = "calendars_checked"
        case alltimeParticipants = "alltime_participants"
        case externalParticipants = "external_participants"
        case attendeesNotified = "attendees_notified"
        case connections
        case connectionName = "connection_name"
    }
}

/// Event data returned by tool executor
struct ToolEventData: Codable, Identifiable {
    let title: String?
    let date: String?
    let startTime: String?
    let endTime: String?
    let location: String?
    let allDay: Bool?
    let sourceEventId: String?

    var id: String { "\(title ?? "event")_\(startTime ?? "")" }

    enum CodingKeys: String, CodingKey {
        case title, date, location
        case startTime = "start_time"
        case endTime = "end_time"
        case allDay = "all_day"
        case sourceEventId = "source_event_id"
    }
}

/// Free time slot
struct FreeSlotData: Codable, Identifiable {
    let startTime: String
    let endTime: String
    let durationMinutes: Int

    var id: String { "\(startTime)_\(endTime)" }

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
    }
}

/// Single day health data from tool executor
struct HealthDayData: Codable, Identifiable {
    let date: String?
    let steps: Int?
    let sleepMinutes: Int?
    let sleepHours: Double?
    let sleepQualityScore: Double?
    let restingHeartRate: Int?
    let hrv: Double?
    let activeMinutes: Int?
    let activeEnergyBurned: Double?
    let workoutsCount: Int?

    var id: String { date ?? "unknown_day" }

    enum CodingKeys: String, CodingKey {
        case date, steps, hrv
        case sleepMinutes = "sleep_minutes"
        case sleepHours = "sleep_hours"
        case sleepQualityScore = "sleep_quality_score"
        case restingHeartRate = "resting_heart_rate"
        case activeMinutes = "active_minutes"
        case activeEnergyBurned = "active_energy_burned"
        case workoutsCount = "workouts_count"
    }
}

/// Aggregated health summary for multi-day requests
struct HealthSummaryData: Codable {
    let avgSteps: Double?
    let avgSleepHours: Double?
    let daysWithData: Int?

    enum CodingKeys: String, CodingKey {
        case avgSteps = "avg_steps"
        case avgSleepHours = "avg_sleep_hours"
        case daysWithData = "days_with_data"
    }
}

/// Date range for health queries
struct DateRangeData: Codable {
    let start: String?
    let end: String?
}

/// Scheduling slot from mutual free time search
struct SchedulingSlotData: Codable, Identifiable {
    let date: String?
    let dayOfWeek: String?
    let startTime: String?
    let endTime: String?
    let score: Int?
    let durationMinutes: Int?

    var id: String { "\(date ?? "")-\(startTime ?? "")" }

    enum CodingKeys: String, CodingKey {
        case date, score
        case dayOfWeek = "day_of_week"
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
    }
}

struct NetworkConnectionData: Codable, Identifiable {
    let connectionId: Int64?
    let userId: Int64?
    let fullName: String?
    let email: String?
    let profilePictureUrl: String?
    let status: String?
    let sharedInterests: [String]?

    var id: Int64 { connectionId ?? 0 }

    enum CodingKeys: String, CodingKey {
        case connectionId = "connection_id"
        case userId = "user_id"
        case fullName = "full_name"
        case email
        case profilePictureUrl = "profile_picture_url"
        case status
        case sharedInterests = "shared_interests"
    }
}

// MARK: - SSE Streaming Types

/// Events received during SSE streaming
enum ClaraSSEEvent {
    case status(message: String)
    case toolResult(ToolResultForUI)
    case token(text: String)
    case done(ClaraStreamDoneData)
    case error(message: String)
}

/// Final data sent with "done" SSE event
struct ClaraStreamDoneData: Codable {
    let response: String
    let sessionId: String?
    let insights: [ResponseInsight]?
    let contextMetrics: ContextMetrics?
    let toolResults: [ToolResultForUI]?

    enum CodingKeys: String, CodingKey {
        case response
        case sessionId = "session_id"
        case insights
        case contextMetrics = "context_metrics"
        case toolResults = "tool_results"
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
