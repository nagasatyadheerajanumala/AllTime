import Foundation
import SwiftUI

// MARK: - Daily Briefing Response (New /api/v1/today/briefing API)
struct DailyBriefingResponse: Codable, Identifiable {
    let date: String
    let timezone: String
    let generatedAt: String
    let greeting: String?
    let summaryLine: String
    let mood: String
    let priorityLevel: String
    let keyMetrics: BriefingKeyMetrics?
    let focusWindows: [FocusWindow]?
    let energyDips: [EnergyDip]?
    let suggestions: [BriefingSuggestion]?
    let quickStats: QuickStats?
    let dataSources: [String: String]?
    let dayNarrative: DayNarrative?

    // New fields for Clara's opinionated intelligence
    let primaryRecommendation: PrimaryRecommendation?  // THE one thing to do today
    let energyBudget: EnergyBudget?                    // Time → Energy transformation
    let claraPrompts: [ClaraPrompt]?                   // Contextual prompts for Clara

    // 1 Risk + 1 Opportunity + 1 Recommendation model
    let riskInsight: CapacityInsight?                  // Single most important risk
    let opportunityInsight: OpportunityInsight?        // Leverage window/opportunity

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case timezone
        case generatedAt = "generated_at"
        case greeting
        case summaryLine = "summary_line"
        case mood
        case priorityLevel = "priority_level"
        case keyMetrics = "key_metrics"
        case focusWindows = "focus_windows"
        case energyDips = "energy_dips"
        case suggestions
        case quickStats = "quick_stats"
        case dataSources = "data_sources"
        case dayNarrative = "day_narrative"
        case primaryRecommendation = "primary_recommendation"
        case energyBudget = "energy_budget"
        case claraPrompts = "clara_prompts"
        case riskInsight = "risk_insight"
        case opportunityInsight = "opportunity_insight"
    }
}

// MARK: - Briefing Key Metrics (Updated to match new API spec)
struct BriefingKeyMetrics: Codable {
    // Health data availability
    let healthDataAvailable: Bool?

    // Sleep metrics
    let sleepHoursLastNight: Double?
    let sleepHoursAverage: Double?
    let sleepQualityScore: Int?

    // Activity metrics
    let stepsYesterday: Int?
    let stepsAverage: Int?
    let activeMinutesYesterday: Int?
    let activeMinutesAverage: Int?

    // Heart metrics
    let restingHeartRate: Int?
    let hrvLastNight: Int?

    // HEALTH SEVERITY - Clara's opinionated escalation
    let healthSeverity: String?      // "normal", "warning", "critical", "data_suspect"
    let escalationReason: String?    // Why this is escalated
    let isCritical: Bool?            // True if immediate attention needed
    let isDataSuspect: Bool?         // True if values seem erroneous (e.g., 0.3h sleep)

    // Calendar metrics
    let meetingsTodayCount: Int?
    let meetingsAverageCount: Double?
    let totalMeetingHoursToday: Double?
    let freeHoursToday: Double?
    let longestFreeBlockMinutes: Int?

