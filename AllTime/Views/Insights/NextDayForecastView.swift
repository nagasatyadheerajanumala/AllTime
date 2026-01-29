import SwiftUI

// MARK: - Next Day (Tomorrow) Forecast View

struct NextDayForecastView: View {
    @StateObject private var viewModel = NextDayForecastViewModel()
    @State private var showSimilarDays = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Header
                headerSection

                // Content
                if viewModel.isLoading && !viewModel.hasForecast {
                    loadingView
                } else if let forecast = viewModel.forecast {
                    forecastContent(forecast)
                } else if viewModel.hasError {
                    errorView
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
            await viewModel.refresh()
        }
        .task {
            await viewModel.fetchForecast()
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
                    Text("Tomorrow")
                        .font(.title2.weight(.bold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(tomorrowDateString)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                // AI Badge
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Forecast")
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

    private var tomorrowDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return formatter.string(from: tomorrow)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.1)
            Text("Analyzing tomorrow's patterns...")
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
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            Text("Couldn't load forecast")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            Button("Try Again") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sunrise")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            Text("No forecast available")
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

    // MARK: - Forecast Content

    @ViewBuilder
    private func forecastContent(_ forecast: NextDayForecast) -> some View {
        // Headline Card
        headlineCard(forecast)

        // Comparison with Today
        if let comparison = forecast.comparedToToday {
            comparisonCard(comparison)
        }

        // Stats Row
        statsRow(forecast)

        // Prediction Card
        if let prediction = forecast.prediction {
            predictionCard(prediction, sleepRec: forecast.sleepRecommendation)
        }

        // Risk Signals
        if forecast.hasRisks {
            riskSignalsSection(forecast.riskSignals ?? [])
        }

        // Interventions
        if let interventions = forecast.interventions, !interventions.isEmpty {
            interventionsSection(interventions)
        }

        // Similar Days
        if forecast.hasSimilarDays {
            similarDaysSection(forecast.similarDays ?? [])
        }

        // Clara's Insight
        if let insight = forecast.claraInsight, !insight.isEmpty {
            claraInsightCard(insight)
        }
    }

    // MARK: - Headline Card

    private func headlineCard(_ forecast: NextDayForecast) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: forecast.intensityIcon)
                    .font(.system(size: 24))
                    .foregroundColor(forecast.intensityColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(forecast.headline)
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    if let subheadline = forecast.subheadline {
                        Text(subheadline)
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
            }

            // Intensity Badge
            HStack {
                Text(forecast.intensityLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(forecast.intensityColor)
                    )

                Spacer()

                if let firstTime = forecast.firstMeetingTime, let lastTime = forecast.lastMeetingTime {
                    Text("\(firstTime) - \(lastTime)")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(forecast.intensityColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Comparison Card

    private func comparisonCard(_ comparison: TomorrowComparison) -> some View {
        HStack(spacing: 12) {
            Image(systemName: comparison.comparisonIcon)
                .font(.system(size: 20))
                .foregroundColor(comparison.isLighter ? .green : comparison.isHeavier ? .orange : .blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(comparison.comparisonLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                let diff = comparison.meetingCountDiff
                let hoursDiff = comparison.meetingHoursDiff
                Text("\(diff >= 0 ? "+" : "")\(diff) meetings, \(hoursDiff >= 0 ? "+" : "")\(String(format: "%.1f", hoursDiff))h")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()
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

    // MARK: - Stats Row

    private func statsRow(_ forecast: NextDayForecast) -> some View {
        HStack(spacing: 0) {
            statItem(icon: "calendar", value: "\(forecast.meetingCount)", label: "Meetings")
            statItem(icon: "clock", value: String(format: "%.1fh", forecast.meetingHours), label: "In Calls")
            statItem(icon: "brain.head.profile", value: String(format: "%.1fh", forecast.focusHours), label: "Focus")
            statItem(icon: "arrow.right.arrow.left", value: "\(forecast.backToBackCount)", label: "Back-to-Back")
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
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.primary)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Prediction Card

    private func predictionCard(_ prediction: TomorrowDayPrediction, sleepRec: TomorrowSleepRecommendation?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(DesignSystem.Colors.indigo)
                Text("Prediction")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                if let confidence = prediction.confidence {
                    Text(confidence.capitalized + " confidence")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }

            HStack(spacing: 16) {
                // Outcome Prediction
                if let outcome = prediction.predictedOutcome {
                    VStack(alignment: .center, spacing: 4) {
                        Image(systemName: prediction.outcomeIcon ?? "sun.max.fill")
                            .font(.system(size: 24))
                            .foregroundColor(prediction.outcomeColor)

                        Text("\(outcome)%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text(prediction.outcomeLabel ?? "Outcome")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Energy Prediction
                if let energy = prediction.predictedEnergy {
                    VStack(alignment: .center, spacing: 4) {
                        Image(systemName: prediction.energyIcon ?? "battery.75")
                            .font(.system(size: 24))
                            .foregroundColor(prediction.energyColor)

                        Text("\(energy)%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text(prediction.energyLabel ?? "Energy")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Sleep Recommendation
            if let sleepRec = sleepRec {
                Divider()

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: sleepRec.icon ?? "bed.double.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.violet)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(sleepRec.recommendation)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        if let reason = sleepRec.reason {
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
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

    // MARK: - Risk Signals Section

    private func riskSignalsSection(_ signals: [TomorrowRiskSignal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Watch Out")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            ForEach(signals) { signal in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: signal.icon)
                        .font(.system(size: 14))
                        .foregroundColor(signal.severityColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(signal.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text(signal.detail)
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
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Interventions Section

    private func interventionsSection(_ interventions: [TomorrowIntervention]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(DesignSystem.Colors.emerald)
                Text("Actions to Take")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            ForEach(interventions) { intervention in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: intervention.icon)
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(intervention.action)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text(intervention.detail)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    Spacer()

                    if intervention.deepLink != nil {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if let deepLink = intervention.deepLink, let url = URL(string: deepLink) {
                        UIApplication.shared.open(url)
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

    // MARK: - Similar Days Section

    private func similarDaysSection(_ days: [TomorrowSimilarDayMatch]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { showSimilarDays.toggle() }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(DesignSystem.Colors.blue)
                    Text("Similar Past Days")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Spacer()

                    Text("\(days.count) matches")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)

                    Image(systemName: showSimilarDays ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }

            if showSimilarDays {
                ForEach(days) { day in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.dayOfWeek)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(DesignSystem.Colors.primaryText)

                            Text(formatDate(day.date))
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(day.similarityScore)% match")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(DesignSystem.Colors.blue)

                            Text(day.outcomeLabel)
                                .font(.caption)
                                .foregroundColor(day.outcomeColor)
                        }
                    }
                    .padding(.vertical, 4)

                    if day.id != days.last?.id {
                        Divider()
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

    // MARK: - Clara's Insight Card

    private func claraInsightCard(_ insight: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(DesignSystem.Colors.indigo)
                Text("Clara's Take")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            Text(insight)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(
                            LinearGradient(
                                colors: [DesignSystem.Colors.indigo.opacity(0.5), DesignSystem.Colors.violet.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
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

// MARK: - Tomorrow Forecast Card (for embedding in other views)

struct TomorrowForecastCard: View {
    @StateObject private var viewModel = NextDayForecastViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tomorrow")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    if let forecast = viewModel.forecast {
                        Text(forecast.intensityLabel)
                            .font(.caption)
                            .foregroundColor(forecast.intensityColor)
                    }
                }

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let forecast = viewModel.forecast {
                    Image(systemName: forecast.intensityIcon)
                        .font(.system(size: 20))
                        .foregroundColor(forecast.intensityColor)
                }
            }

            if let forecast = viewModel.forecast {
                // Stats
                HStack(spacing: 16) {
                    Label("\(forecast.meetingCount) meetings", systemImage: "video.fill")
                    Label(String(format: "%.1fh", forecast.meetingHours), systemImage: "clock.fill")
                }
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)

                // Clara's insight (short)
                if let insight = forecast.claraInsight {
                    Text(insight)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(2)
                }
            } else if viewModel.hasError {
                Text("Couldn't load forecast")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
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
        .task {
            await viewModel.fetchForecast()
        }
    }
}

// MARK: - Preview

#Preview {
    NextDayForecastView()
        .preferredColorScheme(.dark)
}
