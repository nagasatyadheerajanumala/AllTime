import SwiftUI

// MARK: - Weekly Insights View (Calm Notebook Style)

/// A calm, notebook-style weekly insights view that answers 5 key questions:
/// 1. How was my week overall?
/// 2. Where did my time go?
/// 3. Was my schedule aligned with my energy?
/// 4. What patterns should I watch?
/// 5. What could I do differently?
struct WeeklyInsightsView: View {
    @StateObject private var viewModel = WeeklyNarrativeViewModel()
    @State private var showWeekPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Week Picker Header
                weekPickerHeader

                if viewModel.isLoading && viewModel.narrative == nil {
                    loadingView
                } else if let narrative = viewModel.narrative {
                    // Section 1: Hero Card - Overall Tone & Summary
                    heroCard(narrative)

                    // Section 2: Where Your Time Went
                    if !narrative.timeBuckets.isEmpty {
                        timeBucketsSection(narrative.timeBuckets)
                    }

                    // Section 3: Energy Alignment
                    if let energy = narrative.energyAlignment {
                        energyAlignmentSection(energy)
                    }

                    // Section 4: Areas to Watch
                    if !narrative.stressSignals.isEmpty {
                        stressSignalsSection(narrative.stressSignals)
                    }

                    // Section 5: Suggestions
                    if !narrative.suggestions.isEmpty {
                        suggestionsSection(narrative.suggestions)
                    }

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
            async let weeksTask: () = viewModel.fetchAvailableWeeks()
            async let narrativeTask: () = viewModel.fetchNarrative()
            _ = await (weeksTask, narrativeTask)
        }
        .onDisappear {
            viewModel.cancelPendingRequests()
        }
        .sheet(isPresented: $showWeekPicker) {
            WeekPickerSheet(
                weeks: viewModel.availableWeeks,
                selectedWeek: viewModel.selectedWeek
            ) { week in
                Task { await viewModel.selectWeek(week) }
            }
        }
    }

    // MARK: - Week Picker Header

    private var weekPickerHeader: some View {
        Button(action: { showWeekPicker = true }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Week")
                        .font(.title2.weight(.bold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(viewModel.selectedWeek?.label ?? "This Week")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primary.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Hero Card (Section 1)

    private func heroCard(_ narrative: WeeklyNarrativeResponse) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Tone Badge
            HStack(spacing: 8) {
                Circle()
                    .fill(narrative.toneColor)
                    .frame(width: 10, height: 10)
                Text(narrative.overallTone)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(narrative.toneColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(narrative.toneColor.opacity(0.15))
            )

            // Weekly Overview (one sentence)
            Text(narrative.weeklyOverview)
                .font(.title3.weight(.medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)

            Spacer(minLength: DesignSystem.Spacing.sm)

            // Quick Stats Row
            HStack(spacing: 16) {
                statPill(
                    icon: "person.2.fill",
                    value: "\(narrative.aggregates.totalMeetings)",
                    label: "meetings"
                )

                statPill(
                    icon: "brain.head.profile",
                    value: narrative.aggregates.formattedFocusHours,
                    label: "focus"
                )

                if narrative.aggregates.averageSleepHours != nil {
                    statPill(
                        icon: "moon.zzz.fill",
                        value: narrative.aggregates.formattedSleep,
                        label: "avg sleep"
                    )
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1E1B4B"), Color(hex: "312E81")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
        )
    }

    // MARK: - Time Buckets Section (Section 2)

    private func timeBucketsSection(_ buckets: [TimeBucket]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "3B82F6").opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "3B82F6"))
                }

                Text("Where Your Time Went")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)

            // Time Buckets List
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(buckets) { bucket in
                    timeBucketRow(bucket)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                )
        )
    }

    private func timeBucketRow(_ bucket: TimeBucket) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(bucket.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: bucket.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(bucket.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bucket.category.capitalized)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text(bucket.label)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()

            Text(bucket.formattedHours)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(bucket.color)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(bucket.color.opacity(0.05))
        )
    }

    // MARK: - Energy Alignment Section (Section 3)

    private func energyAlignmentSection(_ energy: EnergyAlignment) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(energy.color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: energy.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(energy.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Energy & Health")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text(energy.label)
                        .font(.caption.weight(.medium))
                        .foregroundColor(energy.color)
                }

                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)

            // Summary
            Text(energy.summary)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DesignSystem.Spacing.md)

            // Evidence
            if !energy.evidence.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(energy.evidence, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundColor(energy.color.opacity(0.6))
                                .padding(.top, 6)
                            Text(item)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(energy.color.opacity(0.05))
                )
                .padding(.horizontal, DesignSystem.Spacing.md)
            }

            Spacer(minLength: DesignSystem.Spacing.sm)
        }
        .padding(.bottom, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                )
        )
    }

    // MARK: - Stress Signals Section (Section 4)

    private func stressSignalsSection(_ signals: [StressSignal]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "F59E0B").opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "eye")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "F59E0B"))
                }

                Text("Areas to Watch")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)

            // Signals List
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(signals) { signal in
                    stressSignalRow(signal)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                )
        )
    }

    private func stressSignalRow(_ signal: StressSignal) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.body)
                .foregroundColor(Color(hex: "F59E0B"))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(signal.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text(signal.evidence)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(hex: "F59E0B").opacity(0.05))
        )
    }

    // MARK: - Suggestions Section (Section 5)

    private func suggestionsSection(_ suggestions: [WeeklySuggestion]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "10B981").opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "10B981"))
                }

                Text("Ideas for Next Week")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)

            // Suggestions List
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(suggestions) { suggestion in
                    suggestionRow(suggestion)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                )
        )
    }

    private func suggestionRow(_ suggestion: WeeklySuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(suggestion.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(suggestion.why)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            // Action chip
            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.caption)
                    .foregroundColor(Color(hex: "10B981"))
                Text(suggestion.action)
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color(hex: "10B981"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "10B981").opacity(0.1))
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(hex: "10B981").opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(Color(hex: "10B981").opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.cardBackground)
                    .frame(width: 60, height: 60)
                ProgressView()
                    .scaleEffect(1.2)
            }
            Text("Reflecting on your week...")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.softCritical.opacity(0.1))
                    .frame(width: 64, height: 64)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundColor(DesignSystem.Colors.softCritical)
            }

            Text("Unable to load insights")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(viewModel.errorMessage ?? "Please try again later")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: { Task { await viewModel.refresh() } }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.primary)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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