    // Legacy fields for backward compatibility
    let totalMeetings: Int?
    let meetingHours: Double?
    let freeTimeHours: Double?
    let focusTimeAvailable: Double?
    let backToBackCount: Int?
    let longestFreeBlock: Int?
    let sleepScore: Int?
    let energyLevel: String?
    let stepsToday: Int?
    let activeMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case healthDataAvailable = "health_data_available"
        case sleepHoursLastNight = "sleep_hours_last_night"
        case sleepHoursAverage = "sleep_hours_average"
        case sleepQualityScore = "sleep_quality_score"
        case stepsYesterday = "steps_yesterday"
        case stepsAverage = "steps_average"
        case activeMinutesYesterday = "active_minutes_yesterday"
        case activeMinutesAverage = "active_minutes_average"
        case restingHeartRate = "resting_heart_rate"
        case hrvLastNight = "hrv_last_night"
        // Health severity
        case healthSeverity = "health_severity"
        case escalationReason = "escalation_reason"
        case isCritical = "is_critical"
        case isDataSuspect = "is_data_suspect"
        case meetingsTodayCount = "meetings_today_count"
        case meetingsAverageCount = "meetings_average_count"
        case totalMeetingHoursToday = "total_meeting_hours_today"
        case freeHoursToday = "free_hours_today"
        case longestFreeBlockMinutes = "longest_free_block_minutes"
        // Legacy keys
        case totalMeetings = "total_meetings"
        case meetingHours = "meeting_hours"
        case freeTimeHours = "free_time_hours"
        case focusTimeAvailable = "focus_time_available"
        case backToBackCount = "back_to_back_count"
        case longestFreeBlock = "longest_free_block"
        case sleepScore = "sleep_score"
        case energyLevel = "energy_level"
        case stepsToday = "steps_today"
        case activeMinutes = "active_minutes"
    }

    // Computed properties for easy access
    var hasHealthData: Bool {
        healthDataAvailable ?? false
    }

    var effectiveMeetingsCount: Int {
        meetingsTodayCount ?? totalMeetings ?? 0
    }

    var effectiveMeetingHours: Double {
        totalMeetingHoursToday ?? meetingHours ?? 0
    }

    var effectiveFreeHours: Double {
        freeHoursToday ?? freeTimeHours ?? 0
    }

    var effectiveLongestFreeBlock: Int {
        longestFreeBlockMinutes ?? longestFreeBlock ?? 0
    }

    var effectiveSleepHours: Double? {
        sleepHoursLastNight
    }

    var effectiveSteps: Int? {
        stepsYesterday ?? stepsToday
    }

    // MARK: - Health Severity Helpers

    /// True if health status is critical and needs immediate attention
    var isHealthCritical: Bool {
        isCritical ?? false || healthSeverity == "critical"
    }

    /// True if health data might be incorrect (e.g., 0.3h sleep)
    var isHealthDataSuspect: Bool {
        isDataSuspect ?? false || healthSeverity == "data_suspect"
    }

    /// True if health needs attention (warning or worse)
    var needsHealthAttention: Bool {
        isHealthCritical || healthSeverity == "warning"
    }

    /// Get the escalation message if any
    var healthEscalationMessage: String? {
        escalationReason
    }
}

// MARK: - Focus Window
struct FocusWindow: Codable, Identifiable {
    let id: String?
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    let confidenceString: String?
    let confidenceValue: Double?
    let qualityScore: Int?
    let suggestedActivity: String?
    let reason: String?

    var windowId: String {
        id ?? "\(startTime)-\(endTime)"
    }

    // Computed property for confidence level
    var confidenceLevel: String {
        if let str = confidenceString {
            return str
        }
        if let val = confidenceValue {
            if val >= 0.8 { return "high" }
            if val >= 0.5 { return "medium" }
            return "low"
        }
        return "medium"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
        case confidence
        case qualityScore = "quality_score"
        case suggestedActivity = "suggested_activity"
        case reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        startTime = try container.decode(String.self, forKey: .startTime)
        endTime = try container.decode(String.self, forKey: .endTime)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        qualityScore = try container.decodeIfPresent(Int.self, forKey: .qualityScore)
        suggestedActivity = try container.decodeIfPresent(String.self, forKey: .suggestedActivity)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)

        // Handle confidence as either String or Double
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: .confidence) {
            confidenceString = stringValue
            confidenceValue = nil
        } else if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: .confidence) {
            confidenceValue = doubleValue
            confidenceString = nil
        } else {
            confidenceString = nil
            confidenceValue = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(durationMinutes, forKey: .durationMinutes)
        if let str = confidenceString {
            try container.encode(str, forKey: .confidence)
        } else if let val = confidenceValue {
            try container.encode(val, forKey: .confidence)
        }
        try container.encodeIfPresent(qualityScore, forKey: .qualityScore)
        try container.encodeIfPresent(suggestedActivity, forKey: .suggestedActivity)
        try container.encodeIfPresent(reason, forKey: .reason)
    }
}

// MARK: - Energy Dip
struct EnergyDip: Codable, Identifiable {
    let id: String?
    let startTime: String?
    let endTime: String?
    let severity: String
    let reason: String?
    let recommendation: String?
    // Legacy fields
    let time: String?
    let expectedTime: String?
    let dipTime: String?
    let label: String?

    var dipId: String {
        id ?? displayTime
    }

