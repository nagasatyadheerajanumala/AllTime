import SwiftUI

// MARK: - Weekly Insights View

struct WeeklyInsightsView: View {
    @StateObject private var viewModel = WeeklyInsightsViewModel()
    @State private var showWeekPicker = false
    @State private var expandedRecap = true
    @State private var expandedNextWeek = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Week Picker Header
                weekPickerHeader

                if viewModel.isLoading && viewModel.insights == nil {
                    loadingView
                } else if let insights = viewModel.insights {
                    // Key Metrics Row
                    keyMetricsRow(insights.recap.keyMetrics)

                    // Last Week Recap Section
                    recapSection(insights.recap)

                    // Next Week Focus Section
                    nextWeekSection(insights.nextWeekFocus)

                } else if viewModel.hasError {
                    errorView
                }

                Spacer(minLength: DesignSystem.Spacing.xl)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenMargin)
            .padding(.top, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            await viewModel.fetchAvailableWeeks()
            await viewModel.fetchInsights()
        }
        .sheet(isPresented: $showWeekPicker) {
            WeekPickerSheet(
                weeks: viewModel.availableWeeks,
                selectedWeek: viewModel.selectedWeek
            ) { week in
                Task {
                    await viewModel.selectWeek(week)
                }
            }
        }
    }

    // MARK: - Week Picker Header

    private var weekPickerHeader: some View {
        Button(action: { showWeekPicker = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Summary")
                        .font(.title2.weight(.bold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(viewModel.selectedWeek?.label ?? "This Week")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.primary)
                }

                Spacer()

                Image(systemName: "chevron.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading weekly insights...")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Text("Unable to load weekly insights")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)
            Text(viewModel.errorMessage ?? "Please try again later")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Key Metrics Row

    private func keyMetricsRow(_ metrics: [KeyMetric]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(metrics) { metric in
                    keyMetricChip(metric)
                }
            }
        }
    }

    private func keyMetricChip(_ metric: KeyMetric) -> some View {
        HStack(spacing: 6) {
            Image(systemName: metric.icon)
                .font(.caption)
                .foregroundColor(metric.color)

            Text(metric.value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(metric.label)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(metric.color.opacity(0.1))
        )
    }

    // MARK: - Recap Section

    private func recapSection(_ recap: RecapSection) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section Header
            sectionHeader(
                icon: "clock.arrow.circlepath",
                title: "Last Week Recap",
                color: Color(hex: "8B5CF6"),
                isExpanded: $expandedRecap
            )

            if expandedRecap {
                // Headline
                Text(recap.headline)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.bottom, 4)

                // What Went Wrong
                if let problems = recap.whatWentWrong, !problems.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("What went wrong")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(hex: "EF4444"))

                        ForEach(problems) { problem in
                            problemRow(problem)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(Color(hex: "EF4444").opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .stroke(Color(hex: "EF4444").opacity(0.2), lineWidth: 1)
                            )
                    )
                }

                // Highlights
                if let highlights = recap.highlights, !highlights.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Highlights")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(hex: "10B981"))

                        ForEach(highlights) { highlight in
                            highlightRow(highlight)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(Color(hex: "10B981").opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .stroke(Color(hex: "10B981").opacity(0.2), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    private func problemRow(_ problem: ProblemItem) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundColor(Color(hex: "EF4444"))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(problem.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text(problem.detail)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
    }

    private func highlightRow(_ highlight: WeeklyHighlightItem) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(Color(hex: "10B981"))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(highlight.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text(highlight.detail)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
    }

    // MARK: - Next Week Section

    private func nextWeekSection(_ nextWeek: NextWeekFocusSection) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section Header
            sectionHeader(
                icon: "arrow.right.circle.fill",
                title: "Next Week Focus",
                color: Color(hex: "3B82F6"),
                isExpanded: $expandedNextWeek
            )

            if expandedNextWeek {
                // Headline
                Text(nextWeek.headline)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.bottom, 4)

                // Priorities
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Top Priorities")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(hex: "3B82F6"))

                    ForEach(nextWeek.priorities) { priority in
                        priorityRow(priority)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(Color(hex: "3B82F6").opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .stroke(Color(hex: "3B82F6").opacity(0.2), lineWidth: 1)
                        )
                )

                // Suggested Blocks
                if let blocks = nextWeek.suggestedBlocks, !blocks.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Suggested Focus Blocks")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(hex: "10B981"))

                        ForEach(blocks) { block in
                            suggestedBlockRow(block)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(Color(hex: "10B981").opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .stroke(Color(hex: "10B981").opacity(0.2), lineWidth: 1)
                            )
                    )
                }

                // Preview Plan Button (if available)
                if let plan = nextWeek.plan, plan.available {
                    Button(action: {
                        // TODO: Implement plan preview
                    }) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Preview Plan (\(plan.changeCount) changes)")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(DesignSystem.Colors.primary)
                        )
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    private func priorityRow(_ priority: Priority) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: priority.sfSymbol)
                .font(.body)
                .foregroundColor(Color(hex: "3B82F6"))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(priority.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text(priority.detail)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()
        }
    }

    private func suggestedBlockRow(_ block: SuggestedBlock) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Day indicator
            VStack(spacing: 2) {
                Text(block.dayOfWeek.prefix(3).uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundColor(block.typeColor)
            }
            .frame(width: 40)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(block.typeColor.opacity(0.1))
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(block.formattedTime)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text(block.reason)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: block.typeIcon)
                .font(.body)
                .foregroundColor(block.typeColor)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: String, color: Color, isExpanded: Binding<Bool>) -> some View {
        Button(action: { withAnimation { isExpanded.wrappedValue.toggle() } }) {
            HStack {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundColor(color)

                Text(title)
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Week Picker Sheet

struct WeekPickerSheet: View {
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
            .navigationTitle("Select Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview

#Preview {
    WeeklyInsightsView()
}
