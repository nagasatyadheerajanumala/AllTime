import Foundation

// MARK: - Daily AI Summary Response (New API)
struct DailyAISummaryResponse: Codable, Identifiable {
    let date: String
    let timezone: String
    let overallSummary: String
    let keyHighlights: [String]
    let risksOrConflicts: [String]
    let suggestions: [FreeTimeSuggestion]
    let totalEvents: Int
    let model: String
    let promptTokens: Int?
    let completionTokens: Int?
    
    // Health Integration Fields (NEW)
    let healthBasedSuggestions: [HealthBasedSuggestion]?
    let healthImpactInsights: HealthImpactInsights?
    
    enum CodingKeys: String, CodingKey {
        case date
        case timezone
        case overallSummary = "overall_summary"
        case keyHighlights = "key_highlights"
        case risksOrConflicts = "risks_or_conflicts"
        case suggestions
        case totalEvents = "total_events"
        case model
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case healthBasedSuggestions = "health_based_suggestions"
        case healthImpactInsights = "health_impact_insights"
    }
    
    // Use date as ID for Identifiable
    var id: String { date }
}

// MARK: - Free Time Suggestion
struct FreeTimeSuggestion: Codable, Identifiable {
    let startTime: String?
    let endTime: String?
    let suggestion: String
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case suggestion
        case reason
    }
    
    // Use suggestion + index as ID for Identifiable (since startTime can be nil)
    var id: String { 
        if let startTime = startTime {
            return startTime
        }
        return suggestion
    }
}

// NOTE: HealthBasedSuggestion is now defined in LocationModels.swift for the new API

// MARK: - Health Impact Insights (NEW)
struct HealthImpactInsights: Codable {
    let summary: String?
    let keyCorrelations: [String]?
    let healthTrends: HealthTrends?
    
    enum CodingKeys: String, CodingKey {
        case summary
        case keyCorrelations = "key_correlations"
        case healthTrends = "health_trends"
    }
}

// MARK: - Health Trends
struct HealthTrends: Codable {
    let sleep: String? // improving, declining, stable
    let steps: String?
    let activeMinutes: String?
    let restingHeartRate: String?
    let hrv: String?
    
    enum CodingKeys: String, CodingKey {
        case sleep
        case steps
        case activeMinutes = "active_minutes"
        case restingHeartRate = "resting_heart_rate"
        case hrv
    }
}

// MARK: - Enhanced Daily Summary (New Format)
struct DailySummary: Codable {
    let daySummary: [String]
    let healthSummary: [String]
    let focusRecommendations: [String]
    let alerts: [String]

    enum CodingKeys: String, CodingKey {
        case daySummary = "day_summary"
        case healthSummary = "health_summary"
        case focusRecommendations = "focus_recommendations"
        case alerts
    }
}

// MARK: - Parsed Summary (for UI)
struct ParsedSummary {
    // Sleep
    var sleepHours: Double?
    var sleepStatus: SleepStatus

    // Activity
    var steps: Int?
    var stepsGoal: Int?
    var activeMinutes: Int?
    var activeMinutesGoal: Int?

    // Water
    var waterIntake: Double?
    var waterGoal: Double?
    var dehydrationRisk: Bool

    // Breaks
    var breakStrategy: String?
    var suggestedBreaks: [BreakWindow]

    // Meetings
    var totalMeetings: Int
    var meetingDuration: TimeInterval

    // Alerts
    var criticalAlerts: [Alert]
    var warnings: [Alert]
}

enum SleepStatus {
    case excellent // ≥8 hours
    case good      // 7-8 hours
    case fair      // 6-7 hours
    case poor      // <6 hours
}

struct BreakWindow: Identifiable {
    let id = UUID()
    let time: Date
    let duration: Int // minutes
    let type: BreakType
    let reasoning: String
}

enum BreakType: String {
    case hydration = "💧"
    case meal = "🍽"
    case rest = "😌"
    case movement = "🚶"
    case prep = "📋"

    var displayName: String {
        switch self {
        case .hydration: return "Hydration Break"
        case .meal: return "Meal Break"
        case .rest: return "Rest Break"
        case .movement: return "Movement Break"
        case .prep: return "Prep Time"
        }
    }
}

struct Alert: Identifiable {
    let id = UUID()
    let message: String
    let severity: AlertSeverity
    let category: AlertCategory
}

enum AlertSeverity {
    case critical // 🚨
    case warning  // ⚠️
    case info     // ℹ️
}

enum AlertCategory {
    case sleep
    case hydration
    case activity
    case stress
    case recovery
}

// MARK: - Health Goals (for tracking)
struct HealthGoals: Codable {
    var sleepHours: Double?
    var steps: Int?
    var activeMinutes: Int?
    var activeEnergyBurned: Double?
    var restingHeartRate: Double?
    var hrv: Double?
    var waterIntakeLiters: Double?

    enum CodingKeys: String, CodingKey {
        case sleepHours = "sleep_hours"
        case steps
        case activeMinutes = "active_minutes"
        case activeEnergyBurned = "active_energy_burned"
        case restingHeartRate = "resting_heart_rate"
        case hrv
        case waterIntakeLiters = "water_intake_liters"
    }
}

// MARK: - Legacy Models (for backward compatibility)
struct LegacyDailySummary: Codable, Identifiable {
    let id: Int
    let date: String
    let summaryMarkdown: String
    let signals: SummarySignals
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, date
        case summaryMarkdown = "summary_markdown"
        case signals
        case createdAt = "created_at"
    }
}

struct SummarySignals: Codable {
    let meetingCount: Int
    let totalDuration: Int
    let freeBlocks: Int
    let backToBacks: Int
    let firstMeeting: String?
    let lastMeeting: String?

    enum CodingKeys: String, CodingKey {
        case meetingCount = "meeting_count"
        case totalDuration = "total_duration"
        case freeBlocks = "free_blocks"
        case backToBacks = "back_to_backs"
        case firstMeeting = "first_meeting"
        case lastMeeting = "last_meeting"
    }
}

struct SummaryPreferences: Codable {
    let timezone: String
    let sendHour: Int
    let channel: String
    let includePrivate: Bool

    enum CodingKeys: String, CodingKey {
        case timezone
        case sendHour = "send_hour"
        case channel
        case includePrivate = "include_private"
    }
}

