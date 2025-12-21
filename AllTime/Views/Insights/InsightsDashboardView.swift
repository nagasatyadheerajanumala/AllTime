import SwiftUI

/// Premium Insights Dashboard View
/// Unified, calm, and consistent insights experience
struct InsightsDashboardView: View {
    @StateObject private var viewModel = InsightsDashboardViewModel()
    @State private var showWeekPicker = false
    @State private var isNarrativeExpanded = false
    @State private var expandedIssueId: UUID?

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                // Content
                contentView
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    weekPickerButton
                }
            }
            .sheet(isPresented: $showWeekPicker) {
                InsightsWeekPickerSheet(
                    weeks: viewModel.availableWeeks,
                    selectedWeek: viewModel.selectedWeek
                ) { week in
                    Task {
                        await viewModel.selectWeek(week)
                    }
                }
            }
            .task {
                await viewModel.fetchAvailableWeeks()
                await viewModel.loadData()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .loading:
            InsightsSkeleton()
                .padding(.top, DesignSystem.Spacing.md)

        case .loaded:
            loadedContent

        case .error(let message):
            InsightsErrorState(message: message) {
                Task {
                    await viewModel.loadData(forceRefresh: true)
                }
            }
        }
    }

    // MARK: - Loaded Content

    private var loadedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                // Week indicator (subtle)
                weekIndicator

                // SECTION 1: Your Current State (Hero)
                currentStateSection

                // SECTION 2: What Went Wrong
                if !viewModel.issues.isEmpty {
                    whatWentWrongSection
                }

                // SECTION 3: Next Week Focus
                if !viewModel.recommendations.isEmpty {
                    nextWeekFocusSection
                }

                // Bottom spacing for tab bar
                Spacer(minLength: 100)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenMargin)
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .overlay(refreshIndicator, alignment: .top)
    }

    // MARK: - Week Indicator

    private var weekIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.caption.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primary)

            Text(viewModel.selectedWeekLabel)
                .font(.caption.weight(.medium))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Section 1: Your Current State

    private var currentStateSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section Header
            InsightSectionHeader(
                title: "Your Current State",
                subtitle: "Based on this week's data",
                icon: "brain.head.profile",
                iconColor: DesignSystem.Colors.primary
            )

            // Clara's Narrative (Hero Card)
            ClaraCard(
                narrative: viewModel.claraNarrative,
                isExpanded: isNarrativeExpanded,
                onToggle: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isNarrativeExpanded.toggle()
                    }
                }
            )

            // Key Metrics (Horizontal Scroll)
            if !viewModel.keyMetrics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(viewModel.keyMetrics) { metric in
                            MetricChip(
                                icon: metric.icon,
                                value: metric.value,
                                label: metric.label,
                                color: Color(hex: metric.color),
                                trend: metric.trend.map { trend in
                                    switch trend {
                                    case .up: return .up
                                    case .down: return .down
                                    case .stable: return .stable
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section 2: What Went Wrong

    private var whatWentWrongSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section Header
            InsightSectionHeader(
                title: "What Went Wrong",
                subtitle: "Issues from the past week",
                icon: "exclamationmark.triangle.fill",
                iconColor: Color(hex: "EF4444")
            )

            // Ranked Issues
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(viewModel.issues) { issue in
                    RankedIssueRow(
                        rank: issue.rank,
                        title: issue.title,
                        detail: issue.detail,
                        severity: mapSeverity(issue.severity),
                        isExpanded: expandedIssueId == issue.id,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedIssueId == issue.id {
                                    expandedIssueId = nil
                                } else {
                                    expandedIssueId = issue.id
                                }
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Section 3: Next Week Focus

    private var nextWeekFocusSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section Header
            InsightSectionHeader(
                title: "Next Week Focus",
                subtitle: "Recommendations to improve",
                icon: "arrow.right.circle.fill",
                iconColor: Color(hex: "10B981")
            )

            // Action Recommendations
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(viewModel.recommendations) { rec in
                    ActionRecommendationCard(
                        title: rec.title,
                        description: rec.description,
                        icon: rec.icon,
                        color: Color(hex: rec.colorHex)
                    )
                }
            }
        }
    }

    // MARK: - Toolbar Items

    private var weekPickerButton: some View {
        Button(action: { showWeekPicker = true }) {
            Image(systemName: "calendar.badge.clock")
                .font(.body.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primary)
        }
    }

    // MARK: - Refresh Indicator

    @ViewBuilder
    private var refreshIndicator: some View {
        if viewModel.isRefreshing {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Updating...")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.cardBackground)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            )
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    private func mapSeverity(_ severity: InsightsDashboardViewModel.RankedIssue.Severity) -> RankedIssueRow.IssueSeverity {
        switch severity {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }
}

// MARK: - Week Picker Sheet

struct InsightsWeekPickerSheet: View {
    let weeks: [WeekOption]
    let selectedWeek: WeekOption?
    let onSelect: (WeekOption) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(weeks) { week in
                    Button(action: {
                        onSelect(week)
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(week.label)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(DesignSystem.Colors.primaryText)

                                Text("\(week.weekStart) - \(week.weekEnd)")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }

                            Spacer()

                            if week.weekStart == selectedWeek?.weekStart {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    InsightsDashboardView()
        .preferredColorScheme(.dark)
}
