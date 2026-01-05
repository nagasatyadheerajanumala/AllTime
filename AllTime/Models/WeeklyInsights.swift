import Foundation
import SwiftUI

// MARK: - Weekly Insights Summary Response

struct WeeklyInsightsSummaryResponse: Codable {
    let weekStart: String
    let weekEnd: String
    let recap: RecapSection
    let nextWeekFocus: NextWeekFocusSection
    let generatedAt: String?

    // Computed properties
    var weekStartDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: weekStart)
    }

    var weekEndDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: weekEnd)
    }

    var weekLabel: String {
        guard let start = weekStartDate, let end = weekEndDate else {
            return "Week of \(weekStart)"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - Recap Section

struct RecapSection: Codable {
    let headline: String
    let keyMetrics: [KeyMetric]
    let whatWentWrong: [ProblemItem]?
    let highlights: [WeeklyHighlightItem]?
}

struct KeyMetric: Codable, Identifiable {
    let label: String
    let value: String

    var id: String { label }

    var icon: String {
        switch label.lowercased() {
        case "meetings": return "calendar"
        case "busy time": return "clock.fill"
        case "overload days": return "exclamationmark.triangle.fill"
        case "longest focus block": return "brain.head.profile"
        default: return "chart.bar.fill"
        }
    }

    var color: Color {
        switch label.lowercased() {
        case "meetings": return Color(hex: "3B82F6") // Blue
        case "busy time": return Color(hex: "8B5CF6") // Purple
        case "overload days": return Color(hex: "EF4444") // Red
        case "longest focus block": return Color(hex: "10B981") // Green
        default: return Color(hex: "6B7280") // Gray
        }
    }
}

struct ProblemItem: Codable, Identifiable {
    let title: String
    let detail: String

    var id: String { title }
}

struct WeeklyHighlightItem: Codable, Identifiable {
    let title: String
    let detail: String

    var id: String { title }
}

// MARK: - Next Week Focus Section

struct NextWeekFocusSection: Codable {
    let headline: String
    let priorities: [Priority]
    let suggestedBlocks: [SuggestedBlock]?
    let plan: PlanInfo?
}

struct Priority: Codable, Identifiable {
    let title: String
    let detail: String
    let icon: String?

    var id: String { title }

    var sfSymbol: String {
        // Map backend icons to SF Symbols
        switch icon {
        case "calendar.badge.plus": return "calendar.badge.plus"
        case "clock.badge.checkmark": return "clock.badge.checkmark"
        case "moon.stars": return "moon.stars"
        case "calendar.badge.exclamationmark": return "calendar.badge.exclamationmark"
        case "arrow.triangle.2.circlepath": return "arrow.triangle.2.circlepath"
        default: return "lightbulb.fill"
        }
    }
}

struct SuggestedBlock: Codable, Identifiable {
    let type: String
    let date: String
    let start: String
    let end: String
    let reason: String

    var id: String { "\(date)-\(start)" }

    var blockDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    var dayOfWeek: String {
        guard let date = blockDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    var formattedTime: String {
        return "\(start) - \(end)"
    }

    var typeIcon: String {
        switch type {
        case "focus": return "brain.head.profile"
        case "buffer": return "clock.arrow.circlepath"
        case "break": return "cup.and.saucer"
        default: return "calendar"
        }
    }

    var typeColor: Color {
        switch type {
        case "focus": return Color(hex: "10B981") // Green
        case "buffer": return Color(hex: "F59E0B") // Orange
        case "break": return Color(hex: "3B82F6") // Blue
        default: return Color(hex: "6B7280") // Gray
        }
    }
}

struct PlanInfo: Codable {
    let available: Bool
    let changeCount: Int
    let requiresApproval: Bool
}

// MARK: - Available Weeks Response

struct AvailableWeeksResponse: Codable {
    let weeks: [WeekOption]
    let currentWeek: String
}

struct WeekOption: Codable, Identifiable, Hashable {
    let weekStart: String
    let weekEnd: String
    let label: String

    var id: String { weekStart }
}

// MARK: - Weekly Narrative Response (New Calm UI)

struct WeeklyNarrativeResponse: Codable {
    let weekStart: String
    let weekEnd: String
    let overallTone: String // "Calm", "Balanced", "Overloaded", "Draining"
    let weeklyOverview: String // One sentence summary
    let timeBuckets: [TimeBucket]?
    let energyAlignment: EnergyAlignment?
    let stressSignals: [StressSignal]?
    let suggestions: [WeeklySuggestion]?
    let aggregates: WeeklyAggregates?
    let comparison: WeekComparison? // Week-over-week comparison for report card
    let healthGoals: HealthGoalSummary? // Health goal achievement tracking
    let weekHighlights: WeekHighlights? // Specific interesting highlights

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case overallTone = "overall_tone"
        case weeklyOverview = "weekly_overview"
        case timeBuckets = "time_buckets"
        case energyAlignment = "energy_alignment"
        case stressSignals = "stress_signals"
        case suggestions
        case aggregates
        case comparison
        case healthGoals = "health_goals"
        case weekHighlights = "week_highlights"
    }

    // Custom initializer to handle both snake_case and camelCase
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try snake_case first, then camelCase fallback
        if let ws = try? container.decode(String.self, forKey: .weekStart) {
            weekStart = ws
        } else {
            let fallbackContainer = try decoder.container(keyedBy: FallbackCodingKeys.self)
            weekStart = try fallbackContainer.decode(String.self, forKey: .weekStart)
        }

        if let we = try? container.decode(String.self, forKey: .weekEnd) {
            weekEnd = we
        } else {
            let fallbackContainer = try decoder.container(keyedBy: FallbackCodingKeys.self)
            weekEnd = try fallbackContainer.decode(String.self, forKey: .weekEnd)
        }

        if let ot = try? container.decode(String.self, forKey: .overallTone) {
            overallTone = ot
        } else {
            let fallbackContainer = try decoder.container(keyedBy: FallbackCodingKeys.self)
            overallTone = try fallbackContainer.decode(String.self, forKey: .overallTone)
        }

        if let wo = try? container.decode(String.self, forKey: .weeklyOverview) {
            weeklyOverview = wo
        } else {
            let fallbackContainer = try decoder.container(keyedBy: FallbackCodingKeys.self)
            weeklyOverview = try fallbackContainer.decode(String.self, forKey: .weeklyOverview)
        }

        // Optional fields - try snake_case first, then camelCase
        if let tb = try? container.decode([TimeBucket].self, forKey: .timeBuckets) {
            timeBuckets = tb
        } else {
            timeBuckets = try? decoder.container(keyedBy: FallbackCodingKeys.self).decode([TimeBucket].self, forKey: .timeBuckets)
        }

        if let ea = try? container.decode(EnergyAlignment.self, forKey: .energyAlignment) {
            energyAlignment = ea
        } else {
            energyAlignment = try? decoder.container(keyedBy: FallbackCodingKeys.self).decode(EnergyAlignment.self, forKey: .energyAlignment)
        }

        if let ss = try? container.decode([StressSignal].self, forKey: .stressSignals) {
            stressSignals = ss
        } else {
            stressSignals = try? decoder.container(keyedBy: FallbackCodingKeys.self).decode([StressSignal].self, forKey: .stressSignals)
        }

        suggestions = try? container.decode([WeeklySuggestion].self, forKey: .suggestions)
        aggregates = try? container.decode(WeeklyAggregates.self, forKey: .aggregates)
        comparison = try? container.decode(WeekComparison.self, forKey: .comparison)

        if let hg = try? container.decode(HealthGoalSummary.self, forKey: .healthGoals) {
            healthGoals = hg
        } else {
            healthGoals = try? decoder.container(keyedBy: FallbackCodingKeys.self).decode(HealthGoalSummary.self, forKey: .healthGoals)
        }

        if let wh = try? container.decode(WeekHighlights.self, forKey: .weekHighlights) {
            weekHighlights = wh
        } else {
            weekHighlights = try? decoder.container(keyedBy: FallbackCodingKeys.self).decode(WeekHighlights.self, forKey: .weekHighlights)
        }
    }

    // Fallback keys for camelCase (if backend sends camelCase)
    private enum FallbackCodingKeys: String, CodingKey {
        case weekStart, weekEnd, overallTone, weeklyOverview, timeBuckets
        case energyAlignment, stressSignals, suggestions, aggregates
        case comparison, healthGoals, weekHighlights
    }

    // Computed properties
    var weekStartDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: weekStart)
    }

    var weekEndDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: weekEnd)
    }

    var weekLabel: String {
        guard let start = weekStartDate, let end = weekEndDate else {
            return "Week of \(weekStart)"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    var toneColor: Color {
        switch overallTone.lowercased() {
        case "calm": return Color(hex: "10B981") // Green
        case "balanced": return Color(hex: "3B82F6") // Blue
        case "overloaded": return Color(hex: "F59E0B") // Orange
        case "draining": return Color(hex: "EF4444") // Red
        default: return Color(hex: "6B7280") // Gray
        }
    }

    var toneEmoji: String {
        switch overallTone.lowercased() {
        case "calm": return "🌿"
        case "balanced": return "⚖️"
        case "overloaded": return "📊"
        case "draining": return "🔋"
        default: return "📅"
        }
    }
}

// MARK: - Time Bucket

struct TimeBucket: Codable, Identifiable {
    let category: String
    let hours: Double
    let label: String

    var id: String { category }

    var icon: String {
        switch category.lowercased() {
        case "meetings": return "person.2.fill"
        case "focus": return "brain.head.profile"
        case "personal": return "heart.fill"
        case "health": return "figure.walk"
        case "sleep": return "moon.zzz.fill"
        default: return "clock.fill"
        }
    }

    var color: Color {
        switch category.lowercased() {
        case "meetings": return Color(hex: "8B5CF6") // Purple
        case "focus": return Color(hex: "3B82F6") // Blue
        case "personal": return Color(hex: "EC4899") // Pink
        case "health": return Color(hex: "10B981") // Green
        case "sleep": return Color(hex: "6366F1") // Indigo
        default: return Color(hex: "6B7280") // Gray
        }
    }

    var formattedHours: String {
        if hours < 1 {
            return "\(Int(hours * 60))m"
        } else if hours == hours.rounded() {
            return "\(Int(hours))h"
        } else {
            let wholeHours = Int(hours)
            let minutes = Int((hours - Double(wholeHours)) * 60)
            return minutes > 0 ? "\(wholeHours)h \(minutes)m" : "\(wholeHours)h"
        }
    }
}

// MARK: - Energy Alignment

struct EnergyAlignment: Codable {
    let label: String // "Well-aligned", "Partially aligned", "Misaligned"
    let summary: String
    let evidence: [String]

    var color: Color {
        switch label.lowercased() {
        case "well-aligned", "aligned": return Color(hex: "10B981") // Green
        case "partially aligned": return Color(hex: "F59E0B") // Orange
        case "misaligned": return Color(hex: "EF4444") // Red
        default: return Color(hex: "6B7280") // Gray
        }
    }

    var icon: String {
        switch label.lowercased() {
        case "well-aligned", "aligned": return "checkmark.circle.fill"
        case "partially aligned": return "exclamationmark.circle.fill"
        case "misaligned": return "xmark.circle.fill"
        default: return "circle.fill"
        }
    }
}

// MARK: - Stress Signal

struct StressSignal: Codable, Identifiable {
    let title: String
    let evidence: String

    var id: String { title }
}

// MARK: - Weekly Suggestion

struct WeeklySuggestion: Codable, Identifiable {
    let title: String
    let why: String
    let action: String

    var id: String { title }
}

// MARK: - Weekly Aggregates (Raw Data)

struct WeeklyAggregates: Codable {
    let totalMeetings: Int
    let totalMeetingMinutes: Int
    let totalFocusMinutes: Int
    let averageSleepHours: Double?
    let averageSteps: Int?
    let dayBreakdowns: [DayBreakdown]?

    enum CodingKeys: String, CodingKey {
        case totalMeetings = "total_meetings"
        case totalMeetingMinutes = "total_meeting_minutes"
        case totalFocusMinutes = "total_focus_minutes"
        case averageSleepHours = "average_sleep_hours"
        case averageSteps = "average_steps"
        case dayBreakdowns = "day_breakdowns"
    }

    // Custom decoder to handle both snake_case and camelCase
    init(from decoder: Decoder) throws {
        // Try snake_case keys first
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let tm = try? container.decode(Int.self, forKey: .totalMeetings) {
            totalMeetings = tm
            totalMeetingMinutes = (try? container.decode(Int.self, forKey: .totalMeetingMinutes)) ?? 0
            totalFocusMinutes = (try? container.decode(Int.self, forKey: .totalFocusMinutes)) ?? 0
            averageSleepHours = try? container.decode(Double.self, forKey: .averageSleepHours)
            averageSteps = try? container.decode(Int.self, forKey: .averageSteps)
            dayBreakdowns = try? container.decode([DayBreakdown].self, forKey: .dayBreakdowns)
        } else {
            // Fallback to camelCase keys
            let container = try decoder.container(keyedBy: FallbackCodingKeys.self)
            totalMeetings = (try? container.decode(Int.self, forKey: .totalMeetings)) ?? 0
            totalMeetingMinutes = (try? container.decode(Int.self, forKey: .totalMeetingMinutes)) ?? 0
            totalFocusMinutes = (try? container.decode(Int.self, forKey: .totalFocusMinutes)) ?? 0
            averageSleepHours = try? container.decode(Double.self, forKey: .averageSleepHours)
            averageSteps = try? container.decode(Int.self, forKey: .averageSteps)
            dayBreakdowns = try? container.decode([DayBreakdown].self, forKey: .dayBreakdowns)
        }
    }

    private enum FallbackCodingKeys: String, CodingKey {
        case totalMeetings, totalMeetingMinutes, totalFocusMinutes
        case averageSleepHours, averageSteps, dayBreakdowns
    }

    var formattedMeetingHours: String {
        let hours = Double(totalMeetingMinutes) / 60.0
        if hours < 1 {
            return "\(totalMeetingMinutes)m"
        }
        return String(format: "%.1fh", hours)
    }

    var formattedFocusHours: String {
        let hours = Double(totalFocusMinutes) / 60.0
        if hours < 1 {
            return "\(totalFocusMinutes)m"
        }
        return String(format: "%.1fh", hours)
    }

    var formattedSleep: String {
        guard let sleep = averageSleepHours else { return "—" }
        return String(format: "%.1fh", sleep)
    }

    var formattedSteps: String {
        guard let steps = averageSteps else { return "—" }
        if steps >= 1000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }
        return "\(steps)"
    }
}