    // Computed property to get the time from various possible fields
    var displayTime: String {
        startTime ?? time ?? expectedTime ?? dipTime ?? label ?? "Unknown"
    }

    var displayEndTime: String? {
        endTime
    }

    enum CodingKeys: String, CodingKey {
        case id
        case startTime = "start_time"
        case endTime = "end_time"
        case severity
        case reason
        case recommendation
        case time
        case expectedTime = "expected_time"
        case dipTime = "dip_time"
        case label
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        time = try container.decodeIfPresent(String.self, forKey: .time)
        expectedTime = try container.decodeIfPresent(String.self, forKey: .expectedTime)
        dipTime = try container.decodeIfPresent(String.self, forKey: .dipTime)
        recommendation = try container.decodeIfPresent(String.self, forKey: .recommendation)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        label = try container.decodeIfPresent(String.self, forKey: .label)

        // Severity can be string or might be missing - default to "mild"
        if let sev = try? container.decodeIfPresent(String.self, forKey: .severity) {
            severity = sev
        } else {
            severity = "mild"
        }
    }
}

// MARK: - Briefing Suggestion (Updated to match new API spec)
struct BriefingSuggestion: Codable, Identifiable {
    let id: String?
    let title: String
    let timeLabel: String?
    let description: String?
    let category: String?
    let severity: String?
    let priority: Int?
    let recommendedStart: String?
    let recommendedEnd: String?
    let durationMinutes: Int?
    let primaryActionLabel: String?
    let primaryActionType: String?
    let secondaryActionLabel: String?
    let secondaryActionType: String?
    let icon: String?
    let color: String?
    let dismissible: Bool?
    let metadata: [String: AnyCodable]?
    // Legacy fields
    let suggestedTime: String?
    let actionType: String?
    let actionPayload: AnyCodable?

    var suggestionId: String {
        id ?? title
    }

    // Computed property for effective time display
    var effectiveTimeLabel: String? {
        timeLabel ?? suggestedTime
    }

    // Computed property for action type
    var effectiveActionType: String? {
        primaryActionType ?? actionType
    }

    // Computed property for action label - generates one if not provided
    var effectiveActionLabel: String? {
        if let label = primaryActionLabel, !label.isEmpty {
            return label
        }
        // Generate label from action type
        guard let actionType = effectiveActionType else { return nil }
        switch actionType {
        case "view_food_places": return "View Places"
        case "view_walk_routes": return "View Routes"
        case "block_time": return "Block Time"
        case "add_to_calendar": return "Add to Calendar"
        case "open_calendar": return "Open Calendar"
        case "view_details": return "View Details"
        case "open_map": return "Open Map"
        case "open_maps": return "Open Maps"
        default: return nil
        }
    }

    // Check if this suggestion has an actionable button
    var hasAction: Bool {
        effectiveActionType != nil && effectiveActionLabel != nil
    }

    // Check if this suggestion has a secondary action
    var hasSecondaryAction: Bool {
        secondaryActionType != nil && secondaryActionLabel != nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case timeLabel = "time_label"
        case description
        case category
        case severity
        case priority
        case recommendedStart = "recommended_start"
        case recommendedEnd = "recommended_end"
        case durationMinutes = "duration_minutes"
        case primaryActionLabel = "primary_action_label"
        case primaryActionType = "primary_action_type"
        case secondaryActionLabel = "secondary_action_label"
        case secondaryActionType = "secondary_action_type"
        case icon
        case color
        case dismissible
        case metadata
        // Legacy keys
        case suggestedTime = "suggested_time"
        case actionType = "action_type"
        case actionPayload = "action_payload"
    }
}

// MARK: - Day Narrative (Plain-English story about the day/week)
struct DayNarrative: Codable {
    let type: String // "daily" or "weekly"
    let headline: String
    let story: String
    let keyObservations: [String]?
    let healthConnection: String?
    let lookingAhead: String?
    let tone: String // "positive", "neutral", "cautionary"
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case type
        case headline
        case story
        case keyObservations = "key_observations"
        case healthConnection = "health_connection"
        case lookingAhead = "looking_ahead"
        case tone
        case icon
    }

    // Tone-based styling
    var toneColor: Color {
        switch tone.lowercased() {
        case "positive": return DesignSystem.Colors.emerald // Green
        case "cautionary": return DesignSystem.Colors.amber // Amber
        default: return DesignSystem.Colors.secondaryText // Neutral
        }
    }

    var toneIcon: String {
        if let icon = icon, !icon.isEmpty { return icon }
        switch tone.lowercased() {
        case "positive": return "sun.max.fill"
        case "cautionary": return "exclamationmark.triangle.fill"
        default: return "text.quote"
        }
    }

    var isDaily: Bool { type.lowercased() == "daily" }
    var isWeekly: Bool { type.lowercased() == "weekly" }
}

