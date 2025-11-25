import Foundation

// MARK: - Enhanced Daily Summary Response (v1 API)
struct EnhancedDailySummaryResponse: Codable, Identifiable {
    let date: String
    let overview: String
    let keyHighlights: [HighlightItem]
    let potentialIssues: [IssueItem]
    let suggestions: [SuggestionItem]
    let dayIntel: DayIntel
    
    enum CodingKeys: String, CodingKey {
        case date
        case overview
        case keyHighlights = "key_highlights"
        case potentialIssues = "potential_issues"
        case suggestions
        case dayIntel = "day_intel"
    }
    
    var id: String { date }
}

// MARK: - Highlight Item
struct HighlightItem: Codable, Identifiable {
    let title: String
    let details: String?
    
    var id: String { title }
}

// MARK: - Issue Item
struct IssueItem: Codable, Identifiable {
    let title: String
    let details: String?
    
    var id: String { title }
}

// MARK: - Suggestion Item
struct SuggestionItem: Codable, Identifiable {
    let timeWindow: TimeWindow?
    let headline: String
    let details: String?
    
    enum CodingKeys: String, CodingKey {
        case timeWindow = "time_window"
        case headline
        case details
    }
    
    var id: String { headline }
}

// MARK: - Time Window
struct TimeWindow: Codable {
    let start: String?
    let end: String?
}

// MARK: - Day Intel
struct DayIntel: Codable {
    let aggregates: DayIntelAggregates
    let gaps: [TimeGap]
    let overlaps: [EventOverlap]
    let backToBackBlocks: [BackToBackBlock]
    let healthRisks: HealthRisks
    let contextTotals: [String: Int] // Backend returns simple counts, not ContextTotal objects
    let eventsByContext: [String: [String]] // context -> event IDs
    
    enum CodingKeys: String, CodingKey {
        case aggregates
        case gaps
        case overlaps
        case backToBackBlocks = "back_to_back_blocks"
        case healthRisks = "health_risks"
        case contextTotals = "context_totals"
        case eventsByContext = "events_by_context"
    }
}

// MARK: - Day Intel Aggregates
struct DayIntelAggregates: Codable {
    let totalEvents: Int
    let meetingMinutes: Int
    let firstEventTime: String?
    let lastEventTime: String?
    let hasEarlyStart: Bool
    let hasLateEnd: Bool
    
    enum CodingKeys: String, CodingKey {
        case totalEvents = "total_events"
        case meetingMinutes = "meeting_minutes"
        case firstEventTime = "first_event_time"
        case lastEventTime = "last_event_time"
        case hasEarlyStart = "has_early_start"
        case hasLateEnd = "has_late_end"
    }
}

// MARK: - Time Gap
struct TimeGap: Codable, Identifiable {
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    
    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
    }
    
    var id: String { "\(startTime)-\(endTime)" }
}

// MARK: - Event Overlap
struct EventOverlap: Codable, Identifiable {
    let eventIds: [String]
    let startTime: String
    let endTime: String
    
    enum CodingKeys: String, CodingKey {
        case eventIds = "event_ids"
        case startTime = "start_time"
        case endTime = "end_time"
    }
    
    var id: String { eventIds.joined(separator: "-") }
}

// MARK: - Back to Back Block
struct BackToBackBlock: Codable, Identifiable {
    let eventIds: [String]
    let startTime: String
    let endTime: String
    let totalMinutes: Int
    
    enum CodingKeys: String, CodingKey {
        case eventIds = "event_ids"
        case startTime = "start_time"
        case endTime = "end_time"
        case totalMinutes = "total_minutes"
    }
    
    var id: String { eventIds.joined(separator: "-") }
}

// MARK: - Health Risks
struct HealthRisks: Codable {
    let lunchRisk: Bool
    let dinnerRisk: Bool
    let travelRisks: [TravelRisk]
    let fatigueRisk: FatigueRisk
    
    enum CodingKeys: String, CodingKey {
        case lunchRisk = "lunch_risk"
        case dinnerRisk = "dinner_risk"
        case travelRisks = "travel_risks"
        case fatigueRisk = "fatigue_risk"
    }
}

// MARK: - Travel Risk
struct TravelRisk: Codable {
    let risk: String
    let details: String?
}

// MARK: - Fatigue Risk
struct FatigueRisk: Codable {
    let hasRisk: Bool
    let riskLevel: String
    let meetingDensity: Double
    let consecutiveHours: Int
    let reason: String?
    
    enum CodingKeys: String, CodingKey {
        case hasRisk = "has_risk"
        case riskLevel = "risk_level"
        case meetingDensity = "meeting_density"
        case consecutiveHours = "consecutive_hours"
        case reason
    }
}

// MARK: - Context Total
struct ContextTotal: Codable {
    let minutes: Int
    let count: Int
}

