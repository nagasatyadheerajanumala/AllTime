import Foundation
import SwiftUI

// MARK: - Time Intelligence Response
/// The core response from the Time Intelligence Engine.
/// This is the decision surface - what the user needs to know to act.
struct TimeIntelligenceResponse: Codable {
    // THE DIRECTIVE - The ONE thing the user needs to do
    let primaryDirective: String?
    let directiveType: String?
    let directiveConfidence: Int?

    // CAPACITY STATUS
    let capacityOverloadPercent: Int
    let capacityStatus: String?
    let capacitySummary: String?

    // DAY QUALITY
    let predictedDayQuality: Int?
    let dayQualityVerdict: String?

    // KEY METRICS
    let metrics: TimeIntelligenceMetrics?

    // WARNINGS
    let warnings: [TimeIntelligenceWarning]?

    // PROTECTED TIME
    let protectedTimeBlock: ProtectedTimeBlock?

    // DECLINE RECOMMENDATIONS
    let declineRecommendations: [DeclineRecommendationDTO]?

    // METADATA
    let date: String?
    let computedAt: String?

    enum CodingKeys: String, CodingKey {
        case primaryDirective = "primaryDirective"
        case directiveType = "directiveType"
        case directiveConfidence = "directiveConfidence"
        case capacityOverloadPercent = "capacityOverloadPercent"
        case capacityStatus = "capacityStatus"
        case capacitySummary = "capacitySummary"
        case predictedDayQuality = "predictedDayQuality"
        case dayQualityVerdict = "dayQualityVerdict"
        case metrics
        case warnings
        case protectedTimeBlock = "protectedTimeBlock"
        case declineRecommendations = "declineRecommendations"
        case date
        case computedAt = "computedAt"
    }

    // MARK: - Computed Properties

    var isOverloaded: Bool {
        capacityOverloadPercent > 80
    }

    var isCritical: Bool {
        capacityOverloadPercent >= 90 || capacityStatus == "critical"
    }

    var hasWarnings: Bool {
        !(warnings?.isEmpty ?? true)
    }

    var criticalWarnings: [TimeIntelligenceWarning] {
        warnings?.filter { $0.severity == "critical" } ?? []
    }

    var hasDeclineRecommendations: Bool {
        !(declineRecommendations?.isEmpty ?? true)
    }

    var strongestDeclineRecommendation: DeclineRecommendationDTO? {
        declineRecommendations?.min(by: { ($0.netScore ?? 0) < ($1.netScore ?? 0) })
    }

    // MARK: - Styling

    var capacityColor: Color {
        switch capacityStatus?.lowercased() ?? "" {
        case "critical": return DesignSystem.Colors.errorRed
        case "overloaded": return Color(hex: "F97316") // Orange
        case "strained": return DesignSystem.Colors.amber
        case "manageable": return DesignSystem.Colors.blue
        case "optimal": return DesignSystem.Colors.emerald
        default: return DesignSystem.Colors.secondaryText
        }
    }

    var capacityIcon: String {
        switch capacityStatus?.lowercased() ?? "" {
        case "critical": return "exclamationmark.octagon.fill"
        case "overloaded": return "exclamationmark.triangle.fill"
        case "strained": return "exclamationmark.circle.fill"
        case "manageable": return "checkmark.circle"
        case "optimal": return "checkmark.seal.fill"
        default: return "circle"
        }
    }

    var directiveIcon: String {
        switch directiveType?.lowercased() ?? "" {
        case "decline_meeting": return "xmark.circle.fill"
        case "protect_time": return "shield.fill"
        case "reschedule": return "calendar.badge.clock"
        case "rest": return "moon.fill"
        case "execute": return "bolt.fill"
        default: return "star.fill"
        }
    }

    var directiveColor: Color {
        switch directiveType?.lowercased() ?? "" {
        case "decline_meeting": return DesignSystem.Colors.errorRed
        case "protect_time": return DesignSystem.Colors.violet
        case "reschedule": return DesignSystem.Colors.amber
        case "rest": return DesignSystem.Colors.blue
        case "execute": return DesignSystem.Colors.emerald
        default: return DesignSystem.Colors.primary
        }
    }

