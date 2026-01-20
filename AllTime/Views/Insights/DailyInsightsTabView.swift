import SwiftUI
import Combine

/// Daily Insights Tab View - Shows today's summary within the Insights tab
/// This is the destination for evening summary notifications
struct DailyInsightsTabView: View {
    @StateObject private var viewModel = DailyInsightsTabViewModel()
    @State private var selectedDate: Date = Date()
    @State private var showingReflection = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date picker for viewing different days
                datePicker

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
        .background(DesignSystem.Colors.background)
        .task {
            await viewModel.loadInsights(for: selectedDate)
        }
        .refreshable {
            await viewModel.loadInsights(for: selectedDate, forceRefresh: true)
        }
        .onChange(of: selectedDate) { newDate in
            Task {
                await viewModel.loadInsights(for: newDate)
            }
        }
        .sheet(isPresented: $showingReflection) {
            DayReviewView()
        }
    }

    // MARK: - Date Picker

    private var datePicker: some View {
        HStack {
            Button(action: {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text(selectedDate.formatted(.dateTime.month(.wide).day()))
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()

            Button(action: {
                withAnimation {
                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    if tomorrow <= Date() {
                        selectedDate = tomorrow
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Calendar.current.isDateInToday(selectedDate) ? DesignSystem.Colors.secondaryText.opacity(0.3) : DesignSystem.Colors.primary)
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading your day summary...")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(DesignSystem.Colors.amber)
            Text(error)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await viewModel.loadInsights(for: selectedDate, forceRefresh: true)
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
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Text("No summary available")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            Text("Check back later for your daily insights")
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Insights Content

    @ViewBuilder
    private func insightsContent(_ insights: DailyInsightsSummary) -> some View {
        // Day Tone Badge
        dayToneCard(insights)

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

        // Reflection prompt
        reflectionPromptCard
    }

    // MARK: - Day Tone Card

    private func dayToneCard(_ insights: DailyInsightsSummary) -> some View {
        HStack(spacing: 8) {
            Image(systemName: dayToneIcon(insights.dayTone))
                .font(.title2)
                .foregroundColor(dayToneColor(insights.dayTone))
            Text(insights.dayTone.capitalized)
                .font(.title2.weight(.semibold))
                .foregroundColor(dayToneColor(insights.dayTone))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(dayToneColor(insights.dayTone).opacity(0.15))
        .cornerRadius(DesignSystem.CornerRadius.lg)
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
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text("completed")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            .frame(width: 120, height: 120)

            // Summary message
            if let message = completion.summaryMessage {
                Text(message)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            // Stats row
            HStack(spacing: 32) {
                statItem(value: "\(completion.totalCompleted)", label: "Done", color: DesignSystem.Colors.emerald)
                statItem(value: "\(completion.totalPlanned - completion.totalCompleted)", label: "Missed", color: DesignSystem.Colors.errorRed)
                statItem(value: "\(completion.totalPlanned)", label: "Planned", color: DesignSystem.Colors.blue)
            }
        }
        .padding(24)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
    }

    private func completionColor(for percentage: Int) -> Color {
        if percentage >= 75 {
            return DesignSystem.Colors.emerald
        } else if percentage >= 50 {
            return DesignSystem.Colors.amber
        } else {
            return DesignSystem.Colors.errorRed
        }
    }

    // MARK: - Summary Card

    private func summaryCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.quote")
                    .foregroundColor(DesignSystem.Colors.blue)
                Text("Summary")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            Text(message)
                .font(.body)
                .lineSpacing(4)
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    // MARK: - Time Breakdown Card

    private func timeBreakdownCard(_ breakdown: DailyInsightsSummary.TimeBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(DesignSystem.Colors.violet)
                Text("Time Breakdown")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            VStack(spacing: 12) {
                timeBar(label: "Meetings", hours: breakdown.meetingHours, color: DesignSystem.Colors.errorRed, maxHours: 8)
                timeBar(label: "Focus", hours: breakdown.focusHours, color: DesignSystem.Colors.blue, maxHours: 8)
                timeBar(label: "Personal", hours: breakdown.personalHours, color: DesignSystem.Colors.emerald, maxHours: 8)
                timeBar(label: "Free", hours: breakdown.freeHours, color: DesignSystem.Colors.tertiaryText, maxHours: 8)
            }

            HStack {
                Text("Total Scheduled")
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Spacer()
                Text(formatHours(breakdown.totalScheduledHours))
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            .font(.subheadline)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    private func timeBar(label: String, hours: Double, color: Color, maxHours: Double) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
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
                .foregroundColor(DesignSystem.Colors.primaryText)
                .frame(width: 40, alignment: .trailing)
        }
    }

    // MARK: - Event Stats Card

    private func eventStatsCard(_ stats: DailyInsightsSummary.EventStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(DesignSystem.Colors.amber)
                Text("Events")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                statBubble(value: "\(stats.totalEvents)", label: "Total", color: DesignSystem.Colors.blue)
                statBubble(value: "\(stats.meetings)", label: "Meetings", color: DesignSystem.Colors.errorRed)
                statBubble(value: "\(stats.focusBlocks)", label: "Focus", color: DesignSystem.Colors.violet)
            }

            if stats.backToBackCount > 0 || stats.longestMeetingMinutes > 30 {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    if stats.backToBackCount > 0 {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(DesignSystem.Colors.amber)
                            Text("\(stats.backToBackCount) back-to-back meeting\(stats.backToBackCount == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                    }

                    if stats.longestMeetingMinutes > 30 {
                        HStack {
                            Image(systemName: "hourglass")
                                .foregroundColor(DesignSystem.Colors.violet)
                            Text("Longest meeting: \(stats.longestMeetingMinutes) min")
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    private func statBubble(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }

    // MARK: - Health Card

    private func healthCard(_ health: DailyInsightsSummary.HealthSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(DesignSystem.Colors.errorRed)
                Text("Health")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            HStack(spacing: 20) {
                if let steps = health.steps {
                    healthMetric(
                        icon: "figure.walk",
                        value: formatNumber(steps),
                        label: "Steps",
                        goalMet: health.stepsGoalMet ?? false,
                        goalPercent: health.stepsGoalPercent
                    )
                }

                if let sleepMinutes = health.sleepMinutes {
                    healthMetric(
                        icon: "bed.double.fill",
                        value: formatSleep(sleepMinutes),
                        label: "Sleep",
                        goalMet: health.sleepGoalMet ?? false,
                        goalPercent: health.sleepGoalPercent
                    )
                }

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

            if let rhr = health.restingHeartRate {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(DesignSystem.Colors.errorRed)
                    Text("Resting HR: \(rhr) bpm")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    private func healthMetric(icon: String, value: String, label: String, goalMet: Bool, goalPercent: Int?) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(goalMet ? DesignSystem.Colors.emerald : DesignSystem.Colors.primaryText)
                if goalMet {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.emerald)
                }
            }

            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(label)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)

            if let percent = goalPercent {
                Text("\(percent)% of goal")
                    .font(.caption2)
                    .foregroundColor(goalMet ? DesignSystem.Colors.emerald : DesignSystem.Colors.amber)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Highlights Card

    private func highlightsCard(_ highlights: [DailyInsightsSummary.DayHighlight]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(DesignSystem.Colors.amber)
                Text("Highlights")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
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
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            Text(highlight.detail)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    // MARK: - Reflection Prompt Card

    private var reflectionPromptCard: some View {
        Button(action: {
            showingReflection = true
        }) {
            HStack {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Reflection")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text("Rate your day and add notes")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .padding()
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.lg)
        }
    }

    // MARK: - Helper Functions

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
        case "intense", "busy": return DesignSystem.Colors.amber
        case "calm", "relaxed": return DesignSystem.Colors.emerald
        case "productive": return DesignSystem.Colors.blue
        case "balanced": return DesignSystem.Colors.violet
        default: return DesignSystem.Colors.tertiaryText
        }
    }

    private func highlightColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "health": return DesignSystem.Colors.errorRed
        case "work", "meeting": return DesignSystem.Colors.blue
        case "focus": return DesignSystem.Colors.violet
        case "personal": return DesignSystem.Colors.emerald
        case "achievement": return DesignSystem.Colors.amber
        default: return DesignSystem.Colors.tertiaryText
        }
    }
}

// MARK: - ViewModel

@MainActor
class DailyInsightsTabViewModel: ObservableObject {
    @Published var insights: DailyInsightsSummary?
    @Published var isLoading = false
    @Published var error: String?

    private let dayReviewService = DayReviewService.shared
    private var cache: [String: (insights: DailyInsightsSummary, timestamp: Date)] = [:]
    private let cacheExpiration: TimeInterval = 300 // 5 minutes

    func loadInsights(for date: Date, forceRefresh: Bool = false) async {
        let dateKey = formatDateKey(date)

        // Check cache first
        if !forceRefresh, let cached = cache[dateKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            insights = cached.insights
            return
        }

        isLoading = true
        error = nil

        do {
            let summary = try await dayReviewService.getDailyInsightsSummary(date: date)
            insights = summary
            cache[dateKey] = (summary, Date())
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

#Preview {
    DailyInsightsTabView()
}