// MARK: - Quick Stats (Updated to match new API spec)
struct QuickStats: Codable {
    let meetingsCount: Int?
    let meetingsLabel: String?
    let focusTimeAvailable: String?
    let topSuggestion: String?
    let healthScore: Int?
    let healthLabel: String?
    // Legacy fields
    let energyForecast: String?
    let nextFreeBlock: String?

    enum CodingKeys: String, CodingKey {
        case meetingsCount = "meetings_count"
        case meetingsLabel = "meetings_label"
        case focusTimeAvailable = "focus_time_available"
        case topSuggestion = "top_suggestion"
        case healthScore = "health_score"
        case healthLabel = "health_label"
        case energyForecast = "energy_forecast"
        case nextFreeBlock = "next_free_block"
    }

    // Computed property for health score color
    var healthScoreColor: Color {
        guard let score = healthScore else { return DesignSystem.Colors.secondaryText }
        switch score {
        case 80...100: return DesignSystem.Colors.emerald // Green
        case 65..<80: return Color(hex: "34D399") // Mint
        case 50..<65: return DesignSystem.Colors.amber // Yellow
        case 35..<50: return Color(hex: "F97316") // Orange
        default: return DesignSystem.Colors.errorRed // Red
        }
    }

    var healthScoreLabel: String {
        guard let score = healthScore else { return healthLabel ?? "Unknown" }
        switch score {
        case 80...100: return "Excellent"
        case 65..<80: return "Good"
        case 50..<65: return "Fair"
        case 35..<50: return "Needs attention"
        default: return "Low energy"
        }
    }
}

