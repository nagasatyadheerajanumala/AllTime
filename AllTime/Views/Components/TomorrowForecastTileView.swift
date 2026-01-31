import SwiftUI

/// Tomorrow Forecast Tile for the Today page
/// Shows a comprehensive preview of tomorrow with patterns, predictions, and recommendations
struct TomorrowForecastTileView: View {
    @StateObject private var viewModel = NextDayForecastViewModel()
    @State private var showFullForecast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content
            Button(action: { showFullForecast = true }) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    // Header with tomorrow label and intensity
                    headerSection

                    if viewModel.isLoading && !viewModel.hasForecast {
                        loadingState
                    } else if let forecast = viewModel.forecast {
                        forecastContent(forecast)
                    } else if viewModel.hasError {
                        errorState
                    } else {
                        emptyState
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .task {
            await viewModel.fetchForecast()
        }
        .sheet(isPresented: $showFullForecast) {
            NavigationView {
                DailyInsightsView(initialDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                    .navigationTitle("Daily Insights")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showFullForecast = false
                            }
                        }
                    }
            }
        }
    }

    private var borderColor: Color {
        guard let forecast = viewModel.forecast else {
            return DesignSystem.Colors.calmBorder
        }
        return forecast.intensityColor.opacity(0.3)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.amber)

                    Text("Tomorrow")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }

                Text(tomorrowDateString)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()

            if let forecast = viewModel.forecast {
                // Intensity badge
                Text(forecast.intensityLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(forecast.intensityColor)
                    )
            } else if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    private var tomorrowDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return formatter.string(from: tomorrow)
    }

    // MARK: - Forecast Content

    @ViewBuilder
    private func forecastContent(_ forecast: NextDayForecast) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Stats row
            statsRow(forecast)

            // Comparison with today (if available)
            if let comparison = forecast.comparedToToday {
                comparisonBadge(comparison)
            }

            // Prediction summary (if available)
            if let prediction = forecast.prediction {
                predictionRow(prediction)
            }

            // Top risk signal (if any)
            if let topRisk = forecast.riskSignals?.first {
                riskBadge(topRisk)
            }

            // Clara's insight (truncated)
            if let insight = forecast.claraInsight, !insight.isEmpty {
                claraInsight(insight)
            }

            // View more prompt
            viewMorePrompt
        }
    }

    // MARK: - Stats Row

    private func statsRow(_ forecast: NextDayForecast) -> some View {
        HStack(spacing: 0) {
            statItem(
                icon: "calendar",
                value: "\(forecast.meetingCount)",
                label: "Meetings",
                color: forecast.meetingCount >= 5 ? DesignSystem.Colors.amber : DesignSystem.Colors.primary
            )

            Divider()
                .frame(height: 30)
                .padding(.horizontal, 8)

            statItem(
                icon: "clock",
                value: String(format: "%.1fh", forecast.meetingHours),
                label: "In Calls",
                color: forecast.meetingHours >= 4 ? DesignSystem.Colors.amber : DesignSystem.Colors.primary
            )

            Divider()
                .frame(height: 30)
                .padding(.horizontal, 8)

            statItem(
                icon: "brain.head.profile",
                value: String(format: "%.1fh", forecast.focusHours),
                label: "Focus",
                color: forecast.focusHours >= 3 ? DesignSystem.Colors.emerald : DesignSystem.Colors.primary
            )

            Divider()
                .frame(height: 30)
                .padding(.horizontal, 8)

            statItem(
                icon: "arrow.right.arrow.left",
                value: "\(forecast.backToBackCount)",
                label: "B2B",
                color: forecast.backToBackCount >= 3 ? DesignSystem.Colors.errorRed : DesignSystem.Colors.primary
            )
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.background)
        )
    }

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Comparison Badge

    private func comparisonBadge(_ comparison: TomorrowComparison) -> some View {
        HStack(spacing: 8) {
            Image(systemName: comparison.comparisonIcon)
                .font(.system(size: 14))
                .foregroundColor(comparison.isLighter ? DesignSystem.Colors.emerald :
                               comparison.isHeavier ? DesignSystem.Colors.amber : DesignSystem.Colors.blue)

            Text(comparison.comparisonLabel)
                .font(.caption.weight(.medium))
                .foregroundColor(DesignSystem.Colors.secondaryText)

            Spacer()

            let diff = comparison.meetingCountDiff
            Text("\(diff >= 0 ? "+" : "")\(diff) meetings")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(DesignSystem.Colors.background)
        )
    }

    // MARK: - Prediction Row

    private func predictionRow(_ prediction: TomorrowDayPrediction) -> some View {
        HStack(spacing: 12) {
            // Outcome prediction
            if let outcome = prediction.predictedOutcome {
                HStack(spacing: 6) {
                    Image(systemName: prediction.outcomeIcon ?? "sun.max.fill")
                        .font(.system(size: 14))
                        .foregroundColor(prediction.outcomeColor)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(outcome)%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Text(prediction.outcomeLabel ?? "Outcome")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }
            }

            Spacer()

            // Energy prediction
            if let energy = prediction.predictedEnergy {
                HStack(spacing: 6) {
                    Image(systemName: prediction.energyIcon ?? "battery.75")
                        .font(.system(size: 14))
                        .foregroundColor(prediction.energyColor)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(energy)%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Text(prediction.energyLabel ?? "Energy")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(
                    LinearGradient(
                        colors: [DesignSystem.Colors.indigo.opacity(0.1), DesignSystem.Colors.violet.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
    }

    // MARK: - Risk Badge

    private func riskBadge(_ risk: TomorrowRiskSignal) -> some View {
        HStack(spacing: 8) {
            Image(systemName: risk.icon)
                .font(.system(size: 12))
                .foregroundColor(risk.severityColor)

            Text(risk.title)
                .font(.caption.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineLimit(1)

            Spacer()

            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(risk.severityColor.opacity(0.7))
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(risk.severityColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .stroke(risk.severityColor.opacity(0.3), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Clara's Insight

    private func claraInsight(_ insight: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.indigo)

            Text(insight)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }

    // MARK: - View More Prompt

    private var viewMorePrompt: some View {
        HStack {
            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)

                Text("Browse days")
                    .font(.caption.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.primary.opacity(0.1))
            )
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.9)
                Text("Analyzing tomorrow...")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
            Spacer()
        }
    }

    // MARK: - Error State

    private var errorState: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 20))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't load forecast")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                Button("Tap to retry") {
                    Task {
                        await viewModel.refresh()
                    }
                }
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.primary)
            }

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "sunrise")
                .font(.system(size: 20))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            VStack(alignment: .leading, spacing: 2) {
                Text("Tomorrow looks clear")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                Text("No events scheduled yet")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        TomorrowForecastTileView()
            .padding()
    }
    .background(DesignSystem.Colors.background)
    .preferredColorScheme(.dark)
}
