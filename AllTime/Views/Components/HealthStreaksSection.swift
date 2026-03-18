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

    // Top 3 active streaks for collapsed preview
    private var topActiveStreaks: [HealthStreak] {
        Array(streaks.activeStreaks.prefix(3))
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
                            .chronaGlow(color: DesignSystem.Colors.amber, opacity: 0.3)

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

            // Collapsed Preview — horizontal streak pills
            if !isExpanded {
                if !topActiveStreaks.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(topActiveStreaks) { streak in
                            StreakPill(streak: streak)
                        }

                        Spacer()

                        Text("Tap to see all")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
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

            // Expanded Content
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

// MARK: - Streak Pill (Collapsed Preview)

struct StreakPill: View {
    let streak: HealthStreak

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: streak.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(streak.color)

            Text("\(streak.currentStreak)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Image(systemName: "flame.fill")
                .font(.system(size: 9))
                .foregroundColor(DesignSystem.Colors.amber)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(streak.color.opacity(0.12))
        )
    }
}

// MARK: - Streak Row (List-style)

struct StreakRow: View {
    let streak: HealthStreak
    @State private var isPulsing: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar for active streaks
            if streak.isActive {
                RoundedRectangle(cornerRadius: 1)
                    .fill(streak.color)
                    .frame(width: 2)
                    .padding(.vertical, 4)
            } else {
                Color.clear.frame(width: 2)
            }

            HStack(spacing: 12) {
                // Goal type icon
                ZStack {
                    Circle()
                        .fill(streak.isActive ? streak.color.opacity(0.15) : DesignSystem.Colors.tertiaryText.opacity(0.06))
                        .frame(width: 36, height: 36)

                    Image(systemName: streak.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(streak.isActive ? streak.color : DesignSystem.Colors.tertiaryText.opacity(0.5))
                }

                // Name + status
                VStack(alignment: .leading, spacing: 2) {
                    Text(streak.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(streak.isActive ? DesignSystem.Colors.primaryText : DesignSystem.Colors.tertiaryText)

                    if streak.isActive {
                        if streak.isAtRisk {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(DesignSystem.Colors.amber)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                                    .opacity(isPulsing ? 0.6 : 1.0)
                                    .onAppear {
                                        withAnimation(AppAnimations.pulse) {
                                            isPulsing = true
                                        }
                                    }
                                Text("At risk today")
                                    .font(.caption2)
                                    .foregroundColor(DesignSystem.Colors.amber)
                            }
                        } else if streak.isPersonalBest && streak.currentStreak > 1 {
                            // Gold gradient banner for personal best
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 9))
                                Text("Personal best!")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundColor(DesignSystem.Colors.amber)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                DesignSystem.Colors.amber.opacity(0.2),
                                                DesignSystem.Colors.amber.opacity(0.08)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        } else if streak.longestStreak > streak.currentStreak {
                            Text("Best: \(streak.longestStreak) days")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                    } else {
                        // Inactive — soft CTA
                        if streak.longestStreak > 0 {
                            Text("Best: \(streak.longestStreak) days \u{2022} Start today")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.tertiaryText.opacity(0.7))
                        } else {
                            Text("Start today")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(DesignSystem.Colors.tertiaryText.opacity(0.7))
                        }
                    }
                }

                Spacer()

                // Streak count — gradient pill for active, plain for inactive
                if streak.isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.amber)
                            .scaleEffect(streak.isAtRisk && isPulsing ? 1.15 : 1.0)
                        Text("\(streak.currentStreak)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Text(streak.currentStreak == 1 ? "day" : "days")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(streak.color.opacity(0.1))
                    )
                } else {
                    Text("0 days")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.tertiaryText.opacity(0.5))
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .padding(.vertical, 12)
        }
        .opacity(streak.isActive ? 1.0 : 0.55)
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
