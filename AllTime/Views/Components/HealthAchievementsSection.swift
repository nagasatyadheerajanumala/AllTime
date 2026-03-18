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

                        Text("Achievements")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    Spacer()

                    if !achievements.badges.isEmpty {
                        Text("\(achievements.badges.count) badges")
                            .font(.caption.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.amber)
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
                    // Comparisons as a grouped card with rows
                    let comparisons = buildComparisons()
                    if !comparisons.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(comparisons.enumerated()), id: \.offset) { index, item in
                                ComparisonRow(
                                    emoji: item.emoji,
                                    headline: item.headline,
                                    description: item.description,
                                    stats: item.stats,
                                    color: item.color
                                )

                                if index < comparisons.count - 1 {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(DesignSystem.Colors.cardBackground)
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

    private func buildComparisons() -> [ComparisonRowData] {
        var items: [ComparisonRowData] = []

        if let c = achievements.distanceComparison {
            items.append(ComparisonRowData(
                emoji: c.emoji ?? "👟",
                headline: c.headline,
                description: c.description,
                stats: [
                    (formatNumber(achievements.totals.steps), "steps"),
                    (String(format: "%.1f", achievements.totals.distanceMiles), "mi")
                ],
                color: DesignSystem.Colors.emerald
            ))
        }

        if let c = achievements.calorieComparison {
            items.append(ComparisonRowData(
                emoji: c.emoji ?? "🔥",
                headline: c.headline,
                description: c.description,
                stats: [
                    (formatNumber(achievements.totals.calories), "kcal"),
                    (formatNumber(achievements.totals.calories / max(achievements.periodDays, 1)), "/day")
                ],
                color: DesignSystem.Colors.errorRed
            ))
        }

        if let c = achievements.activityComparison {
            items.append(ComparisonRowData(
                emoji: c.emoji ?? "⚡",
                headline: c.headline,
                description: c.description,
                stats: [
                    ("\(achievements.totals.activeMinutes)", "min"),
                    ("\(achievements.totals.activeMinutes / max(achievements.periodDays, 1))", "/day")
                ],
                color: DesignSystem.Colors.amber
            ))
        }

        return items
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1000 {
            return String(format: "%.1fk", Double(num) / 1000.0)
        }
        return "\(num)"
    }
}

// MARK: - Comparison Row Data

private struct ComparisonRowData {
    let emoji: String
    let headline: String
    let description: String
    let stats: [(String, String)]
    let color: Color
}

// MARK: - Comparison Row

struct ComparisonRow: View {
    let emoji: String
    let headline: String
    let description: String
    let stats: [(String, String)]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Emoji icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Text(emoji)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            // Stats as horizontal pill row below description
            HStack(spacing: 8) {
                ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                    HStack(spacing: 3) {
                        Text(stat.0)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(color)
                        Text(stat.1)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(color.opacity(0.7))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.1))
                    )
                }
            }
            .padding(.leading, 52)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}

// MARK: - Achievement Badges View

struct AchievementBadgesView: View {
    let badges: [BadgeData]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "medal.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.amber)

                Text("Badges Earned")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(badges) { badge in
                        BadgeCardView(badge: badge)
                    }
                }
            }
        }
    }
}

// MARK: - Badge Card View

struct BadgeCardView: View {
    let badge: BadgeData

    private var tierGradient: [Color] {
        switch badge.tierEnum {
        case .bronze:
            return [Color(red: 0.8, green: 0.5, blue: 0.2), Color(red: 0.6, green: 0.35, blue: 0.15)]
        case .silver:
            return [Color.white.opacity(0.12), Color.gray.opacity(0.08)]
        case .gold:
            return [DesignSystem.Colors.amber, DesignSystem.Colors.amber.opacity(0.6)]
        case .platinum:
            return [Color(red: 0.9, green: 0.9, blue: 1.0).opacity(0.15), Color.blue.opacity(0.08)]
        }
    }

    private var tierGradientOpacity: Double {
        switch badge.tierEnum {
        case .bronze: return 0.12
        case .silver: return 1.0 // already has opacity baked in
        case .gold: return 0.15
        case .platinum: return 1.0 // already has opacity baked in
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Double-ring icon
            ZStack {
                // Outer ring (stroke with gap)
                Circle()
                    .strokeBorder(badge.tierEnum.color.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 54, height: 54)

                // Inner fill circle
                Circle()
                    .fill(badge.tierEnum.color.opacity(0.15))
                    .frame(width: 46, height: 46)

                Image(systemName: badge.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(badge.categoryColor)
            }

            VStack(spacing: 4) {
                Text(badge.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                // Tier label as colored pill
                Text(badge.tierEnum.displayName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(badge.tierEnum.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(badge.tierEnum.color.opacity(0.12))
                    )
            }
        }
        .frame(width: 100)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(
            ZStack {
                // Base card fill
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.cardBackground)

                // Tier-specific gradient overlay
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(
                        LinearGradient(
                            colors: tierGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(tierGradientOpacity)
            }
        )
        .overlay(alignment: .top) {
            // Top-edge accent line
            RoundedRectangle(cornerRadius: 0.5)
                .fill(badge.tierEnum.color.opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
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
                .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            if !achievements.badges.isEmpty {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 12))
                    Text("\(achievements.badges.count) badges")
                        .font(.caption)
                }
                .foregroundColor(DesignSystem.Colors.amber)
            } else {
                Spacer()
            }
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
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.amber)

            Text(message)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.amber.opacity(0.08))
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
                motivationalMessage: "Amazing work! You're crushing your goals and earning badges left and right. Keep up this incredible momentum!"
            )
        )
        .padding()
    }
    .background(DesignSystem.Colors.background)
}
