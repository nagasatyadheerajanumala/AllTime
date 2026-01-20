import Foundation
import SwiftUI

// MARK: - Task Suggestion (AI-generated tasks for "Plan Your Day")

struct TaskSuggestion: Codable, Identifiable {
    let id: Int64
    let userId: Int64

    // The suggestion itself
    let suggestedTitle: String
    let suggestedDescription: String?
    let suggestedCategory: String?
    let suggestedTags: String?
    let suggestedTimeSlot: String?
    let suggestedDurationMinutes: Int?
    let suggestedPriority: String?
    let suggestedDate: String?

    // Why we suggested it
    let suggestionType: String
    let suggestionReason: String?
    let confidenceScore: Double?

    // User interaction tracking
    let status: SuggestionStatus
    let shownAt: String?
    let shownCount: Int?

    // If accepted, link to created task
    let createdTaskId: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case suggestedTitle = "suggested_title"
        case suggestedDescription = "suggested_description"
        case suggestedCategory = "suggested_category"
        case suggestedTags = "suggested_tags"
        case suggestedTimeSlot = "suggested_time_slot"
        case suggestedDurationMinutes = "suggested_duration_minutes"
        case suggestedPriority = "suggested_priority"
        case suggestedDate = "suggested_date"
        case suggestionType = "suggestion_type"
        case suggestionReason = "suggestion_reason"
        case confidenceScore = "confidence_score"
        case status
        case shownAt = "shown_at"
        case shownCount = "shown_count"
        case createdTaskId = "created_task_id"
    }

    // MARK: - Computed Properties

    var categoryColor: Color {
        guard let category = suggestedCategory?.lowercased() else {
            return DesignSystem.Colors.primary
        }
        switch category {
        case "fitness", "health", "exercise":
            return DesignSystem.Colors.emerald
        case "work", "career", "professional":
            return DesignSystem.Colors.primary
        case "personal", "self-care":
            return DesignSystem.Colors.violet
        case "social", "family", "friends":
            return DesignSystem.Colors.amber
        case "errands", "chores", "household":
            return DesignSystem.Colors.indigo
        case "learning", "education":
            return Color(hex: "EC4899")
        default:
            return DesignSystem.Colors.primary
        }
    }

    var categoryIcon: String {
        guard let category = suggestedCategory?.lowercased() else {
            return "star.fill"
        }
        switch category {
        case "fitness", "health", "exercise":
            return "figure.run"
        case "work", "career", "professional":
            return "briefcase.fill"
        case "personal", "self-care":
            return "heart.fill"
        case "social", "family", "friends":
            return "person.2.fill"
        case "errands", "chores", "household":
            return "cart.fill"
        case "learning", "education":
            return "book.fill"
        default:
            return "star.fill"
        }
    }

    var formattedDuration: String? {
        guard let mins = suggestedDurationMinutes else { return nil }
        if mins < 60 {
            return "\(mins) min"
        } else {
            let hours = mins / 60
            let remaining = mins % 60
            if remaining == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remaining)m"
        }
    }

    var timeSlotIcon: String {
        guard let slot = suggestedTimeSlot?.uppercased() else { return "clock" }
        switch slot {
        case "MORNING":
            return "sunrise.fill"
        case "AFTERNOON":
            return "sun.max.fill"
        case "EVENING":
            return "sunset.fill"
        case "NIGHT":
            return "moon.fill"
        default:
            return "clock"
        }
    }

    var priorityColor: Color {
        guard let priority = suggestedPriority?.uppercased() else { return .gray }
        switch priority {
        case "HIGH":
            return DesignSystem.Colors.errorRed
        case "MEDIUM":
            return DesignSystem.Colors.amber
        case "LOW":
            return DesignSystem.Colors.emerald
        default:
            return .gray
        }
    }

    var suggestionTypeLabel: String {
        switch suggestionType.lowercased() {
        case "recurring_pattern":
            return "Based on your routine"
        case "health_based":
            return "Good for your health"
        case "similar_users":
            return "Popular with others"
        case "time_based":
            return "Perfect timing"
        case "calendar_gap":
            return "Free time detected"
        default:
            return "Suggested for you"
        }
    }

    var confidencePercentage: Int {
        guard let score = confidenceScore else { return 50 }
        return Int(score * 100)
    }
}

// MARK: - Suggestion Status

enum SuggestionStatus: String, Codable {
    case pending = "PENDING"
    case shown = "SHOWN"
    case accepted = "ACCEPTED"
    case dismissed = "DISMISSED"
    case snoozed = "SNOOZED"
    case expired = "EXPIRED"
}

// MARK: - Task Suggestions Response

struct TaskSuggestionsResponse: Codable {
    let suggestions: [TaskSuggestion]
    let date: String?
    let totalCount: Int?

    enum CodingKeys: String, CodingKey {
        case suggestions
        case date
        case totalCount = "total_count"
    }
}

// MARK: - Accept Suggestion Request

struct AcceptSuggestionRequest: Codable {
    let suggestionId: Int64
    let scheduledDate: String?
    let scheduledTime: String?

    enum CodingKeys: String, CodingKey {
        case suggestionId = "suggestion_id"
        case scheduledDate = "scheduled_date"
        case scheduledTime = "scheduled_time"
    }
}

// MARK: - Accept Suggestion Response

struct AcceptSuggestionResponse: Codable {
    let success: Bool
    let taskId: Int64?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case taskId = "task_id"
        case message
    }
}

// MARK: - Dismiss Suggestion Request

struct DismissSuggestionRequest: Codable {
    let suggestionId: Int64
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case suggestionId = "suggestion_id"
        case reason
    }
}

// MARK: - Suggestion Feedback Request

struct SuggestionFeedbackRequest: Codable {
    let suggestionId: Int64
    let wasHelpful: Bool
    let feedbackText: String?

    enum CodingKeys: String, CodingKey {
        case suggestionId = "suggestion_id"
        case wasHelpful = "was_helpful"
        case feedbackText = "feedback_text"
    }
}