// MARK: - Mood Extensions
extension DailyBriefingResponse {
    /// Returns gradient colors based on mood
    var moodGradient: LinearGradient {
        switch mood.lowercased() {
        case "focus_day", "focused":
            return LinearGradient(
                colors: [DesignSystem.Colors.blue, DesignSystem.Colors.blueDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "light_day", "light":
            return LinearGradient(
                colors: [DesignSystem.Colors.emerald, DesignSystem.Colors.emeraldDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "intense_meetings", "intense", "busy":
            return LinearGradient(
                colors: [DesignSystem.Colors.amber, DesignSystem.Colors.amberDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "rest_day", "rest":
            return LinearGradient(
                colors: [DesignSystem.Colors.violet, DesignSystem.Colors.violetDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "balanced":
            return LinearGradient(
                colors: [Color(hex: "6B7280"), Color(hex: "4B5563")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Returns mood icon based on mood type
    var moodIcon: String {
        switch mood.lowercased() {
        case "focus_day", "focused":
            return "brain.head.profile"
        case "light_day", "light":
            return "sun.max.fill"
        case "intense_meetings", "intense", "busy":
            return "flame.fill"
        case "rest_day", "rest":
            return "leaf.fill"
        case "balanced":
            return "scale.3d"
        default:
            return "sparkles"
        }
    }

    /// Returns human-readable mood label
    var moodLabel: String {
        switch mood.lowercased() {
        case "focus_day", "focused":
            return "Focus Day"
        case "light_day", "light":
            return "Light Day"
        case "intense_meetings", "intense", "busy":
            return "Busy Day"
        case "rest_day", "rest":
            return "Rest Day"
        case "balanced":
            return "Balanced"
        default:
            return mood.capitalized
        }
    }
}

// MARK: - Category Color Mapping
extension BriefingSuggestion {
    var categoryColor: Color {
        // First check if color is provided directly
        if let hexColor = color, !hexColor.isEmpty {
            return Color(hex: hexColor)
        }
        // Fall back to category-based color
        switch (category ?? "").lowercased() {
        case "health", "wellness", "health_insight":
            return DesignSystem.Colors.emerald // Green
        case "productivity", "focus":
            return Color(hex: "5856D6") // Purple
        case "break", "rest":
            return Color(hex: "007AFF") // Blue
        case "meeting", "calendar", "routine":
            return DesignSystem.Colors.success // Green
        case "exercise", "activity", "movement":
            return DesignSystem.Colors.success // Green (or FF9500 for alerts)
        case "nutrition", "meal", "food":
            return DesignSystem.Colors.warning // Orange
        case "hydration", "water":
            return Color(hex: "06B6D4") // Cyan
        case "warning":
            return DesignSystem.Colors.warning // Orange
        default:
            return DesignSystem.Colors.primary
        }
    }

    var severityColor: Color {
        switch (severity ?? "").lowercased() {
        case "alert", "critical":
            return DesignSystem.Colors.errorRed // Red
        case "important", "high":
            return DesignSystem.Colors.amber // Amber
        case "reminder", "medium":
            return DesignSystem.Colors.blue // Blue
        case "info", "low":
            return DesignSystem.Colors.secondaryText
        default:
            return DesignSystem.Colors.secondaryText
        }
    }

    var displayIcon: String {
        if let icon = icon, !icon.isEmpty {
            return icon
        }
        // Default icons based on category
        switch (category ?? "").lowercased() {
        case "health", "wellness", "health_insight":
            return "heart.fill"
        case "productivity", "focus":
            return "brain.head.profile"
        case "break", "rest":
            return "pause.circle.fill"
        case "meeting", "calendar":
            return "calendar"
        case "routine":
            return "calendar.badge.checkmark"
        case "exercise", "activity", "movement":
            return "figure.walk"
        case "nutrition", "meal", "food":
            return "fork.knife"
        case "hydration", "water":
            return "drop.fill"
        case "warning":
            return "exclamationmark.triangle"
        default:
            return "lightbulb.fill"
        }
    }

    var isDismissible: Bool {
        dismissible ?? true
    }
}

// MARK: - Energy Dip Extensions
extension EnergyDip {
    var severityColor: Color {
        switch severity.lowercased() {
        case "significant", "high", "critical":
            return DesignSystem.Colors.errorRed // Red
        case "moderate", "medium":
            return DesignSystem.Colors.amber // Amber
        case "mild", "low":
            return Color(hex: "FBBF24") // Yellow
        default:
            return DesignSystem.Colors.secondaryText
        }
    }

    var severityIcon: String {
        switch severity.lowercased() {
        case "significant", "high", "critical":
            return "exclamationmark.triangle.fill"
        case "moderate", "medium":
            return "exclamationmark.circle.fill"
        case "mild", "low":
            return "info.circle.fill"
        default:
            return "battery.25"
        }
    }
}

// MARK: - Focus Window Extensions
extension FocusWindow {
    var confidenceBadge: String {
        switch confidenceLevel.lowercased() {
        case "high": return "High"
        case "medium": return "Medium"
        case "low": return "Low"
        default: return ""
        }
    }

    var confidenceColor: Color {
        switch confidenceLevel.lowercased() {
        case "high": return DesignSystem.Colors.emerald // Green
        case "medium": return DesignSystem.Colors.amber // Amber
        case "low": return DesignSystem.Colors.errorRed // Red
        default: return DesignSystem.Colors.secondaryText
        }
    }

    var qualityBadge: String {
        guard let score = qualityScore else { return "" }
        if score >= 80 { return "Excellent" }
        if score >= 60 { return "Good" }
        if score >= 40 { return "Fair" }
        return "Low"
    }

    // Parse to Date
    var startDate: Date? {
        parseLocalDateTime(startTime)
    }

    var endDate: Date? {
        parseLocalDateTime(endTime)
    }

    // Formatted time range
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        guard let start = startDate, let end = endDate else {
            return TimeRangeFormatter.format(start: startTime, end: endTime, compact: true)
        }

        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private func parseLocalDateTime(_ timeString: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                f.timeZone = TimeZone.current
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "HH:mm:ss"
                f.timeZone = TimeZone.current
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "HH:mm"
                f.timeZone = TimeZone.current
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: timeString) {
                return date
            }
        }
        return nil
    }
}

// AnyCodable is defined in AnyCodable.swift

// MARK: - Primary Recommendation (THE one non-negotiable recommendation)
/// Clara's Philosophy: Clara does not just "surface options" - it makes ONE recommendation.
/// If the user does one thing today, do THIS.
struct PrimaryRecommendation: Codable, Identifiable {
    let rawId: String?
    let action: String                    // "Block 90 minutes for deep work"
    let reason: String?                   // "Low external demand + high flexibility..."
    let urgency: String?                  // "now", "today", "this_week"
    let impact: String?                   // "high", "medium"
    let category: String?                 // "protect_time", "reduce_load", "health", "catch_up"
    let icon: String?
    let deepLink: String?
    let confidence: Int?                  // 0-100 how confident Clara is
    let ignoredConsequence: String?       // What happens if they ignore this

    // Identifiable conformance - non-optional id
    var id: String { rawId ?? action }
    var recommendationId: String { id }

    enum CodingKeys: String, CodingKey {
        case rawId = "id"
        case action, reason, urgency, impact, category, icon
        case deepLink = "deep_link"
        case confidence
        case ignoredConsequence = "ignored_consequence"
    }

    // Urgency styling
    var urgencyColor: Color {
        switch (urgency ?? "").lowercased() {
        case "now": return DesignSystem.Colors.errorRed      // Red - urgent
        case "today": return DesignSystem.Colors.amber   // Amber - important
        case "this_week": return DesignSystem.Colors.blue // Blue - can wait
        default: return DesignSystem.Colors.secondaryText
        }
    }

    var urgencyLabel: String {
        switch (urgency ?? "").lowercased() {
        case "now": return "Do now"
        case "today": return "Today"
        case "this_week": return "This week"
        default: return "Recommended"
        }
    }

    var impactColor: Color {
        switch (impact ?? "").lowercased() {
        case "high": return DesignSystem.Colors.emerald    // Green
        case "medium": return DesignSystem.Colors.amber // Amber
        default: return DesignSystem.Colors.secondaryText
        }
    }

    var displayIcon: String {
        icon ?? categoryIcon
    }

    var categoryIcon: String {
        switch (category ?? "").lowercased() {
        case "protect_time": return "shield.fill"
        case "reduce_load": return "minus.circle.fill"
        case "health": return "heart.fill"
        case "catch_up": return "checkmark.circle.fill"
        case "movement": return "figure.walk"
        default: return "star.fill"
        }
    }

    var isHighConfidence: Bool {
        (confidence ?? 0) >= 75
    }
}

// MARK: - Energy Budget (Time → Energy Transformation)
/// Clara's Philosophy: Time is not neutral. A meeting-free day can still be draining.
/// This model shows how today's inputs transform into energy capacity.
struct EnergyBudget: Codable {
    let currentLevel: Int?                // 0-100 current energy estimate
    let predictedEndOfDay: Int?           // 0-100 where energy will be at end of day
    let trajectory: String?               // "rising", "stable", "declining", "recovering"
    let trajectoryLabel: String?          // "Energy likely to decline by evening"
    let capacityLabel: String?            // "High capacity", "Moderate capacity", etc.
    let energyDrains: [BriefingEnergyFactor]?     // What's consuming energy
    let energyDeposits: [BriefingEnergyFactor]?   // What's restoring energy
    let netEnergyChange: Int?             // Predicted change from now to end of day
    let peakWindow: EnergyWindow?         // When energy will be highest
    let lowWindow: EnergyWindow?          // When energy will be lowest
    let recoveryNeeded: Bool?
    let recoveryRecommendation: String?

    enum CodingKeys: String, CodingKey {
        case currentLevel = "current_level"
        case predictedEndOfDay = "predicted_end_of_day"
        case trajectory
        case trajectoryLabel = "trajectory_label"
        case capacityLabel = "capacity_label"
        case energyDrains = "energy_drains"
        case energyDeposits = "energy_deposits"
        case netEnergyChange = "net_energy_change"
        case peakWindow = "peak_window"
        case lowWindow = "low_window"
        case recoveryNeeded = "recovery_needed"
        case recoveryRecommendation = "recovery_recommendation"
    }

    // Trajectory styling
    var trajectoryColor: Color {
        switch (trajectory ?? "").lowercased() {
        case "rising": return DesignSystem.Colors.emerald       // Green
        case "stable": return DesignSystem.Colors.blue      // Blue
        case "declining": return DesignSystem.Colors.amber   // Amber
        case "recovering": return DesignSystem.Colors.violet  // Purple
        default: return DesignSystem.Colors.secondaryText
        }
    }

    var trajectoryIcon: String {
        switch (trajectory ?? "").lowercased() {
        case "rising": return "arrow.up.right"
        case "stable": return "arrow.right"
        case "declining": return "arrow.down.right"
        case "recovering": return "arrow.counterclockwise"
        default: return "minus"
        }
    }

    var capacityColor: Color {
        guard let level = currentLevel else { return DesignSystem.Colors.secondaryText }
        if level >= 80 { return DesignSystem.Colors.emerald }      // Green
        if level >= 60 { return DesignSystem.Colors.blue }      // Blue
        if level >= 40 { return DesignSystem.Colors.amber }      // Amber
        return DesignSystem.Colors.errorRed                          // Red
    }

    var levelPercentage: Double {
        Double(currentLevel ?? 50) / 100.0
    }

    var needsRecovery: Bool {
        recoveryNeeded ?? false
    }
}

// MARK: - Briefing Energy Factor (Drains or Deposits)
/// Named BriefingEnergyFactor to avoid conflict with EnergyFactor in EnergyPredictor.swift
struct BriefingEnergyFactor: Codable, Identifiable {
    let id: String?
    let label: String?
    let impact: Int?                      // -30 to +30
    let category: String?                 // "sleep", "meetings", "activity", etc.
    let icon: String?
    let detail: String?

    var factorId: String { id ?? label ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case id, label, impact, category, icon, detail
    }

    var isDrain: Bool {
        (impact ?? 0) < 0
    }

    var isDeposit: Bool {
        (impact ?? 0) > 0
    }

    var impactColor: Color {
        guard let impact = impact else { return DesignSystem.Colors.secondaryText }
        if impact > 0 { return DesignSystem.Colors.emerald }  // Green for deposits
        if impact < 0 { return DesignSystem.Colors.errorRed }  // Red for drains
        return DesignSystem.Colors.secondaryText
    }

    var displayIcon: String {
        if let icon = icon, !icon.isEmpty { return icon }
        switch (category ?? "").lowercased() {
        case "sleep": return "moon.zzz.fill"
        case "meetings": return "calendar.badge.exclamationmark"
        case "activity": return "figure.walk"
        case "recovery": return "heart.fill"
        case "stress": return "exclamationmark.triangle.fill"
        default: return "bolt.fill"
        }
    }

    var formattedImpact: String {
        guard let impact = impact else { return "" }
        if impact > 0 { return "+\(impact)" }
        return "\(impact)"
    }
}

// MARK: - Energy Window (Peak/Low periods)
struct EnergyWindow: Codable {
    let startTime: String?
    let endTime: String?
    let label: String?                    // "9:00 AM - 11:30 AM"
    let energyLevel: Int?                 // 0-100
    let reason: String?

    // Opportunity framing - frame peak windows positively
    let isOpportunity: Bool?              // True if this is an actionable opportunity
    let leverageReason: String?           // "Good sleep + light calendar = use for hardest work"

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case label
        case energyLevel = "energy_level"
        case reason
        case isOpportunity = "is_opportunity"
        case leverageReason = "leverage_reason"
    }

    var displayLabel: String {
        label ?? TimeRangeFormatter.format(start: startTime ?? "", end: endTime ?? "", compact: true)
    }

    /// True if this window should be framed as an opportunity
    var shouldShowAsOpportunity: Bool {
        isOpportunity == true && leverageReason != nil
    }
}

// MARK: - Clara Prompt (Contextual prompts for Clara interaction)
/// Clara's Philosophy: Instead of a generic AI entry point, provide SPECIFIC prompts.
/// "Ask Clara why this day matters" - not open-ended chat.
struct ClaraPrompt: Codable, Identifiable {
    let rawId: String?
    let label: String?                    // "Why is today high-leverage?"
    let fullPrompt: String?               // "Ask Clara why this is a high-leverage day"
    let description: String?              // Tooltip/description
    let icon: String?
    let category: String?                 // "insight", "action", "planning", "health"
    let priority: Int?                    // Lower = shown first
    let contextSpecific: Bool?            // True if based on today's specific context

    // Identifiable conformance - non-optional id
    var id: String { rawId ?? label ?? UUID().uuidString }
    var promptId: String { id }

    enum CodingKeys: String, CodingKey {
        case rawId = "id"
        case label
        case fullPrompt = "full_prompt"
        case description
        case icon
        case category
        case priority
        case contextSpecific = "context_specific"
    }

    var displayIcon: String {
        if let icon = icon, !icon.isEmpty { return icon }
        switch (category ?? "").lowercased() {
        case "insight": return "lightbulb.fill"
        case "action": return "bolt.fill"
        case "planning": return "calendar"
        case "health": return "heart.fill"
        default: return "bubble.left.fill"
        }
    }

    var categoryColor: Color {
        switch (category ?? "").lowercased() {
        case "insight": return DesignSystem.Colors.violet     // Purple
        case "action": return DesignSystem.Colors.amber     // Amber
        case "planning": return DesignSystem.Colors.blue   // Blue
        case "health": return DesignSystem.Colors.emerald     // Green
        default: return DesignSystem.Colors.primary
        }
    }

    var isContextSpecific: Bool {
        contextSpecific ?? false
    }
}

// MARK: - Opportunity Insight (Balance risks with leverage windows)
/// Clara's Philosophy: Don't just surface problems - highlight opportunities.
/// This creates the positive/actionable counterbalance to risk insights.
struct OpportunityInsight: Codable, Identifiable {
    let rawId: String?
    let type: String?                     // "leverage_window", "peak_capacity", "protected_time", "momentum_opportunity"
    let headline: String?                 // "Rare leverage window today"
    let windowStart: String?
    let windowEnd: String?
    let reason: String?                   // "Good sleep + open calendar = rare opportunity"
    let suggestedUse: String?             // "Strategic thinking or deep work"
    let confidence: Int?                  // 0-100
    let icon: String?
    let deepLink: String?

    var id: String { rawId ?? type ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case rawId = "id"
        case type
        case headline
        case windowStart = "window_start"
        case windowEnd = "window_end"
        case reason
        case suggestedUse = "suggested_use"
        case confidence
        case icon
        case deepLink = "deep_link"
    }

    // Type constants
    static let typeLeverageWindow = "leverage_window"
    static let typePeakCapacity = "peak_capacity"
    static let typeProtectedTime = "protected_time"
    static let typeMomentumOpportunity = "momentum_opportunity"

    var displayIcon: String {
        if let icon = icon, !icon.isEmpty { return icon }
        switch (type ?? "").lowercased() {
        case "leverage_window": return "bolt.fill"
        case "peak_capacity": return "brain.head.profile"
        case "protected_time": return "sunrise.fill"
        case "momentum_opportunity": return "hare.fill"
        default: return "star.fill"
        }
    }

    var displayHeadline: String {
        headline ?? "Opportunity today"
    }

    var typeColor: Color {
        switch (type ?? "").lowercased() {
        case "leverage_window": return DesignSystem.Colors.amber       // Gold/amber for high value
        case "peak_capacity": return DesignSystem.Colors.violet        // Purple for cognitive
        case "protected_time": return DesignSystem.Colors.blue         // Blue for time
        case "momentum_opportunity": return DesignSystem.Colors.emerald // Green for momentum
        default: return DesignSystem.Colors.primary
        }
    }

    var typeLabel: String {
        switch (type ?? "").lowercased() {
        case "leverage_window": return "Leverage Window"
        case "peak_capacity": return "Peak Capacity"
        case "protected_time": return "Protected Time"
        case "momentum_opportunity": return "Momentum Day"
        default: return "Opportunity"
        }
    }

    var windowLabel: String? {
        guard let start = windowStart, let end = windowEnd else { return nil }
        return TimeRangeFormatter.format(start: start, end: end, compact: true)
    }

    var isHighConfidence: Bool {
        (confidence ?? 0) >= 80
    }
}