// MARK: - Day Breakdown

struct DayBreakdown: Codable, Identifiable {
    let day: String
    let meetings: Int
    let meetingMinutes: Int
    let focusMinutes: Int
    let sleepHours: Double?
    let steps: Int?

    var id: String { day }

    enum CodingKeys: String, CodingKey {
        case day, meetings
        case meetingMinutes = "meeting_minutes"
        case focusMinutes = "focus_minutes"
        case sleepHours = "sleep_hours"
        case steps
    }

    init(from decoder: Decoder) throws {
        // Try snake_case first
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let d = try? container.decode(String.self, forKey: .day) {
            day = d
            meetings = (try? container.decode(Int.self, forKey: .meetings)) ?? 0
            meetingMinutes = (try? container.decode(Int.self, forKey: .meetingMinutes)) ?? 0
            focusMinutes = (try? container.decode(Int.self, forKey: .focusMinutes)) ?? 0
            sleepHours = try? container.decode(Double.self, forKey: .sleepHours)
            steps = try? container.decode(Int.self, forKey: .steps)
        } else {
            // Fallback to camelCase
            let container = try decoder.container(keyedBy: FallbackCodingKeys.self)
            day = try container.decode(String.self, forKey: .day)
            meetings = (try? container.decode(Int.self, forKey: .meetings)) ?? 0
            meetingMinutes = (try? container.decode(Int.self, forKey: .meetingMinutes)) ?? 0
            focusMinutes = (try? container.decode(Int.self, forKey: .focusMinutes)) ?? 0
            sleepHours = try? container.decode(Double.self, forKey: .sleepHours)
            steps = try? container.decode(Int.self, forKey: .steps)
        }
    }

