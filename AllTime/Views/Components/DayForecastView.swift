import SwiftUI
import Combine

/// Displays the daily intelligence forecast
struct DayForecastCardView: View {
    @StateObject private var viewModel = DayForecastViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.purple)

                Text("Today's Forecast")
                    .font(.headline)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if let forecast = viewModel.forecast {
                // Risk Level Badge
                HStack(spacing: 8) {
                    RiskBadge(level: forecast.dayRiskLevel, score: forecast.dayRiskScore)

                    if let weather = forecast.weatherSummary {
                        WeatherBadge(summary: weather, impact: forecast.weatherImpact)
                    }
                }

                // Energy Forecast
                if let energy = forecast.energyForecast {
                    EnergyTimelineView(forecast: energy)
                }

                // Calendar Summary
                if let summary = forecast.calendarSummary {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text(summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Best Times
                BestTimesView(
                    focusTime: forecast.formattedBestFocusTime,
                    meetingTime: forecast.formattedBestMeetingTime,
                    breakTime: forecast.formattedBestBreakTime
                )

                // Recommendations
                if let recommendations = forecast.recommendations, !recommendations.isEmpty {
                    RecommendationsView(recommendations: Array(recommendations.prefix(2)))
                }

            } else if let error = viewModel.error {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Loading forecast...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .task {
            await viewModel.loadForecast()
        }
    }
}

// MARK: - Risk Badge

struct RiskBadge: View {
    let level: String
    let score: Double

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(riskColor)
                .frame(width: 8, height: 8)

            Text("\(level.capitalized) Risk")
                .font(.caption.bold())
                .foregroundColor(riskColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(riskColor.opacity(0.15))
        )
    }

    var riskColor: Color {
        switch level {
        case "high": return .red
        case "medium": return .orange
        default: return .green
        }
    }
}

// MARK: - Weather Badge

struct WeatherBadge: View {
    let summary: String
    let impact: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: weatherIcon)
                .font(.caption)
            Text(summary)
                .font(.caption)
        }
        .foregroundColor(.secondary)
    }

    var weatherIcon: String {
        if summary.lowercased().contains("rain") { return "cloud.rain.fill" }
        if summary.lowercased().contains("snow") { return "cloud.snow.fill" }
        if summary.lowercased().contains("cloud") { return "cloud.fill" }
        if summary.lowercased().contains("storm") { return "cloud.bolt.fill" }
        return "sun.max.fill"
    }
}

// MARK: - Energy Timeline

struct EnergyTimelineView: View {
    let forecast: EnergyForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Energy Forecast")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                EnergyPeriod(period: "Morning", level: forecast.morningEnergy)
                EnergyPeriod(period: "Afternoon", level: forecast.afternoonEnergy)
                EnergyPeriod(period: "Evening", level: forecast.eveningEnergy)
            }
        }
        .padding(.vertical, 8)
    }
}

struct EnergyPeriod: View {
    let period: String
    let level: Int?

    var body: some View {
        VStack(spacing: 4) {
            // Energy bars
            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i <= (level ?? 0) ? energyColor : Color.gray.opacity(0.2))
                        .frame(width: 6, height: 16)
                }
            }

            Text(period)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    var energyColor: Color {
        guard let level = level else { return .gray }
        switch level {
        case 1...2: return .red
        case 3: return .yellow
        case 4...5: return .green
        default: return .gray
        }
    }
}

// MARK: - Best Times

struct BestTimesView: View {
    let focusTime: String?
    let meetingTime: String?
    let breakTime: String?

    var body: some View {
        HStack(spacing: 12) {
            if let focus = focusTime {
                TimeSlot(icon: "brain", label: "Focus", time: focus)
            }
            if let meeting = meetingTime {
                TimeSlot(icon: "person.2", label: "Meetings", time: meeting)
            }
            if let breakTime = breakTime {
                TimeSlot(icon: "cup.and.saucer", label: "Break", time: breakTime)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TimeSlot: View {
    let icon: String
    let label: String
    let time: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            Text(time)
                .font(.caption2.bold())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recommendations

struct RecommendationsView: View {
    let recommendations: [Recommendation]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(recommendations) { rec in
                HStack(spacing: 8) {
                    Image(systemName: rec.categoryIcon)
                        .font(.caption)
                        .foregroundColor(priorityColor(rec.priority))

                    Text(rec.title)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.top, 4)
    }

    func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "high": return .red
        case "medium": return .orange
        default: return .blue
        }
    }
}

// MARK: - ViewModel

@MainActor
class DayForecastViewModel: ObservableObject {
    @Published var forecast: DailyForecast?
    @Published var isLoading = false
    @Published var error: String?

    func loadForecast() async {
        isLoading = true
        error = nil

        do {
            forecast = try await IntelligenceService.shared.getDailyForecast()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    DayForecastCardView()
        .padding()
        .background(Color(.systemGroupedBackground))
}
