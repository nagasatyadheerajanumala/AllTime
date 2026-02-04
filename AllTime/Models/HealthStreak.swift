//
//  HealthStreak.swift
//  AllTime
//
//  Health goal streak tracking models
//

import Foundation
import SwiftUI

// Note: DesignSystem is defined in the app's DesignSystem.swift file

// MARK: - Health Goal Type

enum HealthGoalType: String, Codable, CaseIterable {
    case steps = "STEPS"
    case sleepHours = "SLEEP_HOURS"
    case activeMinutes = "ACTIVE_MINUTES"
    case activeEnergy = "ACTIVE_ENERGY"
    case waterIntake = "WATER_INTAKE"
    case restingHR = "RESTING_HR"
    case hrv = "HRV"

    var displayName: String {
        switch self {
        case .steps: return "Steps"
        case .sleepHours: return "Sleep"
        case .activeMinutes: return "Active Minutes"
        case .activeEnergy: return "Active Energy"
        case .waterIntake: return "Water"
        case .restingHR: return "Resting HR"
        case .hrv: return "HRV"
        }
    }

    var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .sleepHours: return "bed.double.fill"
        case .activeMinutes: return "clock.fill"
        case .activeEnergy: return "flame.fill"
        case .waterIntake: return "drop.fill"
        case .restingHR: return "heart.fill"
        case .hrv: return "waveform.path.ecg"
        }
    }

    var color: Color {
        switch self {
        case .steps: return DesignSystem.Colors.emerald
        case .sleepHours: return DesignSystem.Colors.indigo
        case .activeMinutes: return DesignSystem.Colors.amber
        case .activeEnergy: return DesignSystem.Colors.errorRed
        case .waterIntake: return DesignSystem.Colors.blue
        case .restingHR: return DesignSystem.Colors.errorRed
        case .hrv: return DesignSystem.Colors.violet
        }
    }
}

// MARK: - Health Streak Model

struct HealthStreak: Codable, Identifiable {
    let goalType: String
    let displayName: String
    let currentStreak: Int
    let longestStreak: Int
    let streakStartDate: String?
    let lastAchievedDate: String?

    // Identifiable conformance - use goalType as unique id
    var id: String { goalType }

    // Computed properties for UI
    var goalTypeEnum: HealthGoalType? {
        HealthGoalType(rawValue: goalType)
    }

    var icon: String {
        goalTypeEnum?.icon ?? "heart.fill"
    }

    var color: Color {
        goalTypeEnum?.color ?? DesignSystem.Colors.primary
    }

    var isActive: Bool {
        currentStreak > 0
    }

    var isPersonalBest: Bool {
        currentStreak > 0 && currentStreak >= longestStreak
    }

    /// Check if the streak is at risk (not achieved today)
    var isAtRisk: Bool {
        guard let lastAchieved = lastAchievedDate else { return currentStreak > 0 }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: lastAchieved) else { return currentStreak > 0 }
        return !Calendar.current.isDateInToday(date) && currentStreak > 0
    }

    var statusColor: Color {
        if !isActive {
            return DesignSystem.Colors.tertiaryText
        } else if isAtRisk {
            return DesignSystem.Colors.amber
        } else {
            return color
        }
    }

    var streakStartDateFormatted: String? {
        guard let dateStr = streakStartDate else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: dateStr) else { return nil }

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}

// MARK: - Health Streaks Summary Response

struct HealthStreaksSummary: Codable {
    let totalActiveStreaks: Int
    let highestCurrentStreak: Int
    let highestAllTimeStreak: Int
    let streaks: [HealthStreak]

    /// Get streaks sorted by current streak (highest first)
    var sortedStreaks: [HealthStreak] {
        streaks.sorted { $0.currentStreak > $1.currentStreak }
    }

    /// Get only active streaks (current > 0)
    var activeStreaks: [HealthStreak] {
        streaks.filter { $0.currentStreak > 0 }
    }

    /// Get the best active streak
    var bestStreak: HealthStreak? {
        activeStreaks.max(by: { $0.currentStreak < $1.currentStreak })
    }
}