    private enum FallbackCodingKeys: String, CodingKey {
        case day, meetings, meetingMinutes, focusMinutes, sleepHours, steps
    }

    var dayDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: day)
    }

    var shortDayName: String {
        guard let date = dayDate else { return day }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

/// MARK: - Week Comparison (Report Card)

struct WeekComparison: Codable {
    let hasPreviousWeek: Bool

    // Meeting hours
    let meetingHoursThisWeek: Int
    let meetingHoursPrevWeek: Int
    let meetingHoursDelta: Int
    let meetingTrend: String // "up", "down", "same"

    // Focus hours
    let focusHoursThisWeek: Int
    let focusHoursPrevWeek: Int
    let focusHoursDelta: Int
    let focusTrend: String

    // Total events
    let eventsThisWeek: Int
    let eventsPrevWeek: Int
    let eventsDelta: Int
    let eventsTrend: String

    // Free time hours (backend uses freeHours*)
    let freeHoursThisWeek: Int
    let freeHoursPrevWeek: Int
    let freeHoursDelta: Int
    let freeTimeTrend: String

    // Balance score (0-100) with transparent drivers
    let balanceScore: Int
    let prevBalanceScore: Int
    let balanceTrend: String
    let scoreBreakdown: ScoreBreakdown?  // Detailed breakdown with drivers

    enum CodingKeys: String, CodingKey {
        case hasPreviousWeek = "has_previous_week"
        case meetingHoursThisWeek = "meeting_hours_this_week"
        case meetingHoursPrevWeek = "meeting_hours_prev_week"
        case meetingHoursDelta = "meeting_hours_delta"
        case meetingTrend = "meeting_trend"
        case focusHoursThisWeek = "focus_hours_this_week"
        case focusHoursPrevWeek = "focus_hours_prev_week"
        case focusHoursDelta = "focus_hours_delta"
        case focusTrend = "focus_trend"
        case eventsThisWeek = "events_this_week"
        case eventsPrevWeek = "events_prev_week"
        case eventsDelta = "events_delta"
        case eventsTrend = "events_trend"
        case freeHoursThisWeek = "free_hours_this_week"
        case freeHoursPrevWeek = "free_hours_prev_week"
        case freeHoursDelta = "free_hours_delta"
        case freeTimeTrend = "free_time_trend"
        case balanceScore = "balance_score"
        case prevBalanceScore = "prev_balance_score"
        case balanceTrend = "balance_trend"
        case scoreBreakdown = "score_breakdown"
    }

    // Custom decoder that handles both snake_case and camelCase with defaults
    init(from decoder: Decoder) throws {
        // Try snake_case container first
        let snakeContainer = try? decoder.container(keyedBy: CodingKeys.self)
        let camelContainer = try? decoder.container(keyedBy: FallbackCodingKeys.self)

        // hasPreviousWeek
        if let c = snakeContainer, let v = try? c.decode(Bool.self, forKey: .hasPreviousWeek) {
            hasPreviousWeek = v
        } else if let c = camelContainer, let v = try? c.decode(Bool.self, forKey: .hasPreviousWeek) {
            hasPreviousWeek = v
        } else {
            hasPreviousWeek = false
        }

        // Meeting hours
        meetingHoursThisWeek = (try? snakeContainer?.decode(Int.self, forKey: .meetingHoursThisWeek))
            ?? (try? camelContainer?.decode(Int.self, forKey: .meetingHoursThisWeek)) ?? 0
        meetingHoursPrevWeek = (try? snakeContainer?.decode(Int.self, forKey: .meetingHoursPrevWeek))
            ?? (try? camelContainer?.decode(Int.self, forKey: .meetingHoursPrevWeek)) ?? 0
        meetingHoursDelta = (try? snakeContainer?.decode(Int.self, forKey: .meetingHoursDelta))
            ?? (try? camelContainer?.decode(Int.self, forKey: .meetingHoursDelta)) ?? 0
        meetingTrend = (try? snakeContainer?.decode(String.self, forKey: .meetingTrend))
            ?? (try? camelContainer?.decode(String.self, forKey: .meetingTrend)) ?? "same"

        // Focus hours
        focusHoursThisWeek = (try? snakeContainer?.decode(Int.self, forKey: .focusHoursThisWeek))
            ?? (try? camelContainer?.decode(Int.self, forKey: .focusHoursThisWeek)) ?? 0
        focusHoursPrevWeek = (try? snakeContainer?.decode(Int.self, forKey: .focusHoursPrevWeek))
            ?? (try? camelContainer?.decode(Int.self, forKey: .focusHoursPrevWeek)) ?? 0
        focusHoursDelta = (try? snakeContainer?.decode(Int.self, forKey: .focusHoursDelta))
            ?? (try? camelContainer?.decode(Int.self, forKey: .focusHoursDelta)) ?? 0
        focusTrend = (try? snakeContainer?.decode(String.self, forKey: .focusTrend))
            ?? (try? camelContainer?.decode(String.self, forKey: .focusTrend)) ?? "same"

        // Events
        eventsThisWeek = (try? snakeContainer?.decode(Int.self, forKey: .eventsThisWeek))
            ?? (try? camelContainer?.decode(Int.self, forKey: .eventsThisWeek)) ?? 0
        eventsPrevWeek = (try? snakeContainer?.decode(Int.self, forKey: .eventsPrevWeek))
            ?? (try? camelContainer?.decode(Int.self, forKey: .eventsPrevWeek)) ?? 0
        eventsDelta = (try? snakeContainer?.decode(Int.self, forKey: .eventsDelta))
            ?? (try? camelContainer?.decode(Int.self, forKey: .eventsDelta)) ?? 0
        eventsTrend = (try? snakeContainer?.decode(String.self, forKey: .eventsTrend))
            ?? (try? camelContainer?.decode(String.self, forKey: .eventsTrend)) ?? "same"

        // Free time
        freeHoursThisWeek = (try? snakeContainer?.decode(Int.self, forKey: .freeHoursThisWeek))
            ?? (try? camelContainer?.decode(Int.self, forKey: .freeHoursThisWeek)) ?? 0
        freeHoursPrevWeek = (try? snakeContainer?.decode(Int.self, forKey: .freeHoursPrevWeek))
            ?? (try? camelContainer?.decode(Int.self, forKey: .freeHoursPrevWeek)) ?? 0
        freeHoursDelta = (try? snakeContainer?.decode(Int.self, forKey: .freeHoursDelta))
            ?? (try? camelContainer?.decode(Int.self, forKey: .freeHoursDelta)) ?? 0
        freeTimeTrend = (try? snakeContainer?.decode(String.self, forKey: .freeTimeTrend))
            ?? (try? camelContainer?.decode(String.self, forKey: .freeTimeTrend)) ?? "same"

        // Balance score - the key field!
        balanceScore = (try? snakeContainer?.decode(Int.self, forKey: .balanceScore))
            ?? (try? camelContainer?.decode(Int.self, forKey: .balanceScore)) ?? 50
        prevBalanceScore = (try? snakeContainer?.decode(Int.self, forKey: .prevBalanceScore))
            ?? (try? camelContainer?.decode(Int.self, forKey: .prevBalanceScore)) ?? 50
        balanceTrend = (try? snakeContainer?.decode(String.self, forKey: .balanceTrend))
            ?? (try? camelContainer?.decode(String.self, forKey: .balanceTrend)) ?? "same"

        // Score breakdown with drivers
        scoreBreakdown = (try? snakeContainer?.decode(ScoreBreakdown.self, forKey: .scoreBreakdown))
            ?? (try? camelContainer?.decode(ScoreBreakdown.self, forKey: .scoreBreakdown))
    }

    private enum FallbackCodingKeys: String, CodingKey {
        case hasPreviousWeek, meetingHoursThisWeek, meetingHoursPrevWeek, meetingHoursDelta, meetingTrend
        case focusHoursThisWeek, focusHoursPrevWeek, focusHoursDelta, focusTrend
        case eventsThisWeek, eventsPrevWeek, eventsDelta, eventsTrend
        case freeHoursThisWeek, freeHoursPrevWeek, freeHoursDelta, freeTimeTrend
        case balanceScore, prevBalanceScore, balanceTrend, scoreBreakdown
    }

    // Computed property for delta
    var balanceScoreDelta: Int {
        balanceScore - prevBalanceScore
    }

    // Helper computed properties
    var balanceScoreColor: Color {
        switch balanceScore {
        case 70...100: return Color(hex: "10B981") // Green - good balance
        case 40...69: return Color(hex: "F59E0B") // Orange - needs attention
        default: return Color(hex: "EF4444") // Red - poor balance
        }
    }

    var balanceLabel: String {
        switch balanceScore {
        case 80...100: return "Excellent"
        case 60...79: return "Good"
        case 40...59: return "Fair"
        case 20...39: return "Needs Work"
        default: return "Critical"
        }
    }

    func trendIcon(for trend: String) -> String {
        switch trend {
        case "up": return "arrow.up"
        case "down": return "arrow.down"
        default: return "minus"
        }
    }

    func trendColor(for trend: String, higherIsBetter: Bool) -> Color {
        switch trend {
        case "up": return higherIsBetter ? Color(hex: "10B981") : Color(hex: "EF4444")
        case "down": return higherIsBetter ? Color(hex: "EF4444") : Color(hex: "10B981")
        default: return Color(hex: "6B7280")
        }
    }
}

// MARK: - Score Breakdown (Transparent Score Drivers)

/// Detailed breakdown of the Balance Score showing what factors contributed to the score
struct ScoreBreakdown: Codable {
    let score: Int
    let drivers: [ScoreDriver]
    let summary: String
    let levers: [ScoreLever]?  // Actionable ways to improve the score

    /// Top positive drivers (sorted by delta, descending)
    var topPositiveDrivers: [ScoreDriver] {
        drivers.filter { $0.delta > 0 }.sorted { $0.delta > $1.delta }
    }

    /// Negative drivers (sorted by delta, ascending - most negative first)
    var negativeDrivers: [ScoreDriver] {
        drivers.filter { $0.delta < 0 }.sorted { $0.delta < $1.delta }
    }

    /// All non-zero drivers for display
    var significantDrivers: [ScoreDriver] {
        drivers.filter { $0.delta != 0 }.sorted { abs($0.delta) > abs($1.delta) }
    }

    /// Whether there are actionable improvements available
    var hasLevers: Bool {
        levers != nil && !(levers!.isEmpty)
    }
}

/// Actionable lever for improving the balance score
struct ScoreLever: Codable, Identifiable {
    let id: String            // "reduce_meetings", "protect_evening", etc.
    let action: String        // "Decline one meeting this week"
    let description: String   // "Reduce meeting load by ~2 hours"
    let potentialGain: Int    // +10 (how many points this could add)
    let icon: String          // SF Symbol
    let deepLink: String      // Deep link to take action

    enum CodingKeys: String, CodingKey {
        case id
        case action
        case description
        case potentialGain = "potential_gain"
        case icon
        case deepLink = "deep_link"
    }

    /// SF Symbol for this lever
    var sfSymbol: String {
        switch icon {
        case "calendar.badge.minus": return "calendar.badge.minus"
        case "moon.stars.fill": return "moon.stars.fill"
        case "clock.badge.checkmark": return "clock.badge.checkmark"
        case "brain.head.profile": return "brain.head.profile"
        case "leaf.fill": return "leaf.fill"
        default: return "arrow.up.circle.fill"
        }
    }

    /// Formatted potential gain string
    var formattedGain: String {
        "+\(potentialGain) pts"
    }
}

/// Individual factor that contributed to the Balance Score
struct ScoreDriver: Codable, Identifiable {
    let category: String   // "meetings", "focus", "free_time", "consistency", "recovery"
    let label: String      // Human-readable: "Light meeting load"
    let detail: String     // Specific data: "8h total"
    let delta: Int         // Point contribution: +15, -10, etc.
    let icon: String       // SF Symbol name

    var id: String { category }

    /// SF Symbol for this driver
    var sfSymbol: String {
        switch icon {
        case "calendar": return "calendar"
        case "person.2.fill": return "person.2.fill"
        case "brain.head.profile": return "brain.head.profile"
        case "clock.fill": return "clock.fill"
        case "sun.max.fill": return "sun.max.fill"
        case "moon.stars.fill": return "moon.stars.fill"
        case "arrow.triangle.2.circlepath": return "arrow.triangle.2.circlepath"
        case "exclamationmark.triangle.fill": return "exclamationmark.triangle.fill"
        case "checkmark.circle.fill": return "checkmark.circle.fill"
        default: return "chart.bar.fill"
        }
    }

    /// Color based on whether this driver is positive or negative
    var color: Color {
        if delta > 0 {
            return Color(hex: "10B981") // Green for positive
        } else if delta < 0 {
            return Color(hex: "EF4444") // Red for negative
        } else {
            return Color(hex: "6B7280") // Gray for neutral
        }
    }

    /// Formatted delta string with sign
    var formattedDelta: String {
        if delta > 0 {
            return "+\(delta)"
        } else {
            return "\(delta)"
        }
    }

    /// Category color for visual distinction
    var categoryColor: Color {
        switch category.lowercased() {
        case "meetings": return Color(hex: "8B5CF6") // Purple
        case "focus": return Color(hex: "3B82F6") // Blue
        case "free_time": return Color(hex: "10B981") // Green
        case "consistency": return Color(hex: "F59E0B") // Orange
        case "recovery": return Color(hex: "EC4899") // Pink
        default: return Color(hex: "6B7280") // Gray
        }
    }
}

// MARK: - Health Goal Summary

struct HealthGoalSummary: Codable {
    let hasGoals: Bool
    let hasData: Bool
    let daysTracked: Int
    let overallPercentage: Int // 0-100
    let sleepGoal: GoalProgress?
    let stepsGoal: GoalProgress?
    let activeMinutesGoal: GoalProgress?

    enum CodingKeys: String, CodingKey {
        case hasGoals = "has_goals"
        case hasData = "has_data"
        case daysTracked = "days_tracked"
        case overallPercentage = "overall_percentage"
        case sleepGoal = "sleep_goal"
        case stepsGoal = "steps_goal"
        case activeMinutesGoal = "active_minutes_goal"
    }

    init(from decoder: Decoder) throws {
        // Try snake_case first
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let hg = try? container.decode(Bool.self, forKey: .hasGoals) {
            hasGoals = hg
            hasData = (try? container.decode(Bool.self, forKey: .hasData)) ?? false
            daysTracked = (try? container.decode(Int.self, forKey: .daysTracked)) ?? 0
            overallPercentage = (try? container.decode(Int.self, forKey: .overallPercentage)) ?? 0
            sleepGoal = try? container.decode(GoalProgress.self, forKey: .sleepGoal)
            stepsGoal = try? container.decode(GoalProgress.self, forKey: .stepsGoal)
            activeMinutesGoal = try? container.decode(GoalProgress.self, forKey: .activeMinutesGoal)
        } else {
            // Fallback to camelCase
            let container = try decoder.container(keyedBy: FallbackCodingKeys.self)
            hasGoals = (try? container.decode(Bool.self, forKey: .hasGoals)) ?? false
            hasData = (try? container.decode(Bool.self, forKey: .hasData)) ?? false
            daysTracked = (try? container.decode(Int.self, forKey: .daysTracked)) ?? 0
            overallPercentage = (try? container.decode(Int.self, forKey: .overallPercentage)) ?? 0
            sleepGoal = try? container.decode(GoalProgress.self, forKey: .sleepGoal)
            stepsGoal = try? container.decode(GoalProgress.self, forKey: .stepsGoal)
            activeMinutesGoal = try? container.decode(GoalProgress.self, forKey: .activeMinutesGoal)
        }
    }

    private enum FallbackCodingKeys: String, CodingKey {
        case hasGoals, hasData, daysTracked, overallPercentage
        case sleepGoal, stepsGoal, activeMinutesGoal
    }

    var overallProgressColor: Color {
        switch overallPercentage {
        case 80...100: return Color(hex: "10B981") // Green - excellent
        case 60...79: return Color(hex: "3B82F6") // Blue - good
        case 40...59: return Color(hex: "F59E0B") // Orange - fair
        default: return Color(hex: "EF4444") // Red - needs work
        }
    }

    var overallLabel: String {
        switch overallPercentage {
        case 90...100: return "Crushing it!"
        case 75...89: return "Great week"
        case 50...74: return "Making progress"
        case 25...49: return "Room to grow"
        default: return "Let's improve"
        }
    }
}

struct GoalProgress: Codable, Identifiable {
    let name: String
    let actual: String
    let target: String
    let percentage: Int // 0-100+
    let daysMet: Int
    let totalDays: Int

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, actual, target, percentage
        case daysMet = "days_met"
        case totalDays = "total_days"
    }

    init(from decoder: Decoder) throws {
        // Try snake_case first
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let n = try? container.decode(String.self, forKey: .name) {
            name = n
            actual = (try? container.decode(String.self, forKey: .actual)) ?? ""
            target = (try? container.decode(String.self, forKey: .target)) ?? ""
            percentage = (try? container.decode(Int.self, forKey: .percentage)) ?? 0
            daysMet = (try? container.decode(Int.self, forKey: .daysMet)) ?? 0
            totalDays = (try? container.decode(Int.self, forKey: .totalDays)) ?? 0
        } else {
            // Fallback to camelCase
            let container = try decoder.container(keyedBy: FallbackCodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            actual = (try? container.decode(String.self, forKey: .actual)) ?? ""
            target = (try? container.decode(String.self, forKey: .target)) ?? ""
            percentage = (try? container.decode(Int.self, forKey: .percentage)) ?? 0
            daysMet = (try? container.decode(Int.self, forKey: .daysMet)) ?? 0
            totalDays = (try? container.decode(Int.self, forKey: .totalDays)) ?? 0
        }
    }

    private enum FallbackCodingKeys: String, CodingKey {
        case name, actual, target, percentage, daysMet, totalDays
    }

    var progressColor: Color {
        switch percentage {
        case 90...Int.max: return Color(hex: "10B981") // Green - exceeded
        case 70...89: return Color(hex: "3B82F6") // Blue - on track
        case 50...69: return Color(hex: "F59E0B") // Orange - partial
        default: return Color(hex: "EF4444") // Red - needs work
        }
    }

    var icon: String {
        switch name.lowercased() {
        case "sleep": return "moon.zzz.fill"
        case "steps": return "figure.walk"
        case "active minutes": return "flame.fill"
        default: return "heart.fill"
        }
    }

    var achievementBadge: String? {
        if percentage >= 100 { return "Goal Achieved" }
        if daysMet == totalDays { return "Perfect Week" }
        return nil
    }
}

// MARK: - Week Highlights

struct WeekHighlights: Codable {
    let longestMeeting: WeekHighlightDetail?
    let earliestMeeting: WeekHighlightDetail?
    let latestMeeting: WeekHighlightDetail?
    let busiestDay: WeekHighlightDetail?      // Day with most meeting hours
    let keyCollaborator: WeekHighlightDetail? // Person met with most often
    let marathonDay: WeekHighlightDetail?     // Day with most back-to-back meetings
    let travel: [WeekHighlightDetail]?
    let totalCollaborators: Int?

    enum CodingKeys: String, CodingKey {
        case longestMeeting = "longest_meeting"
        case earliestMeeting = "earliest_meeting"
        case latestMeeting = "latest_meeting"
        case busiestDay = "busiest_day"
        case keyCollaborator = "key_collaborator"
        case marathonDay = "marathon_day"
        case travel
        case totalCollaborators = "total_collaborators"
    }

    init(from decoder: Decoder) throws {
        // Try snake_case first
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            longestMeeting = try? container.decode(WeekHighlightDetail.self, forKey: .longestMeeting)
            earliestMeeting = try? container.decode(WeekHighlightDetail.self, forKey: .earliestMeeting)
            latestMeeting = try? container.decode(WeekHighlightDetail.self, forKey: .latestMeeting)
            busiestDay = try? container.decode(WeekHighlightDetail.self, forKey: .busiestDay)
            keyCollaborator = try? container.decode(WeekHighlightDetail.self, forKey: .keyCollaborator)
            marathonDay = try? container.decode(WeekHighlightDetail.self, forKey: .marathonDay)
            travel = try? container.decode([WeekHighlightDetail].self, forKey: .travel)
            totalCollaborators = try? container.decode(Int.self, forKey: .totalCollaborators)
        } else {
            // Fallback to camelCase
            let container = try decoder.container(keyedBy: FallbackCodingKeys.self)
            longestMeeting = try? container.decode(WeekHighlightDetail.self, forKey: .longestMeeting)
            earliestMeeting = try? container.decode(WeekHighlightDetail.self, forKey: .earliestMeeting)
            latestMeeting = try? container.decode(WeekHighlightDetail.self, forKey: .latestMeeting)
            busiestDay = try? container.decode(WeekHighlightDetail.self, forKey: .busiestDay)
            keyCollaborator = try? container.decode(WeekHighlightDetail.self, forKey: .keyCollaborator)
            marathonDay = try? container.decode(WeekHighlightDetail.self, forKey: .marathonDay)
            travel = try? container.decode([WeekHighlightDetail].self, forKey: .travel)
            totalCollaborators = try? container.decode(Int.self, forKey: .totalCollaborators)
        }
    }

    private enum FallbackCodingKeys: String, CodingKey {
        case longestMeeting, earliestMeeting, latestMeeting
        case busiestDay, keyCollaborator, marathonDay
        case travel, totalCollaborators
    }

    var hasAnyHighlights: Bool {
        longestMeeting != nil || earliestMeeting != nil || latestMeeting != nil ||
        busiestDay != nil || keyCollaborator != nil || marathonDay != nil ||
        (travel != nil && !travel!.isEmpty)
    }
}

