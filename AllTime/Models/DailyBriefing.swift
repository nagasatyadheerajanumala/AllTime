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
        case 80...100: return Color(hex: "10B981") // Green
        case 65..<80: return Color(hex: "34D399") // Mint
        case 50..<65: return Color(hex: "F59E0B") // Yellow
        case 35..<50: return Color(hex: "F97316") // Orange
        default: return Color(hex: "EF4444") // Red
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
                colors: [Color(hex: "3B82F6"), Color(hex: "1D4ED8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "light_day", "light":
            return LinearGradient(
                colors: [Color(hex: "10B981"), Color(hex: "059669")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "intense_meetings", "intense", "busy":
            return LinearGradient(
                colors: [Color(hex: "F59E0B"), Color(hex: "D97706")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "rest_day", "rest":
            return LinearGradient(
                colors: [Color(hex: "8B5CF6"), Color(hex: "7C3AED")],
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
            return Color(hex: "10B981") // Green
        case "productivity", "focus":
            return Color(hex: "5856D6") // Purple
        case "break", "rest":
            return Color(hex: "007AFF") // Blue
        case "meeting", "calendar", "routine":
            return Color(hex: "34C759") // Green
        case "exercise", "activity", "movement":
            return Color(hex: "34C759") // Green (or FF9500 for alerts)
        case "nutrition", "meal", "food":
            return Color(hex: "FF9500") // Orange
        case "hydration", "water":
            return Color(hex: "06B6D4") // Cyan
        case "warning":
            return Color(hex: "FF9500") // Orange
        default:
            return DesignSystem.Colors.primary
        }
    }

    var severityColor: Color {
        switch (severity ?? "").lowercased() {
        case "alert", "critical":
            return Color(hex: "EF4444") // Red
        case "important", "high":
            return Color(hex: "F59E0B") // Amber
        case "reminder", "medium":
            return Color(hex: "3B82F6") // Blue
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
            return Color(hex: "EF4444") // Red
        case "moderate", "medium":
            return Color(hex: "F59E0B") // Amber
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
        case "high": return Color(hex: "10B981") // Green
        case "medium": return Color(hex: "F59E0B") // Amber
        case "low": return Color(hex: "EF4444") // Red
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
