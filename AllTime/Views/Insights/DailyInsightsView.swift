import SwiftUI
import Combine

/// Daily Insights View with date navigation
/// Shows day forecasts with left/right arrows to navigate between days
/// Defaults to TODAY - navigate right to see Tomorrow with detailed patterns
struct DailyInsightsView: View {
    @StateObject private var viewModel = DailyInsightsViewModel()
    @State private var selectedDate: Date

    init(initialDate: Date = Date()) {
        // Default to today - user navigates right to see tomorrow
        _selectedDate = State(initialValue: initialDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date navigation header
            dateNavigationHeader

            // Content
            if viewModel.isLoading && viewModel.forecast == nil {
                loadingView
            } else if let forecast = viewModel.forecast {
                forecastContent(forecast)
            } else if viewModel.hasError {
                errorView
            } else {
                emptyView
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            Task {
                await viewModel.fetchForecast(for: newDate)
            }
        }
        .task {
            await viewModel.fetchForecast(for: selectedDate)
        }
    }

    // MARK: - Date Navigation Header

    private var dateNavigationHeader: some View {
        VStack(spacing: 12) {
            // Main navigation row
            HStack(spacing: 0) {
                // Left arrow - go to previous day
                Button(action: goToPreviousDay) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 28))
                        Text("Previous")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(minWidth: 100)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                // Date display
                VStack(spacing: 4) {
                    Text(dayLabel)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                // Right arrow - go to next day (TOMORROW)
                Button(action: goToNextDay) {
                    HStack(spacing: 6) {
                        Text(nextDayLabel)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 28))
                    }
                    .foregroundColor(canGoForward ? DesignSystem.Colors.primary : DesignSystem.Colors.tertiaryText)
                    .frame(minWidth: 100)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canGoForward)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)

