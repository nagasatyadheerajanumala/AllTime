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

// MARK: - Health-Based Suggestion (NEW)
struct HealthBasedSuggestion: Codable, Identifiable {
    let title: String
    let description: String
    let category: String // exercise, sleep, nutrition, stress, time_management
    let priority: String // high, medium, low
    let relatedEvent: String? // Related calendar event
    let suggestedTime: String? // Suggested time for the action
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case category
        case priority
        case relatedEvent = "related_event"
        case suggestedTime = "suggested_time"
    }
    
    var id: String { title + (relatedEvent ?? "") }
}

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

// MARK: - Legacy DailySummary (for backward compatibility)
struct DailySummary: Codable, Identifiable {
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

// EventsResponse has been moved to EventsResponse.swift
// This file now only contains DailySummary-related models

