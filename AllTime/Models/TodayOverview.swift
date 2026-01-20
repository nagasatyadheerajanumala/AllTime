import Foundation
import SwiftUI

// MARK: - Today Overview Response (GET /api/v1/today/overview)
struct TodayOverviewResponse: Codable {
    let date: String
    let generatedAt: String?
    let timezone: String
    let summaryTile: SummaryTileData
    let suggestionsTile: SuggestionsTileData
    let todoTile: TodoTileData
    let cacheTtlSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case date
        case generatedAt = "generated_at"
        case timezone
        case summaryTile = "summary_tile"
        case suggestionsTile = "suggestions_tile"
        case todoTile = "todo_tile"
        case cacheTtlSeconds = "cache_ttl_seconds"
    }
}

// MARK: - Summary Tile Data (Today AI Summary)
struct SummaryTileData: Codable {
    let greeting: String?
    let previewLine: String?
    let mood: String?
    let moodEmoji: String?
    let meetingsCount: Int?
    let meetingsLabel: String?
    let focusTimeAvailable: String?
    let healthScore: Int?
    let healthLabel: String?

    enum CodingKeys: String, CodingKey {
        case greeting
        case previewLine = "preview_line"
        case mood
        case moodEmoji = "mood_emoji"
        case meetingsCount = "meetings_count"
        case meetingsLabel = "meetings_label"
        case focusTimeAvailable = "focus_time_available"
        case healthScore = "health_score"
        case healthLabel = "health_label"
    }
}

// MARK: - Suggestions Tile Data
struct SuggestionsTileData: Codable {
    let previewLine: String?
    let count: Int?
    let topSuggestions: [SuggestionPreviewData]?

    enum CodingKeys: String, CodingKey {
        case previewLine = "preview_line"
        case count
        case topSuggestions = "top_suggestions"
    }
}

// MARK: - Suggestion Preview Data (lightweight)
struct SuggestionPreviewData: Codable, Identifiable {
    let id: String?
    let title: String?
    let timeLabel: String?
    let icon: String?
    let category: String?

    var previewId: String {
        id ?? title ?? UUID().uuidString
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case timeLabel = "time_label"
        case icon
        case category
    }
}

// MARK: - Todo Tile Data
struct TodoTileData: Codable {
    let previewLine: String?
    let pendingCount: Int?
    let overdueCount: Int?
    let completedTodayCount: Int?
    let topTasks: [TaskPreviewData]?

    enum CodingKeys: String, CodingKey {
        case previewLine = "preview_line"
        case pendingCount = "pending_count"
        case overdueCount = "overdue_count"
        case completedTodayCount = "completed_today_count"
        case topTasks = "top_tasks"
    }
}

// MARK: - Task Preview Data (lightweight)
struct TaskPreviewData: Codable, Identifiable {
    let id: Int?
    let title: String?
    let timeLabel: String?
    let priority: String?
    let isOverdue: Bool?

    var taskId: Int {
        id ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case timeLabel = "time_label"
        case priority
        case isOverdue = "is_overdue"
    }
}

// MARK: - Summary Tile Extensions
extension SummaryTileData {
    var moodGradient: LinearGradient {
        switch (mood ?? "").lowercased() {
        case "focus_day":
            return LinearGradient(
                colors: [DesignSystem.Colors.blue, DesignSystem.Colors.blueDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "light_day":
            return LinearGradient(
                colors: [DesignSystem.Colors.emerald, DesignSystem.Colors.emeraldDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "intense_meetings":
            return LinearGradient(
                colors: [DesignSystem.Colors.amber, DesignSystem.Colors.amberDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "rest_day":
            return LinearGradient(
                colors: [DesignSystem.Colors.violet, DesignSystem.Colors.violetDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "balanced":
            return LinearGradient(
                colors: [DesignSystem.Colors.indigo, DesignSystem.Colors.indigoDark],
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

    var moodIcon: String {
        switch (mood ?? "").lowercased() {
        case "focus_day": return "brain.head.profile"
        case "light_day": return "sun.max.fill"
        case "intense_meetings": return "flame.fill"
        case "rest_day": return "leaf.fill"
        case "balanced": return "scale.3d"
        default: return "sparkles"
        }
    }

    var moodLabel: String {
        switch (mood ?? "").lowercased() {
        case "focus_day": return "Focus Day"
        case "light_day": return "Light Day"
        case "intense_meetings": return "Busy Day"
        case "rest_day": return "Rest Day"
        case "balanced": return "Balanced"
        default: return (mood ?? "").capitalized
        }
    }
}

// MARK: - Suggestion Preview Extensions
extension SuggestionPreviewData {
    var categoryColor: Color {
        switch (category ?? "").lowercased() {
        case "focus": return Color(hex: "5856D6")
        case "movement": return DesignSystem.Colors.success
        case "nutrition": return DesignSystem.Colors.warning
        case "break": return Color(hex: "007AFF")
        case "health_insight": return DesignSystem.Colors.emerald
        case "routine": return DesignSystem.Colors.success
        case "warning": return DesignSystem.Colors.warning
        default: return DesignSystem.Colors.primary
        }
    }

    var displayIcon: String {
        if let icon = icon, !icon.isEmpty {
            return icon
        }
        switch (category ?? "").lowercased() {
        case "focus": return "brain.head.profile"
        case "movement": return "figure.walk"
        case "nutrition": return "fork.knife"
        case "break": return "pause.circle.fill"
        case "health_insight": return "heart.fill"
        case "routine": return "calendar.badge.checkmark"
        case "warning": return "exclamationmark.triangle"
        default: return "lightbulb.fill"
        }
    }
}

// MARK: - Task Preview Extensions
extension TaskPreviewData {
    var priorityColor: Color {
        switch (priority ?? "").uppercased() {
        case "URGENT": return DesignSystem.Colors.errorRed
        case "HIGH": return DesignSystem.Colors.amber
        case "MEDIUM": return DesignSystem.Colors.primary
        case "LOW": return DesignSystem.Colors.secondaryText
        default: return DesignSystem.Colors.secondaryText
        }
    }

    var priorityIcon: String {
        switch (priority ?? "").uppercased() {
        case "URGENT": return "exclamationmark.2"
        case "HIGH": return "exclamationmark"
        case "MEDIUM": return "minus"
        case "LOW": return "chevron.down"
        default: return "minus"
        }
    }
}
