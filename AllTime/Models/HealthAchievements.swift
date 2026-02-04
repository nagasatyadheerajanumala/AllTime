//
//  HealthAchievements.swift
//  AllTime
//
//  Models for health achievements, comparisons, and badges from the backend
//

import Foundation
import SwiftUI

// MARK: - Health Achievements Response

struct HealthAchievementsResponse: Codable {
    let periodDays: Int
    let startDate: String?
    let endDate: String?
    let totals: HealthTotals
    let dailyAverages: HealthDailyAverages
    let distanceComparison: ComparisonData?
    let calorieComparison: ComparisonData?
    let activityComparison: ComparisonData?
    let badges: [BadgeData]
    let motivationalMessage: String?
}

// MARK: - Totals

struct HealthTotals: Codable {
    let steps: Int
    let calories: Int
    let activeMinutes: Int
    let distanceMiles: Double
    let avgSleepHours: Double?
    let workouts: Int?
}

// MARK: - Daily Averages

struct HealthDailyAverages: Codable {
    let steps: Int
    let calories: Int
    let activeMinutes: Int
    let distanceMiles: Double?
}

// MARK: - Comparison Data (from OpenAI)

struct ComparisonData: Codable {
    let headline: String
    let description: String
    let emoji: String?
    let funFact: String?
    let equivalent: String?
}

// MARK: - Badge Data

struct BadgeData: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let tier: String // "bronze", "silver", "gold", "platinum"
    let icon: String // SF Symbol name
    let category: String // "steps", "calories", "activity", "sleep", "workout"

    var tierEnum: BadgeTier {
        BadgeTier(rawValue: tier) ?? .bronze
    }

    var categoryColor: Color {
        switch category {
        case "steps": return DesignSystem.Colors.emerald
        case "calories": return DesignSystem.Colors.errorRed
        case "activity": return DesignSystem.Colors.amber
        case "sleep": return DesignSystem.Colors.indigo
        case "workout": return DesignSystem.Colors.blue
        default: return DesignSystem.Colors.primary
        }
    }
}

// MARK: - Badge Tier

enum BadgeTier: String, Codable {
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
    case platinum = "platinum"

    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .gold: return DesignSystem.Colors.amber
        case .platinum: return Color(red: 0.9, green: 0.9, blue: 1.0)
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}
