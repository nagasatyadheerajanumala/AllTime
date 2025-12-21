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
