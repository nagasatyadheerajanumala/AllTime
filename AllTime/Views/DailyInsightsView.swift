import SwiftUI
import Combine

/// Comprehensive Daily Insights View for evening notification destination
/// Shows a summary of the user's day including time breakdown, health, and highlights
struct DailyInsightsView: View {
    @StateObject private var viewModel = DailyInsightsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        loadingView
                    } else if let error = viewModel.error {
                        errorView(error)
                    } else if let insights = viewModel.insights {
                        insightsContent(insights)
                    } else {
                        emptyView
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Your Day")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadInsights()
            }
            .refreshable {
                await viewModel.loadInsights()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading your day summary...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text(error)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await viewModel.loadInsights()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No summary available")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Check back later for your daily insights")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Insights Content

    @ViewBuilder
    private func insightsContent(_ insights: DailyInsightsSummary) -> some View {
        // Header with date and day tone
        headerCard(insights)

        // Activity Completion Card (if user has planned activities)
        if let completion = insights.completion, completion.hasActivities {
            completionCard(completion)
        }

        // Narrative Summary
        summaryCard(insights.summaryMessage)

        // Time Breakdown
        if let timeBreakdown = insights.timeBreakdown {
            timeBreakdownCard(timeBreakdown)
        }

        // Event Stats
        if let eventStats = insights.eventStats {
            eventStatsCard(eventStats)
        }

        // Health Metrics
        if let health = insights.health, health.hasData {
            healthCard(health)
        }

        // Highlights
        if let highlights = insights.highlights, !highlights.isEmpty {
            highlightsCard(highlights)
        }

        // Optional: Reflection prompt (for users who want to reflect)
        reflectionPromptCard
    }

    // MARK: - Completion Card

    private func completionCard(_ completion: DailyInsightsSummary.CompletionStats) -> some View {
        VStack(spacing: 16) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: CGFloat(completion.completionPercentage) / 100.0)
                    .stroke(
                        completionColor(for: completion.completionPercentage),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: completion.completionPercentage)

                VStack(spacing: 4) {
                    Text("\(completion.completionPercentage)%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 120)

            // Summary message
            if let message = completion.summaryMessage {
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }

            // Stats row
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(completion.totalCompleted)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Done")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(completion.totalPlanned - completion.totalCompleted)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("Missed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 4) {
                    Text("\(completion.totalPlanned)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Planned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private func completionColor(for percentage: Int) -> Color {
        if percentage >= 75 {
            return .green
        } else if percentage >= 50 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Header Card

    private func headerCard(_ insights: DailyInsightsSummary) -> some View {
        VStack(spacing: 8) {
            Text(insights.dayOfWeek)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(formatDate(insights.date))
                .font(.title2)
                .fontWeight(.bold)

            // Day Tone Badge
            HStack(spacing: 6) {
                Image(systemName: dayToneIcon(insights.dayTone))
                    .foregroundColor(dayToneColor(insights.dayTone))
                Text(insights.dayTone.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(dayToneColor(insights.dayTone))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(dayToneColor(insights.dayTone).opacity(0.15))
            .cornerRadius(20)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Summary Card

    private func summaryCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.quote")
                    .foregroundColor(.blue)
                Text("Summary")
                    .font(.headline)
            }

            Text(message)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Time Breakdown Card

    private func timeBreakdownCard(_ breakdown: DailyInsightsSummary.TimeBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.purple)
                Text("Time Breakdown")
                    .font(.headline)
            }

            // Visual bar chart
            VStack(spacing: 12) {
                timeBar(label: "Meetings", hours: breakdown.meetingHours, color: .red, maxHours: 8)
                timeBar(label: "Focus", hours: breakdown.focusHours, color: .blue, maxHours: 8)
                timeBar(label: "Personal", hours: breakdown.personalHours, color: .green, maxHours: 8)
                timeBar(label: "Free", hours: breakdown.freeHours, color: .gray.opacity(0.5), maxHours: 8)
            }

            // Total
            HStack {
                Text("Total Scheduled")
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatHours(breakdown.totalScheduledHours))
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private func timeBar(label: String, hours: Double, color: Color, maxHours: Double) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(hours / maxHours)))
                }
            }
            .frame(height: 8)

            Text(formatHours(hours))
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 40, alignment: .trailing)
        }
    }

    // MARK: - Event Stats Card

    private func eventStatsCard(_ stats: DailyInsightsSummary.EventStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.orange)
                Text("Events")
                    .font(.headline)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                statBubble(value: "\(stats.totalEvents)", label: "Total", color: .blue)
                statBubble(value: "\(stats.meetings)", label: "Meetings", color: .red)
                statBubble(value: "\(stats.focusBlocks)", label: "Focus", color: .purple)
            }

            if stats.backToBackCount > 0 || stats.longestMeetingMinutes > 30 {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    if stats.backToBackCount > 0 {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.orange)
                            Text("\(stats.backToBackCount) back-to-back meeting\(stats.backToBackCount == 1 ? "" : "s")")
                                .font(.subheadline)
                        }
                    }

                    if stats.longestMeetingMinutes > 30 {
                        HStack {
                            Image(systemName: "hourglass")
                                .foregroundColor(.purple)
                            Text("Longest meeting: \(stats.longestMeetingMinutes) min")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private func statBubble(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Health Card

    private func healthCard(_ health: DailyInsightsSummary.HealthSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Health")
                    .font(.headline)
            }

            HStack(spacing: 20) {
                // Steps
                if let steps = health.steps {
                    healthMetric(
                        icon: "figure.walk",
                        value: formatNumber(steps),
                        label: "Steps",
                        goalMet: health.stepsGoalMet ?? false,
                        goalPercent: health.stepsGoalPercent
                    )
                }

                // Sleep
                if let sleepMinutes = health.sleepMinutes {
                    healthMetric(
                        icon: "bed.double.fill",
                        value: formatSleep(sleepMinutes),
                        label: "Sleep",
                        goalMet: health.sleepGoalMet ?? false,
                        goalPercent: health.sleepGoalPercent
                    )
                }

                // Active Minutes
                if let activeMinutes = health.activeMinutes {
                    healthMetric(
                        icon: "flame.fill",
                        value: "\(activeMinutes)",
                        label: "Active min",
                        goalMet: health.activeGoalMet ?? false,
                        goalPercent: health.activeGoalPercent
                    )
                }
            }

            // Resting heart rate if available
            if let rhr = health.restingHeartRate {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.red)
                    Text("Resting HR: \(rhr) bpm")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private func healthMetric(icon: String, value: String, label: String, goalMet: Bool, goalPercent: Int?) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(goalMet ? .green : .primary)
                if goalMet {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Text(value)
                .font(.headline)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            if let percent = goalPercent {
                Text("\(percent)% of goal")
                    .font(.caption2)
                    .foregroundColor(goalMet ? .green : .orange)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Highlights Card

    private func highlightsCard(_ highlights: [DailyInsightsSummary.DayHighlight]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Highlights")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                ForEach(highlights, id: \.label) { highlight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: highlight.icon)
                            .foregroundColor(highlightColor(highlight.category))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(highlight.label)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(highlight.detail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Reflection Prompt Card

    private var reflectionPromptCard: some View {
        Button(action: {
            viewModel.showReflection = true
        }) {
            HStack {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Reflection")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("Rate your day and add notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
        .sheet(isPresented: $viewModel.showReflection) {
            DayReviewView()
        }
    }

    // MARK: - Helper Functions

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func formatHours(_ hours: Double) -> String {
        if hours < 1 {
            return "\(Int(hours * 60))m"
        } else if hours == floor(hours) {
            return "\(Int(hours))h"
        } else {
            let h = Int(hours)
            let m = Int((hours - Double(h)) * 60)
            return "\(h)h \(m)m"
        }
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func formatSleep(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(mins)m"
    }

    private func dayToneIcon(_ tone: String) -> String {
        switch tone.lowercased() {
        case "intense", "busy": return "bolt.fill"
        case "calm", "relaxed": return "leaf.fill"
        case "productive": return "checkmark.seal.fill"
        case "balanced": return "scale.3d"
        default: return "sun.max.fill"
        }
    }

    private func dayToneColor(_ tone: String) -> Color {
        switch tone.lowercased() {
        case "intense", "busy": return .orange
        case "calm", "relaxed": return .green
        case "productive": return .blue
        case "balanced": return .purple
        default: return .gray
        }
    }

    private func highlightColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "health": return .red
        case "work", "meeting": return .blue
        case "focus": return .purple
        case "personal": return .green
        case "achievement": return .yellow
        default: return .gray
        }
    }
}

// MARK: - ViewModel

@MainActor
class DailyInsightsViewModel: ObservableObject {
    @Published var insights: DailyInsightsSummary?
    @Published var isLoading = false
    @Published var error: String?
    @Published var showReflection = false

    private let dayReviewService = DayReviewService.shared

    func loadInsights() async {
        isLoading = true
        error = nil

        do {
            insights = try await dayReviewService.getDailyInsightsSummary(date: Date())
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    DailyInsightsView()
}
