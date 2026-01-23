import SwiftUI

/// The Decision Surface - Visual-first, glanceable time intelligence.
/// Design principle: Show, don't tell. One glance = full understanding.
struct DecisionSurfaceView: View {
    @StateObject private var intelligenceService = TimeIntelligenceService.shared
    @State private var selectedDeclineRecommendation: DeclineRecommendationDTO?
    @State private var showingDeclineSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                if intelligenceService.isLoading && intelligenceService.todayIntelligence == nil {
                    loadingState
                } else if let intelligence = intelligenceService.todayIntelligence {
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.xl) {
                            // HERO: Capacity Ring - The ONE number that matters
                            CapacityRing(
                                percent: intelligence.capacityOverloadPercent,
                                status: intelligence.capacityStatus ?? "unknown"
                            )
                            .padding(.top, DesignSystem.Spacing.lg)

                            // QUICK STATUS: Visual pills, no text walls
                            QuickStatusRow(intelligence: intelligence)
                                .padding(.horizontal, DesignSystem.Spacing.md)

                            // ACTIONS: What to do (not why)
                            if intelligence.hasDeclineRecommendations {
                                DeclineActionCards(
                                    recommendations: intelligence.declineRecommendations ?? [],
                                    onSelect: { recommendation in
                                        selectedDeclineRecommendation = recommendation
                                        showingDeclineSheet = true
                                    }
                                )
                                .padding(.horizontal, DesignSystem.Spacing.md)
                            }

                            // PROTECTED TIME: Visual block
                            if let protectedBlock = intelligence.protectedTimeBlock {
                                ProtectedTimeVisual(block: protectedBlock)
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                            }

                            Color.clear.frame(height: 100)
                        }
                    }
                    .refreshable {
                        await intelligenceService.fetchTodayIntelligence()
                    }
                } else {
                    emptyState
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task {
                    await intelligenceService.fetchTodayIntelligence()
                }
            }
            .sheet(isPresented: $showingDeclineSheet) {
                if let recommendation = selectedDeclineRecommendation {
                    DeclineActionSheet(
                        recommendation: recommendation,
                        onDecline: {
                            showingDeclineSheet = false
                            Task {
                                await intelligenceService.recordDeclineAction(
                                    recommendationId: recommendation.recommendationId,
                                    action: "declined",
                                    wasPositive: true
                                )
                                await intelligenceService.fetchTodayIntelligence()
                            }
                        },
                        onReschedule: {
                            showingDeclineSheet = false
                            Task {
                                await intelligenceService.recordDeclineAction(
                                    recommendationId: recommendation.recommendationId,
                                    action: "rescheduled",
                                    wasPositive: true
                                )
                                await intelligenceService.fetchTodayIntelligence()
                            }
                        },
                        onDismiss: {
                            showingDeclineSheet = false
                            Task {
                                await intelligenceService.dismissRecommendation(
                                    recommendationId: recommendation.recommendationId
                                )
                                await intelligenceService.fetchTodayIntelligence()
                            }
                        }
                    )
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            CapacityRing(percent: 0, status: "loading", isLoading: true)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            CapacityRing(percent: 0, status: "clear", isLoading: false)
            Text("Pull to refresh")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
    }
}

// MARK: - Capacity Ring (Hero Component)
/// The dominant visual - a ring that shows capacity at a glance.
/// Color tells the story. Number confirms it.
struct CapacityRing: View {
    let percent: Int
    let status: String
    var isLoading: Bool = false

    private var ringColor: Color {
        if percent >= 100 { return DesignSystem.Colors.errorRed }
        if percent >= 80 { return DesignSystem.Colors.amber }
        if percent >= 60 { return DesignSystem.Colors.blue }
        return DesignSystem.Colors.emerald
    }

    private var statusIcon: String {
        if percent >= 100 { return "xmark.circle.fill" }
        if percent >= 80 { return "exclamationmark.triangle.fill" }
        if percent >= 60 { return "minus.circle.fill" }
        return "checkmark.circle.fill"
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(DesignSystem.Colors.secondaryText.opacity(0.15), lineWidth: 16)
                .frame(width: 180, height: 180)

            // Progress ring
            Circle()
                .trim(from: 0, to: isLoading ? 0.3 : min(CGFloat(percent) / 100.0, 1.0))
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))
                .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .easeOut(duration: 0.8), value: isLoading ? 0.3 : CGFloat(percent))

            // Center content
            VStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    Text("\(percent)%")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(ringColor)

                    Image(systemName: statusIcon)
                        .font(.system(size: 20))
                        .foregroundColor(ringColor)
                }
            }
        }
    }
}

// MARK: - Quick Status Row
/// Visual pills that show status without text walls.
struct QuickStatusRow: View {
    let intelligence: TimeIntelligenceResponse

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Meetings pill
            StatusPill(
                icon: "calendar",
                value: "\(intelligence.metrics?.meetingCount ?? 0)",
                color: meetingColor
            )

            // Focus time pill
            StatusPill(
                icon: "brain.head.profile",
                value: intelligence.metrics?.formattedFocusTime ?? "0h",
                color: DesignSystem.Colors.violet
            )

            // Warnings pill (if any)
            if intelligence.hasWarnings {
                StatusPill(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(intelligence.warnings?.count ?? 0)",
                    color: DesignSystem.Colors.amber
                )
            }

            // Burnout indicator
            if intelligence.metrics?.hasBurnoutRisk == true {
                StatusPill(
                    icon: "flame.fill",
                    value: "\(intelligence.metrics?.consecutiveHighLoadDays ?? 0)d",
                    color: DesignSystem.Colors.errorRed
                )
            }
        }
    }

    private var meetingColor: Color {
        let count = intelligence.metrics?.meetingCount ?? 0
        if count >= 6 { return DesignSystem.Colors.errorRed }
        if count >= 4 { return DesignSystem.Colors.amber }
        return DesignSystem.Colors.blue
    }
}

struct StatusPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}

// MARK: - Action Cards
/// Minimal cards focused on action, not explanation.
struct DeclineActionCards: View {
    let recommendations: [DeclineRecommendationDTO]
    let onSelect: (DeclineRecommendationDTO) -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(recommendations) { recommendation in
                DeclineActionCard(
                    recommendation: recommendation,
                    onTap: { onSelect(recommendation) }
                )
            }
        }
    }
}

struct DeclineActionCard: View {
    let recommendation: DeclineRecommendationDTO
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Red indicator
                Circle()
                    .fill(DesignSystem.Colors.errorRed)
                    .frame(width: 8, height: 8)

                // Meeting info - minimal
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.meetingTitle ?? "Meeting")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)

                    Text(recommendation.formattedMeetingTime ?? "")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                // Action button
                Text("Decline")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.errorRed)
                    )
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Protected Time Visual
/// Visual block showing protected time - minimal text.
struct ProtectedTimeVisual: View {
    let block: ProtectedTimeBlock

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Shield icon
            Image(systemName: "shield.fill")
                .font(.system(size: 24))
                .foregroundColor(DesignSystem.Colors.violet)

            VStack(alignment: .leading, spacing: 2) {
                Text(block.formattedDuration)
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text("Protected")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.violet)
            }

            Spacer()

            // Time display
            Text(block.formattedTimeRange ?? "")
                .font(.caption.weight(.medium))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.violet.opacity(0.1))
        )
    }
}

#Preview {
    DecisionSurfaceView()
}