struct WeekHighlightDetail: Codable, Identifiable {
    let label: String
    let title: String
    let detail: String
    let icon: String

    var id: String { label + title }

    var sfSymbol: String {
        // Map backend icons to SF Symbols
        switch icon {
        case "clock.fill": return "clock.fill"
        case "sunrise.fill": return "sunrise.fill"
        case "moon.fill": return "moon.fill"
        case "sun.max.fill": return "sun.max.fill"
        case "moon.stars.fill": return "moon.stars.fill"
        case "flame.fill": return "flame.fill"
        case "person.2.fill": return "person.2.fill"
        case "figure.run": return "figure.run"
        case "airplane": return "airplane"
        case "building.2.fill": return "building.2.fill"
        default: return "star.fill"
        }
    }

    var iconColor: Color {
        switch label.lowercased() {
        case "busiest day": return Color(hex: "EF4444") // Red - intense
        case "key collaborator": return Color(hex: "3B82F6") // Blue - collaborative
        case "marathon day": return Color(hex: "F97316") // Orange - endurance
        case "longest meeting": return Color(hex: "8B5CF6") // Purple
        case "early bird": return Color(hex: "F59E0B") // Amber
        case "night owl": return Color(hex: "6366F1") // Indigo
        case "flight", "travel": return Color(hex: "0EA5E9") // Sky blue
        default: return Color(hex: "6B7280") // Gray
        }
    }
}

