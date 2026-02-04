//
//  HealthAchievementsSection.swift
//  AllTime
//
//  Fun gamification: distance comparisons, calorie equivalents, and achievement badges
//  Data is fetched from the backend which uses OpenAI for creative comparisons
//

import SwiftUI

// MARK: - Health Achievements Section

struct HealthAchievementsSection: View {
    let achievements: HealthAchievementsResponse
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.amber)

                        Text("Your Achievements")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    Spacer()

                    if !achievements.badges.isEmpty {
                        Text("\(achievements.badges.count) badges")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.amber)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.amber.opacity(0.15))
                            )
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(spacing: 12) {
                    // Distance Comparison Card
                    if let comparison = achievements.distanceComparison {
                        ComparisonCard(
                            comparison: comparison,
                            color: DesignSystem.Colors.emerald,
                            stats: [
                                (formatNumber(achievements.totals.steps), "steps"),
                                (String(format: "%.1f", achievements.totals.distanceMiles), "miles"),
                                (String(format: "%.1f", achievements.totals.distanceMiles / Double(max(achievements.periodDays, 1))), "mi/day")
                            ]
                        )
                    }

                    // Calorie Comparison Card
                    if let comparison = achievements.calorieComparison {
                        ComparisonCard(
                            comparison: comparison,
                            color: DesignSystem.Colors.errorRed,
                            stats: [
                                (formatNumber(achievements.totals.calories), "kcal"),
                                (formatNumber(achievements.totals.calories / max(achievements.periodDays, 1)), "kcal/day")
                            ]
                        )
                    }

                    // Activity Comparison Card
                    if let comparison = achievements.activityComparison {
                        ComparisonCard(
                            comparison: comparison,
                            color: DesignSystem.Colors.amber,
                            stats: [
                                ("\(achievements.totals.activeMinutes)", "active min"),
                                ("\(achievements.totals.activeMinutes / max(achievements.periodDays, 1))", "min/day")
                            ]
                        )
                    }

                    // Achievement Badges
                    if !achievements.badges.isEmpty {
                        AchievementBadgesView(badges: achievements.badges)
                    }

                    // Motivational Message
                    if let message = achievements.motivationalMessage, !message.isEmpty {
                        MotivationalMessageView(message: message)
                    }
                }
            } else {
                // Collapsed preview
                CollapsedPreview(achievements: achievements)
            }
        }
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1000 {
            return String(format: "%.1fk", Double(num) / 1000.0)
        }
        return "\(num)"
    }
}

// MARK: - Comparison Card

struct ComparisonCard: View {
    let comparison: ComparisonData
    let color: Color
    let stats: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Text(comparison.emoji ?? "🏆")
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(comparison.headline)
                        .font(.headline.weight(.bold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(comparison.description)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(2)
                }

                Spacer()
            }

            // Stats pills
            HStack(spacing: 12) {
                ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                    AchievementStatPill(value: stat.0, label: stat.1, color: color)
                }
            }

            // Fun fact if available
            if let funFact = comparison.funFact, !funFact.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.amber)
                    Text(funFact)
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .lineLimit(2)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Stat Pill

struct AchievementStatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Achievement Badges View

struct AchievementBadgesView: View {
    let badges: [BadgeData]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Badges Earned")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.secondaryText)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(badges) { badge in
                    BadgeCardView(badge: badge)
                }
            }
        }
    }
}

// MARK: - Badge Card View

struct BadgeCardView: View {
    let badge: BadgeData

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(badge.tierEnum.color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Circle()
                    .strokeBorder(badge.tierEnum.color, lineWidth: 2)
                    .frame(width: 44, height: 44)

                Image(systemName: badge.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(badge.categoryColor)
            }

            Text(badge.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(badge.tierEnum.displayName)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(badge.tierEnum.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Collapsed Preview

struct CollapsedPreview: View {
    let achievements: HealthAchievementsResponse

    var body: some View {
        HStack(spacing: 12) {
            if let comparison = achievements.distanceComparison {
                HStack(spacing: 4) {
                    Text(comparison.emoji ?? "👟")
                        .font(.system(size: 12))
                    Text(comparison.headline)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(DesignSystem.Colors.emerald)
            }

            if !achievements.badges.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 12))
                    Text("\(achievements.badges.count) badges")
                        .font(.caption)
                }
                .foregroundColor(DesignSystem.Colors.amber)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Motivational Message View

struct MotivationalMessageView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundColor(DesignSystem.Colors.amber)

            Text(message)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.amber.opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview("Achievements") {
    ScrollView {
        HealthAchievementsSection(
            achievements: HealthAchievementsResponse(
                periodDays: 7,
                startDate: "2026-01-29",
                endDate: "2026-02-04",
                totals: HealthTotals(
                    steps: 52000,
                    calories: 4200,
                    activeMinutes: 320,
                    distanceMiles: 26.0,
                    avgSleepHours: 7.5,
                    workouts: 4
                ),
                dailyAverages: HealthDailyAverages(
                    steps: 7428,
                    calories: 600,
                    activeMinutes: 45,
                    distanceMiles: 3.7
                ),
                distanceComparison: ComparisonData(
                    headline: "Full Marathon!",
                    description: "You walked 26 miles - that's a full marathon distance!",
                    emoji: "🏅",
                    funFact: "The average marathon takes about 4-5 hours to complete.",
                    equivalent: nil
                ),
                calorieComparison: ComparisonData(
                    headline: "2 Pizzas Burned!",
                    description: "You burned 4,200 calories - that's 2 whole pizzas!",
                    emoji: "🍕",
                    funFact: nil,
                    equivalent: "2 pizzas or 8 Big Macs"
                ),
                activityComparison: ComparisonData(
                    headline: "320 Active Minutes!",
                    description: "You were active for over 5 hours this week!",
                    emoji: "⚡",
                    funFact: nil,
                    equivalent: nil
                ),
                badges: [
                    BadgeData(id: "marathon", name: "Marathon Master", description: "26+ miles walked!", tier: "gold", icon: "figure.walk.circle.fill", category: "steps"),
                    BadgeData(id: "calories", name: "Calorie Crusher", description: "4000+ calories burned!", tier: "silver", icon: "flame.circle.fill", category: "calories"),
                    BadgeData(id: "active", name: "Fitness Warrior", description: "300+ active minutes!", tier: "gold", icon: "bolt.circle.fill", category: "activity")
                ],
                motivationalMessage: "Amazing work! You're crushing your goals and earning badges left and right. Keep up this incredible momentum! 🌟"
            )
        )
        .padding()
    }
    .background(DesignSystem.Colors.background)
}