    var dayQualityColor: Color {
        let quality = predictedDayQuality ?? 50
        if quality >= 70 { return DesignSystem.Colors.emerald }
        if quality >= 50 { return DesignSystem.Colors.amber }
        if quality >= 30 { return Color(hex: "F97316") }
        return DesignSystem.Colors.errorRed
    }
}

// MARK: - Time Intelligence Metrics
struct TimeIntelligenceMetrics: Codable {
    let focusLoad: Int?
    let focusLoadReason: String?
    let contextSwitchingCost: Int?
    let meetingDensityRisk: Int?
    let taskFragmentation: Int?
    let recoveryDeficit: Int?
    let energyState: String?
    let consecutiveHighLoadDays: Int?
    let meetingMinutesTotal: Int?
    let meetingCount: Int?
    let usableFocusBlocks: Int?
    let largestFocusBlockMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case focusLoad = "focusLoad"
        case focusLoadReason = "focusLoadReason"
        case contextSwitchingCost = "contextSwitchingCost"
        case meetingDensityRisk = "meetingDensityRisk"
        case taskFragmentation = "taskFragmentation"
        case recoveryDeficit = "recoveryDeficit"
        case energyState = "energyState"
        case consecutiveHighLoadDays = "consecutiveHighLoadDays"
        case meetingMinutesTotal = "meetingMinutesTotal"
        case meetingCount = "meetingCount"
        case usableFocusBlocks = "usableFocusBlocks"
        case largestFocusBlockMinutes = "largestFocusBlockMinutes"
    }

    var hasBurnoutRisk: Bool {
        (consecutiveHighLoadDays ?? 0) >= 3
    }

    var hasRecoveryDeficit: Bool {
        (recoveryDeficit ?? 0) > 30
    }

    var hasCriticalRecoveryDeficit: Bool {
        (recoveryDeficit ?? 0) > 60
    }

    var energyStateIcon: String {
        switch energyState?.lowercased() ?? "" {
        case "peak": return "sun.max.fill"
        case "rising": return "arrow.up.right.circle.fill"
        case "falling": return "arrow.down.right.circle.fill"
        case "trough": return "moon.fill"
        case "recovering": return "arrow.counterclockwise.circle.fill"
        case "winding_down": return "moon.stars.fill"
        default: return "circle"
        }
    }

    var formattedMeetingTime: String {
        let minutes = meetingMinutesTotal ?? 0
        if minutes == 0 { return "No meetings" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 { return "\(mins)m" }
        if mins == 0 { return "\(hours)h" }
        return "\(hours)h \(mins)m"
    }

    var formattedFocusTime: String {
        let minutes = largestFocusBlockMinutes ?? 0
        if minutes == 0 { return "No focus blocks" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 { return "\(hours)h" }
        return "\(hours)h \(mins)m"
    }
}

// MARK: - Time Intelligence Warning
struct TimeIntelligenceWarning: Codable, Identifiable {
    let type: String?
    let severity: String?
    let message: String?
    let actionText: String?
    let actionDeepLink: String?

    var id: String { type ?? UUID().uuidString }

    var isCritical: Bool {
        severity?.lowercased() == "critical"
    }

    var severityColor: Color {
        switch severity?.lowercased() ?? "" {
        case "critical": return DesignSystem.Colors.errorRed
        case "warning": return DesignSystem.Colors.amber
        case "info": return DesignSystem.Colors.blue
        default: return DesignSystem.Colors.secondaryText
        }
    }

    var severityIcon: String {
        switch severity?.lowercased() ?? "" {
        case "critical": return "exclamationmark.octagon.fill"
        case "warning": return "exclamationmark.triangle.fill"
        case "info": return "info.circle.fill"
        default: return "circle"
        }
    }

    var typeIcon: String {
        switch type?.lowercased() ?? "" {
        case "back_to_back": return "arrow.right.arrow.left"
        case "recovery_deficit": return "battery.25"
        case "burnout_risk": return "flame.fill"
        case "fragmentation": return "square.split.2x2"
        case "no_focus_time": return "brain.head.profile"
        default: return "exclamationmark.triangle"
        }
    }

    var hasAction: Bool {
        actionText != nil && actionDeepLink != nil
    }
}

// MARK: - Protected Time Block
struct ProtectedTimeBlock: Codable {
    let startTime: String?
    let endTime: String?
    let durationMinutes: Int?
    let reason: String?
    let actionText: String?
    let actionDeepLink: String?

    var formattedDuration: String {
        let minutes = durationMinutes ?? 0
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 { return "\(hours)h" }
        return "\(hours)h \(mins)m"
    }

    var formattedTimeRange: String? {
        guard let start = startTime, let end = endTime else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        guard let startDate = formatter.date(from: start),
              let endDate = formatter.date(from: end) else { return nil }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "h:mm a"

        return "\(displayFormatter.string(from: startDate)) - \(displayFormatter.string(from: endDate))"
    }
}

// MARK: - Decline Recommendation DTO
struct DeclineRecommendationDTO: Codable, Identifiable {
    let id: Int64?
    let eventId: Int64?
    let meetingTitle: String?
    let meetingStartTime: String?
    let meetingDurationMinutes: Int?
    let declineReasonCode: String?
    let declineReasonHuman: String?
    let costOfAttending: Int?
    let valueOfAttending: Int?
    let netScore: Int?
    let suggestedAction: String?
    let declineMessage: String?
    let rescheduleMessage: String?
    let confidence: Int?

    var recommendationId: Int64 { id ?? 0 }

    var isStrongRecommendation: Bool {
        (netScore ?? 0) < -30
    }

    var suggestedActionLabel: String {
        switch suggestedAction?.lowercased() ?? "" {
        case "decline": return "Decline"
        case "reschedule": return "Reschedule"
        case "shorten": return "Shorten"
        case "async": return "Make Async"
        case "delegate": return "Delegate"
        default: return "Decline"
        }
    }

    var suggestedActionIcon: String {
        switch suggestedAction?.lowercased() ?? "" {
        case "decline": return "xmark.circle.fill"
        case "reschedule": return "calendar.badge.clock"
        case "shorten": return "minus.circle.fill"
        case "async": return "envelope.fill"
        case "delegate": return "person.badge.plus"
        default: return "xmark.circle"
        }
    }

    var reasonIcon: String {
        switch declineReasonCode?.lowercased() ?? "" {
        case "back_to_back_overload": return "arrow.right.arrow.left"
        case "recovery_violation": return "battery.25"
        case "meeting_density_critical": return "flame.fill"
        case "energy_mismatch": return "bolt.slash.fill"
        case "focus_time_invasion": return "brain.head.profile"
        case "low_value": return "arrow.down.circle"
        case "recurring_waste": return "repeat"
        default: return "xmark.circle"
        }
    }

    var formattedMeetingTime: String? {
        guard let timeStr = meetingStartTime else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        if let date = formatter.date(from: timeStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "EEE h:mm a"
            return displayFormatter.string(from: date)
        }
        return nil
    }

    var formattedDuration: String {
        let minutes = meetingDurationMinutes ?? 0
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 { return "\(hours)h" }
        return "\(hours)h \(mins)m"
    }
}

// MARK: - Directive Response (Fast endpoint)
struct DirectiveResponse: Codable {
    let directive: String?
    let type: String?
    let confidence: Int?
    let overloadPercent: Int?
    let interventionUrgency: String?

    var needsIntervention: Bool {
        let urgency = interventionUrgency?.lowercased() ?? "none"
        return urgency == "medium" || urgency == "high" || urgency == "critical"
    }

    var urgencyColor: Color {
        switch interventionUrgency?.lowercased() ?? "none" {
        case "critical": return DesignSystem.Colors.errorRed
        case "high": return Color(hex: "F97316")
        case "medium": return DesignSystem.Colors.amber
        case "low": return DesignSystem.Colors.blue
        default: return DesignSystem.Colors.secondaryText
        }
    }
}