// MARK: - Next Week Forecast (Predictive Intelligence)

/// Forward-looking forecast for next week
/// Philosophy: Clara exists to forecast the next 24-72 hours, not summarize the past.
struct NextWeekForecastResponse: Codable {
    let weekStart: String
    let weekEnd: String
    let headline: String        // "Next week needs attention." or "Manageable week ahead."
    let subheadline: String     // Specific numbers: "4 heavy days with 22h meetings"
    let weekMetrics: ForecastWeekMetrics
    let dailyForecasts: [DayForecast]
    let riskSignals: [ForecastRiskSignal]
    let interventions: [ForecastIntervention]

    enum CodingKeys: String, CodingKey {
        case weekStart = "week_start"
        case weekEnd = "week_end"
        case headline, subheadline
        case weekMetrics = "week_metrics"
        case dailyForecasts = "daily_forecasts"
        case riskSignals = "risk_signals"
        case interventions
    }

    // Computed properties
    var weekStartDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: weekStart)
    }

    var weekLabel: String {
        guard let start = weekStartDate else { return "Next Week" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        return "\(formatter.string(from: start)) - \(formatter.string(from: endDate))"
    }

    var hasRisks: Bool {
        !riskSignals.isEmpty
    }

    var topRisk: ForecastRiskSignal? {
        riskSignals.first
    }
}

