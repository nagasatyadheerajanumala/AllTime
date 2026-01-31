import SwiftUI

// MARK: - Next Day (Tomorrow) Forecast View

struct NextDayForecastView: View {
    @StateObject private var viewModel = NextDayForecastViewModel()
    @State private var showSimilarDays = false
    @State private var showRisks = true
    @State private var showInterventions = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
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

    private var tomorrowDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return formatter.string(from: tomorrow)
    }

    private var shortDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return formatter.string(from: tomorrow).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
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
        // Hero Section (like Balance Score in Weekly Insights)
        heroSection(forecast)

        // Day Overview Card
        dayOverviewCard(forecast)

        // Stats Grid (like Metrics Comparison in Weekly Insights)
        statsGridSection(forecast)

        // Prediction Card with outcome/energy
        if let prediction = forecast.prediction {
            predictionSection(prediction, sleepRec: forecast.sleepRecommendation)
        }

        // Risk Signals (expandable)
        if forecast.hasRisks {
            riskSignalsSection(forecast.riskSignals ?? [])
        }

        // Interventions (expandable)
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

    // MARK: - Hero Section (Balance Score Style)

    private func heroSection(_ forecast: NextDayForecast) -> some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Intensity Gauge Ring
            IntensityGaugeRing(
                intensity: forecast.intensity,
                meetingHours: forecast.meetingHours,
                size: 140
            )
            .padding(.top, DesignSystem.Spacing.md)

            // Date and intensity label
            VStack(spacing: 4) {
                Text("Tomorrow")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)

                Text(tomorrowDateString)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }

            // Intensity badge
            HStack(spacing: 8) {
                Circle()
                    .fill(forecast.intensityColor)
                    .frame(width: 10, height: 10)
                Text(forecast.intensityLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(forecast.intensityColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(forecast.intensityColor.opacity(0.15))
            )

            // Comparison with today
            if let comparison = forecast.comparedToToday {
                comparisonBadge(comparison)
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

    private func comparisonBadge(_ comparison: TomorrowComparison) -> some View {
        HStack(spacing: 6) {
            Image(systemName: comparison.comparisonIcon)
                .font(.system(size: 12, weight: .semibold))
            Text(comparison.comparisonLabel)
                .font(.caption.weight(.medium))
        }
        .foregroundColor(comparison.isLighter ? DesignSystem.Colors.emerald : comparison.isHeavier ? DesignSystem.Colors.amber : .white.opacity(0.7))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(comparison.isLighter ? DesignSystem.Colors.emerald.opacity(0.15) :
                      comparison.isHeavier ? DesignSystem.Colors.amber.opacity(0.15) :
                      Color.white.opacity(0.1))
        )
    }

    // MARK: - Day Overview Card

    private func dayOverviewCard(_ forecast: NextDayForecast) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: forecast.intensityIcon)
                    .font(.title2)
                    .foregroundColor(forecast.intensityColor)
                Text(forecast.headline)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            if let subheadline = forecast.subheadline {
                Text(subheadline)
                    .font(.body)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }

            // Time range
            if let firstTime = forecast.firstMeetingTime, let lastTime = forecast.lastMeetingTime {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("\(firstTime) - \(lastTime)")
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .padding(.top, 4)
            }
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

    // MARK: - Stats Grid Section

    private func statsGridSection(_ forecast: NextDayForecast) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.blue.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.blue)
                }

                Text("Day Metrics")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)

            // 2x2 Grid of metrics
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                metricCard(
                    icon: "calendar",
                    value: "\(forecast.meetingCount)",
                    label: "Meetings",
                    color: DesignSystem.Colors.blue
                )

                metricCard(
                    icon: "clock.fill",
                    value: String(format: "%.1fh", forecast.meetingHours),
                    label: "In Calls",
                    color: DesignSystem.Colors.violet
                )

                metricCard(
                    icon: "brain.head.profile",
                    value: String(format: "%.1fh", forecast.focusHours),
                    label: "Focus Time",
                    color: DesignSystem.Colors.emerald
                )

                metricCard(
                    icon: "arrow.right.arrow.left",
                    value: "\(forecast.backToBackCount)",
                    label: "Back-to-Back",
                    color: forecast.backToBackCount > 2 ? DesignSystem.Colors.amber : DesignSystem.Colors.secondaryText
                )
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

    private func metricCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(color.opacity(0.05))
        )
    }

    // MARK: - Prediction Section

    private func predictionSection(_ prediction: TomorrowDayPrediction, sleepRec: TomorrowSleepRecommendation?) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.indigo.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.indigo)
                }

                Text("Prediction")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                if let confidence = prediction.confidence {
                    Text(confidence.capitalized)
                        .font(.caption.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
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

            // Prediction cards row
            HStack(spacing: 12) {
                // Outcome Prediction
                if let outcome = prediction.predictedOutcome {
                    predictionMetricCard(
                        icon: prediction.outcomeIcon ?? "sun.max.fill",
                        value: "\(outcome)%",
                        label: prediction.outcomeLabel ?? "Good Day",
                        color: prediction.outcomeColor
                    )
                }

                // Energy Prediction
                if let energy = prediction.predictedEnergy {
                    predictionMetricCard(
                        icon: prediction.energyIcon ?? "battery.75",
                        value: "\(energy)%",
                        label: prediction.energyLabel ?? "Energy",
                        color: prediction.energyColor
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)

            // Sleep Recommendation
            if let sleepRec = sleepRec {
                Divider()
                    .padding(.horizontal, DesignSystem.Spacing.md)

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
                .padding(.horizontal, DesignSystem.Spacing.md)
            }

            Spacer(minLength: DesignSystem.Spacing.md)
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

    private func predictionMetricCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(color.opacity(0.08))
        )
    }

    // MARK: - Risk Signals Section (Expandable)

    private func riskSignalsSection(_ signals: [TomorrowRiskSignal]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (tappable to expand/collapse)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showRisks.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.amber.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.amber)
                    }

                    Text("Watch Out")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Spacer()

                    Text("\(signals.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.amber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.amber.opacity(0.1))
                        )

                    Image(systemName: showRisks ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(DesignSystem.Spacing.md)

            // Expandable content
            if showRisks {
                Divider()
                    .padding(.horizontal, DesignSystem.Spacing.md)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(signals) { signal in
                        riskSignalRow(signal)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.md)
            }
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

    private func riskSignalRow(_ signal: TomorrowRiskSignal) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: signal.icon)
                .font(.system(size: 14))
                .foregroundColor(signal.severityColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(signal.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text(signal.detail)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.amber.opacity(0.05))
        )
    }

    // MARK: - Interventions Section (Expandable)

    private func interventionsSection(_ interventions: [TomorrowIntervention]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showInterventions.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.emerald.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.emerald)
                    }

                    Text("Actions to Take")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Spacer()

                    Text("\(interventions.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.emerald)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.emerald.opacity(0.1))
                        )

                    Image(systemName: showInterventions ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(DesignSystem.Spacing.md)

            // Expandable content
            if showInterventions {
                Divider()
                    .padding(.horizontal, DesignSystem.Spacing.md)

                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(interventions) { intervention in
                        interventionRow(intervention)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.md)
            }
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

    private func interventionRow(_ intervention: TomorrowIntervention) -> some View {
        Button(action: {
            if let deepLink = intervention.deepLink, let url = URL(string: deepLink) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: intervention.icon)
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.emerald)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(intervention.action)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(intervention.detail)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if intervention.deepLink != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.emerald.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .stroke(DesignSystem.Colors.emerald.opacity(0.1), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Intensity Gauge Ring (like Balance Score Ring)

struct IntensityGaugeRing: View {
    let intensity: String  // "light", "moderate", "busy", "heavy"
    let meetingHours: Double
    let size: CGFloat

    private var progress: Double {
        // Convert meeting hours to 0-1 scale (0-8+ hours)
        min(meetingHours / 8.0, 1.0)
    }

    private var intensityColor: Color {
        switch intensity.lowercased() {
        case "light", "free":
            return Color(hex: "10B981") // Green
        case "moderate":
            return DesignSystem.Colors.blue
        case "busy", "full":
            return DesignSystem.Colors.amber
        case "heavy", "overloaded":
            return Color(hex: "EF4444") // Red
        default:
            return DesignSystem.Colors.blue
        }
    }

    private var intensityIcon: String {
        switch intensity.lowercased() {
        case "light", "free":
            return "sun.max.fill"
        case "moderate":
            return "cloud.sun.fill"
        case "busy", "full":
            return "cloud.fill"
        case "heavy", "overloaded":
            return "cloud.bolt.fill"
        default:
            return "calendar"
        }
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 12)
                .frame(width: size, height: size)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    intensityColor,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: progress)

            // Inner glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [intensityColor.opacity(0.2), .clear],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size - 24, height: size - 24)

            // Center content
            VStack(spacing: 4) {
                Image(systemName: intensityIcon)
                    .font(.system(size: size * 0.2, weight: .semibold))
                    .foregroundColor(intensityColor)

                Text(String(format: "%.1fh", meetingHours))
                    .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("meetings")
                    .font(.system(size: size * 0.08, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NextDayForecastView()
        .preferredColorScheme(.dark)
}
