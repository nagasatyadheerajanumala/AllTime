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
    let timeBuckets: [TimeBucket]
    let energyAlignment: EnergyAlignment?
    let stressSignals: [StressSignal]
    let suggestions: [WeeklySuggestion]
    let aggregates: WeeklyAggregates
    let comparison: WeekComparison? // Week-over-week comparison for report card

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
    let dayBreakdowns: [DayBreakdown]

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

// MARK: - Week Comparison (Report Card)

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

    // Balance score (0-100)
    let balanceScore: Int
    let prevBalanceScore: Int
    let balanceTrend: String

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
