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

                    // Active streaks count badge
                    if streaks.totalActiveStreaks > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                            Text("\(streaks.totalActiveStreaks) active")
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(DesignSystem.Colors.amber)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.amber.opacity(0.15))
                        )
                    }

                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    // Chevron indicator
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Collapsed Preview - show best streak summary
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
                            Text("\(best.displayName) • Tap to see all")
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
                    // No active streaks preview
                    HStack(spacing: 8) {
                        Image(systemName: "flame")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Text("No active streaks • Tap to see goals")
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

            // Expanded Content - Streaks Grid
            if isExpanded {
                if streaks.sortedStreaks.isEmpty {
                    NoActiveStreaksView()
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(streaks.sortedStreaks.prefix(6)) { streak in
                            StreakCard(streak: streak)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Individual Streak Card

struct StreakCard: View {
    let streak: HealthStreak

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Icon + Goal Type
            HStack(spacing: 8) {
                // Goal type icon
                ZStack {
                    Circle()
                        .fill(streak.statusColor.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: streak.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(streak.statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(streak.displayName)
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)

                    // Status indicator
                    if streak.isAtRisk && streak.isActive {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 9))
                            Text("At risk")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.amber)
                    } else if !streak.isActive {
                        Text("Start today!")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }

                Spacer()
            }

            // Main streak number with flame
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if streak.isActive {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20))
                        .foregroundColor(streak.isAtRisk ? DesignSystem.Colors.amber : DesignSystem.Colors.amber)
                }

                Text("\(streak.currentStreak)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(streak.isActive ? DesignSystem.Colors.primaryText : DesignSystem.Colors.tertiaryText)

                Text(streak.currentStreak == 1 ? "day" : "days")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            // Personal best indicator
            if streak.isPersonalBest && streak.currentStreak > 1 {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10))
                    Text("Personal Best!")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(DesignSystem.Colors.amber)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.amber.opacity(0.15))
                )
            } else if streak.longestStreak > streak.currentStreak {
                // Show longest streak if different from current
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9))
                    Text("Best: \(streak.longestStreak) days")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .strokeBorder(
                    streak.isPersonalBest ? DesignSystem.Colors.amber.opacity(0.3) : Color.clear,
                    lineWidth: 1.5
                )
        )
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
                // Flame icon
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

                    Text("\(bestStreak.displayName) • \(streaks.totalActiveStreaks) goals on track")
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
            // Sample data
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
