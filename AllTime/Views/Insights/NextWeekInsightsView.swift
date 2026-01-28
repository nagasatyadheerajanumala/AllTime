import SwiftUI

// MARK: - Next Week Insights View (Dedicated Tab)

struct NextWeekInsightsView: View {
    @StateObject private var viewModel = WeeklyNarrativeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Header
                headerSection

                // Content
                if viewModel.isLoadingPatternIntelligence && !viewModel.hasPatternData {
                    loadingView
                } else if let pattern = viewModel.patternIntelligence {
                    patternIntelligenceContent(pattern)
                } else if let forecast = viewModel.nextWeekForecast {
                    forecastContent(forecast)
                } else {
                    emptyStateView
                }

                Spacer(minLength: DesignSystem.Spacing.xl)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenMargin)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, 100)
        }
        .background(DesignSystem.Colors.background)
        .refreshable {
            await viewModel.fetchPatternIntelligence()
            await viewModel.fetchNextWeekForecast()
        }
        .task {
            async let patternTask: () = viewModel.fetchPatternIntelligence()
            async let forecastTask: () = viewModel.fetchNextWeekForecast()
            _ = await (patternTask, forecastTask)
        }
        .onDisappear {
            viewModel.cancelPendingRequests()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Week")
                        .font(.title2.weight(.bold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(nextWeekDateRange)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                // AI Badge
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Predictive")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.indigo, DesignSystem.Colors.violet],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
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

    private var nextWeekDateRange: String {
        let calendar = Calendar.current
        let today = Date()

        // Find next Monday
        let weekday = calendar.component(.weekday, from: today)
        let daysToAdd = weekday == 1 ? 1 : (9 - weekday) // Sunday = 1, need to go to next Monday
        guard let nextMonday = calendar.date(byAdding: .day, value: daysToAdd, to: today),
              let nextSunday = calendar.date(byAdding: .day, value: 6, to: nextMonday) else {
            return "Next Week"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        return "\(formatter.string(from: nextMonday)) - \(formatter.string(from: nextSunday))"
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.1)
            Text("Analyzing next week patterns...")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            Text("No data yet for next week")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Text("Check back when your calendar has events scheduled")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Pattern Intelligence Content

    @ViewBuilder
    private func patternIntelligenceContent(_ pattern: PatternIntelligenceReport) -> some View {
        // Week at a Glance
        weekAtGlanceSection(pattern)

        // Stats Row
        patternStatsRow(pattern)

        // Day Cards
        ForEach(pattern.days) { day in
            patternDayCard(day)
        }

        // Week Patterns (if any)
        if let weekPatterns = pattern.weekPatterns, !weekPatterns.isEmpty {
            weekPatternsSection(weekPatterns)
        }
    }

    // MARK: - Forecast Content (Fallback)

    @ViewBuilder
    private func forecastContent(_ forecast: NextWeekForecastResponse) -> some View {
        weekAtGlanceFallback(forecast)
        forecastStatsRow(forecast)
        ForEach(forecast.dailyForecasts) { day in
            forecastDayCard(day)
        }
    }

    // MARK: - Week at a Glance

    private func weekAtGlanceSection(_ pattern: PatternIntelligenceReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Week at a Glance")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                HStack(spacing: 12) {
                    legendDot(color: Color(hex: "10B981"), label: "Light")
                    legendDot(color: DesignSystem.Colors.blue, label: "Busy")
                    legendDot(color: Color(hex: "EF4444"), label: "Heavy")
                }
            }

            HStack(spacing: 0) {
                ForEach(pattern.days) { day in
                    VStack(spacing: 8) {
                        Text(day.shortDayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(day.isWeekend ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.secondaryText)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.intensityColor)
                            .frame(height: 8)

                        Text("\(day.meetingCount)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(day.isWeekend ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
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

    private func weekAtGlanceFallback(_ forecast: NextWeekForecastResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Week at a Glance")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                HStack(spacing: 12) {
                    legendDot(color: Color(hex: "10B981"), label: "Light")
                    legendDot(color: DesignSystem.Colors.blue, label: "Busy")
                    legendDot(color: Color(hex: "EF4444"), label: "Heavy")
                }
            }

            HStack(spacing: 0) {
                ForEach(forecast.dailyForecasts) { day in
                    VStack(spacing: 8) {
                        Text(day.shortDayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.secondaryText)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.intensityColor)
                            .frame(height: 8)

                        Text("\(day.meetingCount)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
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

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
    }

    // MARK: - Stats Row

    @ViewBuilder
    private func patternStatsRow(_ pattern: PatternIntelligenceReport) -> some View {
        let totalMeetings = pattern.weekSummary?.totalMeetings ?? pattern.days.reduce(0) { $0 + $1.meetingCount }
        let totalHours = pattern.weekSummary?.totalMeetingHours ?? pattern.days.reduce(0.0) { $0 + $1.meetingHours }
        let heavyDays = pattern.weekSummary?.heavyDays ?? pattern.days.filter { $0.intensity == "heavy" || $0.intensity == "extreme" }.count
        let lightDays = pattern.weekSummary?.lightDays ?? pattern.days.filter { $0.intensity == "light" || $0.intensity == "open" }.count

        HStack(spacing: 0) {
            statItem(icon: "calendar", value: "\(totalMeetings)", label: "Meetings")
            statItem(icon: "clock", value: String(format: "%.0fh", totalHours), label: "In Calls")
            statItem(icon: "flame.fill", value: "\(heavyDays)", label: "Heavy Days")
            statItem(icon: "sun.max.fill", value: "\(lightDays)", label: "Light Days")
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private func forecastStatsRow(_ forecast: NextWeekForecastResponse) -> some View {
        let metrics = forecast.weekMetrics
        HStack(spacing: 0) {
            statItem(icon: "calendar", value: "\(metrics.totalMeetings)", label: "Meetings")
            statItem(icon: "clock", value: String(format: "%.0fh", metrics.totalMeetingHours), label: "In Calls")
            statItem(icon: "flame.fill", value: "\(metrics.heavyDays)", label: "Heavy Days")
            statItem(icon: "sun.max.fill", value: "\(metrics.openDays)", label: "Light Days")
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                )
        )
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(DesignSystem.Colors.primary)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Day Cards

    private func patternDayCard(_ day: PatternDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.dayOfWeek)
                        .font(.headline)
                        .foregroundColor(day.isWeekend ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.primaryText)

                    Text(formatDate(day.date))
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }

                Spacer()

                // Intensity Badge
                Text(day.intensityLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(day.intensityColor)
                    )
            }

            // Stats
            HStack(spacing: 16) {
                Label("\(day.meetingCount) meetings", systemImage: "video.fill")
                Label(String(format: "%.1fh", day.meetingHours), systemImage: "clock.fill")
            }
            .font(.caption)
            .foregroundColor(DesignSystem.Colors.secondaryText)

            // AI Insight (if available)
            if let insight = day.claraInsight, !insight.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.indigo)

                    Text(insight)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(day.isWeekend ? DesignSystem.Colors.calmBorder.opacity(0.5) : DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                )
        )
        .opacity(day.isWeekend ? 0.7 : 1.0)
    }

    private func forecastDayCard(_ day: DayForecast) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.dayOfWeek)
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(formatDate(day.date))
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }

                Spacer()

                Text(day.intensityLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(day.intensityColor)
                    )
            }

            HStack(spacing: 16) {
                Label("\(day.meetingCount) meetings", systemImage: "video.fill")
                Label(String(format: "%.1fh", day.meetingHours), systemImage: "clock.fill")
            }
            .font(.caption)
            .foregroundColor(DesignSystem.Colors.secondaryText)
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

    // MARK: - Week Patterns Section

    @ViewBuilder
    private func weekPatternsSection(_ patterns: [WeekPatternItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(DesignSystem.Colors.amber)
                Text("Week Patterns")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            ForEach(patterns) { pattern in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: pattern.icon)
                        .font(.system(size: 14))
                        .foregroundColor(pattern.severityColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(pattern.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text(pattern.detail)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
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

    // MARK: - Helpers

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d"
        return outputFormatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    NextWeekInsightsView()
        .preferredColorScheme(.dark)
}
