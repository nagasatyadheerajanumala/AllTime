//
//  HealthStreaksSection.swift
//  AllTime
//
//  Health goal streak display components
//

import SwiftUI

// MARK: - Health Streaks Section

struct HealthStreaksSection: View {
    let streaks: HealthStreaksSummary
    let isLoading: Bool
    @State private var isExpanded: Bool = false

    // Show best streak in collapsed state
    private var bestStreak: HealthStreak? {
        streaks.sortedStreaks.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tappable Header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.amber)

                        Text("Goal Streaks")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    Spacer()

                    if streaks.totalActiveStreaks > 0 {
                        Text("\(streaks.totalActiveStreaks) active")
                            .font(.caption.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.amber)
                    }

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Collapsed Preview
            if !isExpanded {
                if let best = bestStreak, best.currentStreak > 0 {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(best.color.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: best.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(best.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignSystem.Colors.amber)
                                Text("\(best.currentStreak)-day streak")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                if best.isPersonalBest {
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(DesignSystem.Colors.amber)
                                }
                            }
                            Text("\(best.displayName) \u{2022} Tap to see all")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "flame")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Text("No active streaks \u{2022} Tap to see goals")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                }
            }

            // Expanded Content - List-style rows in a grouped card
            if isExpanded {
                if streaks.sortedStreaks.isEmpty {
                    NoActiveStreaksView()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(streaks.sortedStreaks.prefix(6).enumerated()), id: \.element.id) { index, streak in
                            StreakRow(streak: streak)

                            if index < min(streaks.sortedStreaks.count, 6) - 1 {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                }
            }
        }
    }
}

// MARK: - Streak Row (List-style)

struct StreakRow: View {
    let streak: HealthStreak

    var body: some View {
        HStack(spacing: 12) {
            // Goal type icon
            ZStack {
                Circle()
                    .fill(streak.isActive ? streak.color.opacity(0.15) : DesignSystem.Colors.tertiaryText.opacity(0.1))
                    .frame(width: 36, height: 36)

                Image(systemName: streak.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(streak.isActive ? streak.color : DesignSystem.Colors.tertiaryText)
            }

            // Name + status
            VStack(alignment: .leading, spacing: 2) {
                Text(streak.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                if streak.isActive {
                    if streak.isAtRisk {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(DesignSystem.Colors.amber)
                                .frame(width: 6, height: 6)
                            Text("At risk today")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.amber)
                        }
                    } else if streak.isPersonalBest && streak.currentStreak > 1 {
                        HStack(spacing: 3) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 9))
                            Text("Personal best!")
                                .font(.caption2)
                        }
                        .foregroundColor(DesignSystem.Colors.amber)
                    } else if streak.longestStreak > streak.currentStreak {
                        Text("Best: \(streak.longestStreak) days")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                } else {
                    Text("Best: \(streak.longestStreak) days")
                        .font(.caption2)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }

            Spacer()

            // Streak count
            HStack(spacing: 4) {
                if streak.isActive {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.amber)
                }
                Text("\(streak.currentStreak)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(streak.isActive ? DesignSystem.Colors.primaryText : DesignSystem.Colors.tertiaryText)
                Text(streak.currentStreak == 1 ? "day" : "days")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - No Active Streaks View

struct NoActiveStreaksView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "flame")
                .font(.system(size: 32))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            VStack(spacing: 4) {
                Text("No Active Streaks")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text("Meet your health goals today to start building streaks!")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Streak Highlight Banner (For Today View)

struct StreakHighlightBanner: View {
    let streaks: HealthStreaksSummary

    var body: some View {
        if let bestStreak = streaks.bestStreak, bestStreak.currentStreak > 0 {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.amber.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.amber)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(bestStreak.currentStreak)-day streak")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        if bestStreak.isPersonalBest {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.amber)
                        }
                    }

                    Text("\(bestStreak.displayName) \u{2022} \(streaks.totalActiveStreaks) goals on track")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .strokeBorder(DesignSystem.Colors.amber.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview

#Preview("Streaks Section") {
    ScrollView {
        VStack(spacing: 20) {
            HealthStreaksSection(
                streaks: HealthStreaksSummary(
                    totalActiveStreaks: 3,
                    highestCurrentStreak: 12,
                    highestAllTimeStreak: 30,
                    streaks: [
                        HealthStreak(goalType: "STEPS", displayName: "Steps", currentStreak: 7, longestStreak: 7, streakStartDate: "2026-01-28", lastAchievedDate: "2026-02-04"),
                        HealthStreak(goalType: "SLEEP_HOURS", displayName: "Sleep", currentStreak: 3, longestStreak: 14, streakStartDate: "2026-02-01", lastAchievedDate: "2026-02-04"),
                        HealthStreak(goalType: "ACTIVE_MINUTES", displayName: "Active Minutes", currentStreak: 0, longestStreak: 5, streakStartDate: nil, lastAchievedDate: "2026-02-01"),
                        HealthStreak(goalType: "ACTIVE_ENERGY", displayName: "Active Energy", currentStreak: 12, longestStreak: 12, streakStartDate: "2026-01-24", lastAchievedDate: "2026-02-04")
                    ]
                ),
                isLoading: false
            )
            .padding(.horizontal)
        }
    }
    .background(DesignSystem.Colors.background)
}

#Preview("No Streaks") {
    ScrollView {
        HealthStreaksSection(
            streaks: HealthStreaksSummary(
                totalActiveStreaks: 0,
                highestCurrentStreak: 0,
                highestAllTimeStreak: 0,
                streaks: []
            ),
            isLoading: false
        )
        .padding(.horizontal)
    }
    .background(DesignSystem.Colors.background)
}