/// Week-level metrics for next week forecast
struct ForecastWeekMetrics: Codable {
    let totalMeetings: Int
    let totalMeetingHours: Double
    let totalFocusHours: Double
    let heavyDays: Int
    let openDays: Int
    let lateEvenings: Int
    let backToBackTotal: Int
    let weekdayMeetings: Int
    let weekendMeetings: Int

    enum CodingKeys: String, CodingKey {
        case totalMeetings = "total_meetings"
        case totalMeetingHours = "total_meeting_hours"
        case totalFocusHours = "total_focus_hours"
        case heavyDays = "heavy_days"
        case openDays = "open_days"
        case lateEvenings = "late_evenings"
        case backToBackTotal = "back_to_back_total"
        case weekdayMeetings = "weekday_meetings"
        case weekendMeetings = "weekend_meetings"
    }

    var formattedMeetingHours: String {
        if totalMeetingHours < 1 {
            return "\(Int(totalMeetingHours * 60))m"
        }
        return String(format: "%.0fh", totalMeetingHours)
    }

    var formattedFocusHours: String {
        if totalFocusHours < 1 {
            return "\(Int(totalFocusHours * 60))m"
        }
        return String(format: "%.0fh", totalFocusHours)
    }

    var densityLabel: String {
        if heavyDays >= 4 {
            return "Very Heavy"
        } else if heavyDays >= 2 {
            return "Heavy"
        } else if totalMeetings >= 15 {
            return "Full"
        } else if openDays >= 3 {
            return "Light"
        } else {
            return "Balanced"
        }
    }