            // Navigation hint when on Today
            if isToday {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 12))
                    Text("Tap \"Tomorrow\" to see tomorrow's forecast →")
                        .font(.caption)
                }
                .foregroundColor(DesignSystem.Colors.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.primary.opacity(0.12))
                )
            }
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
    }

    private var isToday: Bool {
        Calendar.current.isDate(selectedDate, inSameDayAs: Date())
    }

    private var nextDayLabel: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selected = calendar.startOfDay(for: selectedDate)

        if calendar.isDate(selected, inSameDayAs: today) {
            return "Tomorrow"
        } else {
            return "Next"
        }
    }

    private var dayLabel: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selected = calendar.startOfDay(for: selectedDate)

        if calendar.isDate(selected, inSameDayAs: today) {
            return "Today"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
                  calendar.isDate(selected, inSameDayAs: tomorrow) {
            return "Tomorrow"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  calendar.isDate(selected, inSameDayAs: yesterday) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: selectedDate)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: selectedDate)
    }

    private var canGoForward: Bool {
        // Allow navigation up to 14 days in the future
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let today = calendar.startOfDay(for: Date())
        guard let maxDate = calendar.date(byAdding: .day, value: 14, to: today) else {
            return true // Default to allowing navigation
        }
        return selectedDay < maxDate
    }

    private func goToPreviousDay() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
                selectedDate = newDate
            }
        }
        HapticManager.shared.lightTap()
    }

    private func goToNextDay() {
        guard canGoForward else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            if let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                selectedDate = newDate
            }
        }
        HapticManager.shared.lightTap()
    }

    // MARK: - Forecast Content

    @ViewBuilder
    private func forecastContent(_ forecast: NextDayForecast) -> some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Use the existing NextDayForecastView components
                // Headline card
                headlineCard(forecast)

                // Stats row
                statsRow(forecast)

                // Comparison card (if available)
                if let comparison = forecast.comparedToToday {
                    comparisonCard(comparison)
                }

                // Prediction card (if available)
                if let prediction = forecast.prediction {
                    predictionCard(prediction)
                }

                // Risk signals
                if let risks = forecast.riskSignals, !risks.isEmpty {
                    riskSignalsSection(risks)
                }

                // Interventions
                if let interventions = forecast.interventions, !interventions.isEmpty {
                    interventionsSection(interventions)
                }

                // Similar days
                if let similarDays = forecast.similarDays, !similarDays.isEmpty {
                    similarDaysSection(similarDays)
                }

                // Clara's insight
                if let insight = forecast.claraInsight, !insight.isEmpty {
                    claraInsightCard(insight)
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .refreshable {
            await viewModel.fetchForecast(for: selectedDate, forceRefresh: true)
        }
    }

    // MARK: - Headline Card

    private func headlineCard(_ forecast: NextDayForecast) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(forecast.headline)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                Text(forecast.intensityLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(forecast.intensityColor)
                    )
            }

            if let subheadline = forecast.subheadline {
                Text(subheadline)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
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

    // MARK: - Stats Row

    private func statsRow(_ forecast: NextDayForecast) -> some View {
        HStack(spacing: 0) {
            statItem(icon: "calendar", value: "\(forecast.meetingCount)", label: "Meetings",
                     color: forecast.meetingCount >= 5 ? DesignSystem.Colors.amber : DesignSystem.Colors.primary)

            Divider().frame(height: 40)

            statItem(icon: "clock", value: String(format: "%.1fh", forecast.meetingHours), label: "In Calls",
                     color: forecast.meetingHours >= 4 ? DesignSystem.Colors.amber : DesignSystem.Colors.primary)

            Divider().frame(height: 40)

            statItem(icon: "brain.head.profile", value: String(format: "%.1fh", forecast.focusHours), label: "Focus",
                     color: forecast.focusHours >= 3 ? DesignSystem.Colors.emerald : DesignSystem.Colors.primary)

            Divider().frame(height: 40)

            statItem(icon: "arrow.right.arrow.left", value: "\(forecast.backToBackCount)", label: "Back-to-Back",
                     color: forecast.backToBackCount >= 3 ? DesignSystem.Colors.errorRed : DesignSystem.Colors.primary)
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Comparison Card

    private func comparisonCard(_ comparison: TomorrowComparison) -> some View {
        HStack(spacing: 12) {
            Image(systemName: comparison.comparisonIcon)
                .font(.system(size: 24))
                .foregroundColor(comparison.isLighter ? DesignSystem.Colors.emerald :
                               comparison.isHeavier ? DesignSystem.Colors.amber : DesignSystem.Colors.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(comparison.comparisonLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                let diff = comparison.meetingCountDiff
                Text("\(diff >= 0 ? "+" : "")\(diff) meetings vs previous day")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Prediction Card

    private func predictionCard(_ prediction: TomorrowDayPrediction) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.violet)
                Text("Pattern Prediction")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            HStack(spacing: DesignSystem.Spacing.lg) {
                if let outcome = prediction.predictedOutcome {
                    VStack(spacing: 4) {
                        Text("\(outcome)%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(prediction.outcomeColor)
                        Text(prediction.outcomeLabel ?? "Outcome")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                if let energy = prediction.predictedEnergy {
                    VStack(spacing: 4) {
                        Text("\(energy)%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(prediction.energyColor)
                        Text(prediction.energyLabel ?? "Energy")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [DesignSystem.Colors.indigo.opacity(0.1), DesignSystem.Colors.violet.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    // MARK: - Risk Signals Section

    private func riskSignalsSection(_ risks: [TomorrowRiskSignal]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Heads Up")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .padding(.horizontal, 4)

            ForEach(risks, id: \.id) { risk in
                HStack(spacing: 12) {
                    Image(systemName: risk.icon)
                        .font(.system(size: 16))
                        .foregroundColor(risk.severityColor)
                        .frame(width: 32, height: 32)
                        .background(risk.severityColor.opacity(0.15))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(risk.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Text(risk.detail)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
        }
    }

    // MARK: - Interventions Section

    private func interventionsSection(_ interventions: [TomorrowIntervention]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Suggested Actions")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .padding(.horizontal, 4)

            ForEach(interventions, id: \.id) { intervention in
                HStack(spacing: 12) {
                    Image(systemName: intervention.icon)
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .frame(width: 32, height: 32)
                        .background(DesignSystem.Colors.primary.opacity(0.15))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(intervention.action)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(DesignSystem.Colors.primaryText)

                            // Time context badge
                            if let timeLabel = intervention.timeLabel {
                                Text(timeLabel)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(timeContextColor(intervention.timeContext))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(timeContextColor(intervention.timeContext).opacity(0.15))
                                    )
                            }
                        }

                        Text(intervention.detail)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineLimit(2)
                    }

                    Spacer()

                    if intervention.deepLink != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
        }
    }

    private func timeContextColor(_ context: String?) -> Color {
        switch context {
        case "morning": return DesignSystem.Colors.amber
        case "afternoon": return DesignSystem.Colors.blue
        case "evening": return DesignSystem.Colors.indigo
        case "midday": return DesignSystem.Colors.emerald
        default: return DesignSystem.Colors.primary
        }
    }

    // MARK: - Similar Days Section

    private func similarDaysSection(_ similarDays: [TomorrowSimilarDayMatch]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Similar Days in Your History")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .padding(.horizontal, 4)

            ForEach(Array(similarDays.prefix(3)), id: \.date) { day in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.dayOfWeek.capitalized)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Text("\(day.meetingCount) meetings • \(day.outcomeLabel)")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    Spacer()

                    Text("\(day.similarityScore)%")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.primary.opacity(0.15))
                        )
                }
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
        }
    }

    // MARK: - Clara's Insight Card

    private func claraInsightCard(_ insight: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.indigo)
                Text("Clara's Take")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.indigo)
            }

            Text(insight)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.indigo.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Analyzing \(dayLabel.lowercased())...")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Spacer()
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(DesignSystem.Colors.amber)

            Text("Couldn't load forecast")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            Button("Try Again") {
                Task {
                    await viewModel.fetchForecast(for: selectedDate, forceRefresh: true)
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(DesignSystem.Colors.primary)

            Spacer()
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            Text("No data available")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Select a different date")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)

            Spacer()
        }
    }
}

// MARK: - ViewModel

@MainActor
class DailyInsightsViewModel: ObservableObject {
    @Published var forecast: NextDayForecast?
    @Published var isLoading = false
    @Published var hasError = false

    private let apiService = APIService.shared

    func fetchForecast(for date: Date, forceRefresh: Bool = false) async {
        isLoading = true
        hasError = false

        do {
            let response = try await apiService.getDayForecast(date: date)
            forecast = response
            isLoading = false
        } catch {
            print("DailyInsightsViewModel: Error fetching forecast - \(error.localizedDescription)")
            isLoading = false
            if forecast == nil {
                hasError = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DailyInsightsView()
        .preferredColorScheme(.dark)
}
