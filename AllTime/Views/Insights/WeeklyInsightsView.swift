import SwiftUI

// MARK: - Weekly Insights View (Report Card Style)

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
                    // Report Card Sections - show narrative if we have one
                    reportCardContent(narrative)
                } else if viewModel.hasError {
                    errorView
                } else if viewModel.isLoading {
                    loadingView
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
            async let forecastTask: () = viewModel.fetchNextWeekForecast()
            _ = await (weeksTask, narrativeTask, forecastTask)
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

    // MARK: - Report Card Content

    @ViewBuilder
    private func reportCardContent(_ narrative: WeeklyNarrativeResponse) -> some View {
        // Section 0: Next Week Forecast (Predictive Intelligence - show first!)
        // Only show when viewing current week
        if viewModel.isCurrentWeek {
            nextWeekForecastSection
        }

        // Section 1: Balance Score Hero
        balanceScoreSection(narrative)

        // Section 2: Week Overview Summary
        weekOverviewCard(narrative)

        // Section 3: Week Highlights (specific interesting tidbits)
        if let highlights = narrative.weekHighlights, highlights.hasAnyHighlights {
            weekHighlightsSection(highlights)
        }

        // Section 4: Metrics Comparison Grid
        if let comparison = narrative.comparison, comparison.hasPreviousWeek {
            metricsComparisonSection(comparison)
        }

        // Section 5: Health Goals Achievement
        if let healthGoals = narrative.healthGoals, healthGoals.hasGoals && healthGoals.hasData {
            healthGoalsSection(healthGoals)
        }

        // Section 5.5: Energy Patterns (meeting/health correlations)
        EnergyPatternsSection()

        // Section 5.6: Similar Week Alert (pattern matching with historical weeks)
        SimilarWeekSection()

        // Section 6: Where Your Time Went
        if let timeBuckets = narrative.timeBuckets, !timeBuckets.isEmpty {
            timeBucketsSection(timeBuckets)
        }

        // Section 7: Energy Alignment
        if let energy = narrative.energyAlignment {
            energyAlignmentSection(energy)
        }

        // Section 8: Areas to Watch
        if let stressSignals = narrative.stressSignals, !stressSignals.isEmpty {
            stressSignalsSection(stressSignals)
        }

        // Section 9: Suggestions
        if let suggestions = narrative.suggestions, !suggestions.isEmpty {
            suggestionsSection(suggestions)
        }
    }

    // MARK: - Week Picker Header

    private var weekPickerHeader: some View {
        Button(action: { showWeekPicker = true }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly Report")
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

    // MARK: - Balance Score Section

    private func balanceScoreSection(_ narrative: WeeklyNarrativeResponse) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Balance Score Ring
            if let comparison = narrative.comparison {
                BalanceScoreRing(
                    score: comparison.balanceScore,
                    previousScore: comparison.hasPreviousWeek ? comparison.prevBalanceScore : nil,
                    size: 160
                )
                .padding(.top, DesignSystem.Spacing.md)

                Text("Work-Life Balance")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                if comparison.hasPreviousWeek {
                    let trend = comparison.balanceScoreDelta
                    HStack(spacing: 4) {
                        if trend > 0 {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(Color(hex: "10B981"))
                            Text("\(trend) points from last week")
                                .foregroundColor(Color(hex: "10B981"))
                        } else if trend < 0 {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(Color(hex: "EF4444"))
                            Text("\(abs(trend)) points from last week")
                                .foregroundColor(Color(hex: "EF4444"))
                        } else {
                            Image(systemName: "equal.circle.fill")
                                .foregroundColor(Color(hex: "6B7280"))
                            Text("Same as last week")
                                .foregroundColor(Color(hex: "6B7280"))
                        }
                    }
                    .font(.caption.weight(.medium))
                }

                // Score Drivers - show what's driving the score
                if let breakdown = comparison.scoreBreakdown, !breakdown.significantDrivers.isEmpty {
                    scoreDriversSection(breakdown)
                }
            } else {
                // Fallback: Show tone-based hero when no comparison data
                toneBasedHero(narrative)
            }
        }
        .frame(maxWidth: .infinity)
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

    private func toneBasedHero(_ narrative: WeeklyNarrativeResponse) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
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

            // Quick Stats Row
            if let aggregates = narrative.aggregates {
                HStack(spacing: 16) {
                    statPill(
                        icon: "person.2.fill",
                        value: "\(aggregates.totalMeetings)",
                        label: "meetings"
                    )

                    statPill(
                        icon: "brain.head.profile",
                        value: aggregates.formattedFocusHours,
                        label: "focus"
                    )

                    if aggregates.averageSleepHours != nil {
                        statPill(
                            icon: "moon.zzz.fill",
                            value: aggregates.formattedSleep,
                            label: "avg sleep"
                        )
                    }
                }
            }
        }
    }

    // MARK: - Score Drivers Section

    private func scoreDriversSection(_ breakdown: ScoreBreakdown) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.top, DesignSystem.Spacing.sm)

            // Drivers label
            Text("Driven by")
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 4)

            // Show top 3 most significant drivers
            let topDrivers = Array(breakdown.significantDrivers.prefix(3))
            FlexibleDriversView(drivers: topDrivers)
                .padding(.horizontal, DesignSystem.Spacing.sm)

            // Show improvement levers if available
            if breakdown.hasLevers, let levers = breakdown.levers, !levers.isEmpty {
                scoreLeversSection(levers)
            }
        }
    }

    // MARK: - Score Levers Section

    private func scoreLeversSection(_ levers: [ScoreLever]) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.top, DesignSystem.Spacing.xs)

            // Levers label
            Text("Quick wins")
                .font(.caption.weight(.medium))
                .foregroundColor(Color(hex: "10B981").opacity(0.8))
                .padding(.top, 4)

            // Show levers as tappable rows
            ForEach(levers.prefix(2)) { lever in
                Button(action: {
                    HapticManager.shared.mediumTap()
                    NavigationManager.shared.handleDestination(lever.deepLink)
                }) {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: lever.sfSymbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "10B981"))
                            .frame(width: 16)

                        Text(lever.action)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 8)

                        Text(lever.formattedGain)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "10B981"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "10B981").opacity(0.2))
                            )
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "10B981").opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "10B981").opacity(0.2), lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
    }

    // MARK: - Week Overview Card

    private func weekOverviewCard(_ narrative: WeeklyNarrativeResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(narrative.toneEmoji)
                    .font(.title2)
                Text(narrative.overallTone)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(narrative.toneColor)
            }

            Text(narrative.weeklyOverview)
                .font(.body)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                )
        )
    }

    // MARK: - Week Highlights Section

    private func weekHighlightsSection(_ highlights: WeekHighlights) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "F59E0B").opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "F59E0B"))
                }

                Text("Week Highlights")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                if let collabs = highlights.totalCollaborators, collabs > 0 {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("\(collabs) people")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(hex: "6B7280").opacity(0.1))
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)

            // Horizontal scrolling highlights
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Busiest day - most meaningful
                    if let busiest = highlights.busiestDay {
                        highlightCard(busiest)
                    }

                    // Key collaborator
                    if let collaborator = highlights.keyCollaborator {
                        highlightCard(collaborator)
                    }

                    // Marathon day (back-to-back meetings)
                    if let marathon = highlights.marathonDay {
                        highlightCard(marathon)
                    }

                    // Longest meeting
                    if let longest = highlights.longestMeeting {
                        highlightCard(longest)
                    }

                    // Early bird
                    if let earliest = highlights.earliestMeeting {
                        highlightCard(earliest)
                    }

                    // Night owl
                    if let latest = highlights.latestMeeting {
                        highlightCard(latest)
                    }

                    // Travel
                    if let travel = highlights.travel {
                        ForEach(travel) { trip in
                            highlightCard(trip)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
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

    private func highlightCard(_ item: WeekHighlightDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon and label
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(item.iconColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: item.sfSymbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(item.iconColor)
                }

                Text(item.label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(item.iconColor)
            }

            // Title
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Detail
            Text(item.detail)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .lineLimit(1)
        }
        .padding(12)
        .frame(width: 160, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(item.iconColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(item.iconColor.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Metrics Comparison Section

    private func metricsComparisonSection(_ comparison: WeekComparison) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "8B5CF6").opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "8B5CF6"))
                }

                Text("Week vs Week")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            // 2x2 Grid of metrics
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                // Meetings
                compactMetricCard(
                    title: "Meetings",
                    icon: "person.2.fill",
                    current: comparison.meetingHoursThisWeek,
                    previous: comparison.meetingHoursPrevWeek,
                    delta: comparison.meetingHoursDelta,
                    trend: comparison.meetingTrend,
                    unit: "h",
                    color: Color(hex: "8B5CF6"),
                    higherIsBetter: false
                )

                // Focus Time
                compactMetricCard(
                    title: "Focus",
                    icon: "brain.head.profile",
                    current: comparison.focusHoursThisWeek,
                    previous: comparison.focusHoursPrevWeek,
                    delta: comparison.focusHoursDelta,
                    trend: comparison.focusTrend,
                    unit: "h",
                    color: Color(hex: "3B82F6"),
                    higherIsBetter: true
                )

                // Events
                compactMetricCard(
                    title: "Events",
                    icon: "calendar",
                    current: comparison.eventsThisWeek,
                    previous: comparison.eventsPrevWeek,
                    delta: comparison.eventsDelta,
                    trend: comparison.eventsTrend,
                    unit: "",
                    color: Color(hex: "F59E0B"),
                    higherIsBetter: false
                )

                // Free Time
                compactMetricCard(
                    title: "Free Time",
                    icon: "leaf.fill",
                    current: comparison.freeHoursThisWeek,
                    previous: comparison.freeHoursPrevWeek,
                    delta: comparison.freeHoursDelta,
                    trend: comparison.freeTimeTrend,
                    unit: "h",
                    color: Color(hex: "10B981"),
                    higherIsBetter: true
                )
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

    private func compactMetricCard(
        title: String,
        icon: String,
        current: Int,
        previous: Int,
        delta: Int,
        trend: String,
        unit: String,
        color: Color,
        higherIsBetter: Bool
    ) -> some View {
        let trendColor: Color = {
            switch trend {
            case "up": return higherIsBetter ? Color(hex: "10B981") : Color(hex: "EF4444")
            case "down": return higherIsBetter ? Color(hex: "EF4444") : Color(hex: "10B981")
            default: return Color(hex: "6B7280")
            }
        }()

        let trendIcon: String = {
            switch trend {
            case "up": return "arrow.up"
            case "down": return "arrow.down"
            default: return "minus"
            }
        }()

        return VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            // Value
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(current)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }

            // Trend
            if delta != 0 {
                HStack(spacing: 3) {
                    Image(systemName: trendIcon)
                        .font(.system(size: 9, weight: .bold))
                    Text("\(abs(delta))\(unit)")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundColor(trendColor)
            } else {
                Text("No change")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "6B7280"))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(color.opacity(0.08))
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

    // MARK: - Health Goals Section

    private func healthGoalsSection(_ healthGoals: HealthGoalSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with overall percentage
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(healthGoals.overallProgressColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(healthGoals.overallProgressColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Health Goals")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text(healthGoals.overallLabel)
                        .font(.caption.weight(.medium))
                        .foregroundColor(healthGoals.overallProgressColor)
                }

                Spacer()

                // Overall percentage ring
                ZStack {
                    Circle()
                        .stroke(healthGoals.overallProgressColor.opacity(0.2), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: min(Double(healthGoals.overallPercentage) / 100, 1))
                        .stroke(healthGoals.overallProgressColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)
                    Text("\(healthGoals.overallPercentage)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(healthGoals.overallProgressColor)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)

            // Individual goals
            VStack(spacing: DesignSystem.Spacing.sm) {
                if let sleepGoal = healthGoals.sleepGoal {
                    goalProgressRow(sleepGoal)
                }
                if let stepsGoal = healthGoals.stepsGoal {
                    goalProgressRow(stepsGoal)
                }
                if let activeGoal = healthGoals.activeMinutesGoal {
                    goalProgressRow(activeGoal)
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

    private func goalProgressRow(_ goal: GoalProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Icon
                Image(systemName: goal.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(goal.progressColor)
                    .frame(width: 20)

                Text(goal.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                // Actual vs Target
                HStack(spacing: 4) {
                    Text(goal.actual)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(goal.progressColor)
                    Text("/")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    Text(goal.target)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                // Days met badge
                HStack(spacing: 2) {
                    Text("\(goal.daysMet)/\(goal.totalDays)")
                        .font(.caption2.weight(.semibold))
                    Text("days")
                        .font(.caption2)
                }
                .foregroundColor(goal.progressColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(goal.progressColor.opacity(0.15))
                )
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(goal.progressColor.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(goal.progressColor)
                        .frame(width: geometry.size.width * min(Double(goal.percentage) / 100, 1), height: 6)
                        .animation(.easeInOut(duration: 0.5), value: goal.percentage)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(goal.progressColor.opacity(0.03))
        )
    }

    // MARK: - Time Buckets Section

    private func timeBucketsSection(_ buckets: [TimeBucket]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "3B82F6").opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "3B82F6"))
                }

                Text("Time Breakdown")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)

            // Horizontal bar chart style
            VStack(spacing: 10) {
                ForEach(buckets) { bucket in
                    timeBucketBar(bucket, maxHours: buckets.map(\.hours).max() ?? 1)
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

    private func timeBucketBar(_ bucket: TimeBucket, maxHours: Double) -> some View {
        let progress = maxHours > 0 ? bucket.hours / maxHours : 0

        return HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(bucket.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: bucket.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(bucket.color)
            }

            // Label and bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(bucket.category.capitalized)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Spacer()
                    Text(bucket.formattedHours)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(bucket.color)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(bucket.color.opacity(0.15))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(bucket.color)
                            .frame(width: geometry.size.width * progress, height: 8)
                            .animation(.easeInOut(duration: 0.5), value: progress)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(bucket.color.opacity(0.03))
        )
    }

    // MARK: - Energy Alignment Section

    private func energyAlignmentSection(_ energy: EnergyAlignment) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
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

            Text(energy.summary)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DesignSystem.Spacing.md)

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

    // MARK: - Stress Signals Section

    private func stressSignalsSection(_ signals: [StressSignal]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
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

    // MARK: - Suggestions Section

    private func suggestionsSection(_ suggestions: [WeeklySuggestion]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
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
            Text("Generating your report card...")
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

// MARK: - Flexible Drivers View

/// Displays score drivers as rows (vertical layout for full visibility)
struct FlexibleDriversView: View {
    let drivers: [ScoreDriver]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(drivers) { driver in
                driverRow(driver)
            }
        }
    }

    private func driverRow(_ driver: ScoreDriver) -> some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: driver.sfSymbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(driver.color)
                .frame(width: 16)

            // Label - full text, no truncation
            Text(driver.label)
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            // Delta badge
            Text(driver.formattedDelta)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(driver.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(driver.color.opacity(0.2))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(driver.color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(driver.color.opacity(0.15), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Next Week Forecast Section

extension WeeklyInsightsView {

    @ViewBuilder
    private var nextWeekForecastSection: some View {
        if viewModel.isLoadingForecast && viewModel.nextWeekForecast == nil {
            // Loading state
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "6366F1").opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.forward.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "6366F1"))
                    }

                    Text("Next Week Forecast")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Spacer()
                }

                ProgressView()
                    .scaleEffect(0.9)
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
        } else if let forecast = viewModel.nextWeekForecast {
            // Forecast content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "6366F1").opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.forward.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "6366F1"))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Week Forecast")
                            .font(.headline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Text(forecast.weekLabel)
                            .font(.caption.weight(.medium))
                            .foregroundColor(Color(hex: "6366F1"))
                    }

                    Spacer()

                    // Density badge
                    Text(forecast.weekMetrics.densityLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(forecast.weekMetrics.densityColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(forecast.weekMetrics.densityColor.opacity(0.15))
                        )
                }

                // Headline & Subheadline
                VStack(alignment: .leading, spacing: 6) {
                    Text(forecast.headline)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(forecast.subheadline)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Daily Forecast Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(forecast.dailyForecasts) { day in
                            dayForecastPill(day)
                        }
                    }
                }

                // Risk Signals (if any)
                if forecast.hasRisks {
                    VStack(spacing: 8) {
                        ForEach(forecast.riskSignals) { risk in
                            riskSignalRow(risk)
                        }
                    }
                }

                // Interventions (actions to take)
                if !forecast.interventions.isEmpty {
                    VStack(spacing: 8) {
                        Text("Take action now")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(hex: "10B981"))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(forecast.interventions) { intervention in
                            interventionRow(intervention)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "1E1B4B").opacity(0.3), Color(hex: "312E81").opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .stroke(Color(hex: "6366F1").opacity(0.3), lineWidth: 0.5)
                    )
            )
        }
    }

    private func dayForecastPill(_ day: DayForecast) -> some View {
        VStack(spacing: 6) {
            Text(day.shortDayName)
                .font(.caption2.weight(.bold))
                .foregroundColor(DesignSystem.Colors.secondaryText)

            ZStack {
                Circle()
                    .fill(day.intensityColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: day.intensityIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(day.intensityColor)
            }

            Text("\(day.meetingCount)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(day.intensityColor)

            Text("mtgs")
                .font(.system(size: 9))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(day.intensityColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(day.intensityColor.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private func riskSignalRow(_ risk: ForecastRiskSignal) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(risk.severityColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: risk.sfSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(risk.severityColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(risk.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text(risk.detail)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Severity badge
            Text(risk.severityLabel)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(risk.severityColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(risk.severityColor.opacity(0.15))
                )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(risk.severityColor.opacity(0.05))
        )
    }

    private func interventionRow(_ intervention: ForecastIntervention) -> some View {
        Button(action: {
            HapticManager.shared.mediumTap()
            NavigationManager.shared.handleDestination(intervention.deepLink)
        }) {
            HStack(spacing: 10) {
                Image(systemName: intervention.sfSymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "10B981"))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(intervention.action)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    Text(intervention.detail)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                // Impact badge
                Text(intervention.impactLabel)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(intervention.impactColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(intervention.impactColor.opacity(0.15))
                    )

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "10B981").opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "10B981").opacity(0.15), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    WeeklyInsightsView()
}