    var densityColor: Color {
        switch densityLabel {
        case "Very Heavy": return Color(hex: "EF4444") // Red
        case "Heavy": return Color(hex: "F97316") // Orange
        case "Full": return Color(hex: "F59E0B") // Amber
        case "Light": return Color(hex: "10B981") // Green
        default: return Color(hex: "3B82F6") // Blue
        }
    }
}

/// Day-by-day forecast for next week
struct DayForecast: Codable, Identifiable {
    let date: String
    let dayOfWeek: String
    let dayLabel: String         // "MON", "TUE", etc.
    let meetingCount: Int
    let meetingHours: Double
    let focusHours: Double
    let backToBackCount: Int
    let firstMeetingTime: String?
    let lastMeetingTime: String?
    let hasLateEvening: Bool
    let intensity: String        // "open", "light", "moderate", "full", "heavy"
    let intensityLabel: String

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case dayOfWeek = "day_of_week"
        case dayLabel = "day_label"
        case meetingCount = "meeting_count"
        case meetingHours = "meeting_hours"
        case focusHours = "focus_hours"
        case backToBackCount = "back_to_back_count"
        case firstMeetingTime = "first_meeting_time"
        case lastMeetingTime = "last_meeting_time"
        case hasLateEvening = "has_late_evening"
        case intensity
        case intensityLabel = "intensity_label"
    }

    var dayDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    var shortDayName: String {
        dayLabel
    }

    var intensityColor: Color {
        switch intensity {
        case "heavy": return Color(hex: "EF4444") // Red
        case "full": return Color(hex: "F97316") // Orange
        case "moderate": return Color(hex: "F59E0B") // Amber
        case "light": return Color(hex: "3B82F6") // Blue
        case "open": return Color(hex: "10B981") // Green
        default: return Color(hex: "6B7280") // Gray
        }
    }

    var intensityIcon: String {
        switch intensity {
        case "heavy": return "flame.fill"
        case "full": return "calendar.badge.exclamationmark"
        case "moderate": return "calendar"
        case "light": return "sun.max.fill"
        case "open": return "leaf.fill"
        default: return "circle.fill"
        }
    }

    var formattedTimeRange: String? {
        guard let first = firstMeetingTime, let last = lastMeetingTime else { return nil }
        return "\(first) - \(last)"
    }
}

/// Risk signal for upcoming week
struct ForecastRiskSignal: Codable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let severity: String  // "high", "medium", "low"

    var sfSymbol: String {
        switch icon {
        case "exclamationmark.triangle.fill": return "exclamationmark.triangle.fill"
        case "battery.25": return "battery.25"
        case "lungs.fill": return "lungs.fill"
        case "moon.stars.fill": return "moon.stars.fill"
        case "moon.fill": return "moon.fill"
        case "arrow.right.arrow.left": return "arrow.right.arrow.left"
        default: return "exclamationmark.circle.fill"
        }
    }

    var severityColor: Color {
        switch severity {
        case "high": return Color(hex: "EF4444") // Red
        case "medium": return Color(hex: "F59E0B") // Amber
        case "low": return Color(hex: "3B82F6") // Blue
        default: return Color(hex: "6B7280") // Gray
        }
    }

    var severityLabel: String {
        switch severity {
        case "high": return "Critical"
        case "medium": return "Warning"
        case "low": return "Note"
        default: return "Info"
        }
    }
}

/// Specific action to take to prevent bad outcomes
struct ForecastIntervention: Codable, Identifiable {
    let id: String
    let action: String       // "Decline one meeting on TUE"
    let detail: String       // "6 meetings scheduled. Identify one that's optional."
    let icon: String
    let deepLink: String     // Deep link for action
    let impact: Int          // Impact score (higher = more important)

    enum CodingKeys: String, CodingKey {
        case id, action, detail, icon
        case deepLink = "deep_link"
        case impact
    }

    var sfSymbol: String {
        switch icon {
        case "calendar.badge.minus": return "calendar.badge.minus"
        case "brain.head.profile": return "brain.head.profile"
        case "moon.stars.fill": return "moon.stars.fill"
        case "clock.badge.checkmark": return "clock.badge.checkmark"
        case "calendar.badge.exclamationmark": return "calendar.badge.exclamationmark"
        default: return "arrow.up.circle.fill"
        }
    }

    var impactLabel: String {
        switch impact {
        case 15...100: return "High Impact"
        case 10...14: return "Medium Impact"
        default: return "Low Impact"
        }
    }

    var impactColor: Color {
        switch impact {
        case 15...100: return Color(hex: "10B981") // Green - high impact
        case 10...14: return Color(hex: "3B82F6") // Blue - medium
        default: return Color(hex: "6B7280") // Gray - low
        }
    }
}
