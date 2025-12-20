import SwiftUI
import Combine

// MARK: - Predictions Tile Content
struct PredictionsTileContent: View {
    let predictions: PredictionsResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Main capacity display
            if let capacity = predictions?.capacity {
                HStack(spacing: 6) {
                    Image(systemName: capacity.capacityIcon)
                        .font(.title3)
                    Text(capacity.capacityDisplayText)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                // Capacity bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.8))
                            .frame(width: geometry.size.width * min(capacity.capacityPercentage / 100, 1.0), height: 6)
                    }
                }
                .frame(height: 6)
            } else {
                Text("No capacity data")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Spacer(minLength: 0)

            // Stats row
            HStack(spacing: DesignSystem.Spacing.md) {
                if let travel = predictions?.travelPredictions, !travel.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                            .font(.caption2)
                        Text("\(travel.count)")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
                }

                if let warnings = predictions?.warningCount, warnings > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("\(warnings)")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(Color(hex: "FEF2F2"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
                }

                Spacer()
            }
        }
    }
}

// MARK: - Predictions Detail View (Redesigned)
struct PredictionsDetailView: View {
    @StateObject private var viewModel = CapacityAnalysisViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Today.sectionSpacing) {
                    if viewModel.isLoading && viewModel.capacityAnalysis == nil {
                        loadingView
                    } else if let analysis = viewModel.capacityAnalysis {
                        // Capacity Score Card
                        capacityScoreCard(analysis.summary)

                        // Key Insights
                        if !analysis.insights.isEmpty {
                            insightsSection(analysis.insights)
                        }

                        // Health Correlations
                        if analysis.healthImpact.sleepCorrelation?.hasSignificantCorrelation == true ||
                           analysis.healthImpact.activityCorrelation?.hasSignificantActivityImpact == true {
                            healthCorrelationsSection(analysis.healthImpact)
                        }

                        // Top Time Consumers
                        if let meetings = analysis.meetingPatterns.topRepetitiveMeetings, !meetings.isEmpty {
                            timeConsumersSection(meetings)
                        }

                        // Meeting Patterns
                        meetingPatternsSection(analysis.meetingPatterns, summary: analysis.summary)

                    } else if viewModel.hasError {
                        errorView
                    }

                    Spacer(minLength: DesignSystem.Spacing.xl)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenMargin)
                .padding(.top, DesignSystem.Spacing.md)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .presentationDragIndicator(.visible)
        .task {
            await viewModel.fetchCapacityAnalysis()
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Analyzing your patterns...")
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
                .font(.system(size: 40))
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Text("Unable to load insights")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)
            Text(viewModel.errorMessage ?? "Please try again later")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Capacity Score Card
    private func capacityScoreCard(_ summary: CapacityAnalysisSummary) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Score Circle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Capacity Score")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text(summary.statusText)
                        .font(.title2.weight(.bold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }

                Spacer()

                // Circular Score
                ZStack {
                    Circle()
                        .stroke(summary.scoreColor.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(summary.capacityScore) / 100)
                        .stroke(summary.scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(summary.capacityScore)")
                            .font(.title.weight(.bold))
                            .foregroundColor(summary.scoreColor)
                        Text("/100")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
            }

            // Stats Grid
            HStack(spacing: 0) {
                statBlock(
                    icon: "calendar",
                    value: "\(summary.totalMeetings)",
                    label: "Meetings",
                    sublabel: "in 30 days"
                )

                Divider()
                    .frame(height: 50)

                statBlock(
                    icon: "clock",
                    value: summary.formattedMeetingHours,
                    label: "Total Time",
                    sublabel: "in meetings"
                )

                Divider()
                    .frame(height: 50)

                statBlock(
                    icon: "bolt.fill",
                    value: "\(summary.highIntensityDays)",
                    label: "Intense Days",
                    sublabel: "high load"
                )
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    private func statBlock(icon: String, value: String, label: String, sublabel: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)
            Text(label)
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Text(sublabel)
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Insights Section
    private func insightsSection(_ insights: [CapacityInsight]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(icon: "lightbulb.fill", title: "Key Insights", color: Color(hex: "F59E0B"))

            ForEach(insights) { insight in
                insightCard(insight)
            }
        }
    }

    private func insightCard(_ insight: CapacityInsight) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: insight.severityIcon)
                    .font(.title3)
                    .foregroundColor(insight.severityColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(insight.description)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            if let actionable = insight.actionable, !actionable.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text(actionable)
                        .font(.caption.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                .padding(.leading, 36)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(insight.severityColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(insight.severityColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Health Correlations Section
    private func healthCorrelationsSection(_ health: HealthImpactSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(icon: "heart.fill", title: "Health Impact", color: Color(hex: "EC4899"))

            VStack(spacing: DesignSystem.Spacing.sm) {
                // Sleep Correlation
                if let sleep = health.sleepCorrelation, sleep.hasSignificantCorrelation {
                    correlationRow(
                        icon: "moon.zzz.fill",
                        iconColor: Color(hex: "6366F1"),
                        title: "Sleep Impact",
                        description: "High meeting days = \(sleep.formattedDifference) less sleep",
                        isNegative: sleep.sleepDifference > 0
                    )
                }

                // Activity Correlation
                if let activity = health.activityCorrelation, activity.hasSignificantActivityImpact {
                    correlationRow(
                        icon: "figure.walk",
                        iconColor: Color(hex: "10B981"),
                        title: "Activity Impact",
                        description: "Meeting days = \(activity.formattedDifference) fewer",
                        isNegative: activity.stepsDifference > 0
                    )
                }

                // Stress Correlation
                if let stress = health.stressCorrelation, stress.hasSignificantStressCorrelation {
                    correlationRow(
                        icon: "waveform.path.ecg",
                        iconColor: Color(hex: "EF4444"),
                        title: "Stress Indicator",
                        description: "Intense meeting days show elevated heart rate",
                        isNegative: true
                    )
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }

    private func correlationRow(icon: String, iconColor: Color, title: String, description: String, isNegative: Bool) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text(description)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()

            Image(systemName: isNegative ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.title3)
                .foregroundColor(isNegative ? Color(hex: "EF4444") : Color(hex: "10B981"))
        }
    }

    // MARK: - Time Consumers Section
    private func timeConsumersSection(_ meetings: [RepetitiveMeetingInfo]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(icon: "clock.fill", title: "Top Time Consumers", color: Color(hex: "3B82F6"))

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(meetings.prefix(5)) { meeting in
                    timeConsumerRow(meeting)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }

    private func timeConsumerRow(_ meeting: RepetitiveMeetingInfo) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Rank indicator
            Circle()
                .fill(Color(hex: "3B82F6").opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Text("\(meeting.occurrenceCount)x")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color(hex: "3B82F6"))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                Text(meeting.frequencyLabel)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(meeting.formattedTotalHours)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text("total")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
    }

    // MARK: - Meeting Patterns Section
    private func meetingPatternsSection(_ patterns: MeetingPatternsSummary, summary: CapacityAnalysisSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(icon: "chart.bar.fill", title: "Meeting Patterns", color: Color(hex: "8B5CF6"))

            VStack(spacing: DesignSystem.Spacing.md) {
                // Average per day
                patternStatRow(
                    icon: "calendar.day.timeline.leading",
                    label: "Average meetings per day",
                    value: String(format: "%.1f", patterns.avgMeetingsPerDay)
                )

                // Busiest day
                if let busiestDay = patterns.busiestDay {
                    patternStatRow(
                        icon: "flame.fill",
                        label: "Busiest day",
                        value: busiestDay.capitalized
                    )
                }

                // Back-to-back stats
                if let b2b = patterns.backToBackStats, b2b.daysWithBackToBack > 0 {
                    patternStatRow(
                        icon: "arrow.right.arrow.left",
                        label: "Back-to-back days",
                        value: "\(b2b.daysWithBackToBack) days"
                    )
                }

                // Days with health impact
                if summary.healthImpactedDays > 0 {
                    patternStatRow(
                        icon: "heart.text.square",
                        label: "Health-impacted days",
                        value: "\(summary.healthImpactedDays) days"
                    )
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }

    private func patternStatRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(Color(hex: "8B5CF6"))
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
    }

    // MARK: - Section Header
    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Spacer()
        }
    }
}

// MARK: - Capacity Analysis ViewModel
@MainActor
class CapacityAnalysisViewModel: ObservableObject {
    @Published var capacityAnalysis: CapacityAnalysisResponse?
    @Published var isLoading: Bool = false
    @Published var hasError: Bool = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    private let cacheKey = "capacity_analysis_30d"

    init() {
        loadCacheSync()
    }

    private func loadCacheSync() {
        if let cached = cacheService.loadJSONSync(CapacityAnalysisResponse.self, filename: cacheKey) {
            print("CapacityAnalysis: Loaded from cache")
            capacityAnalysis = cached
        }
    }

    func fetchCapacityAnalysis(forceRefresh: Bool = false) async {
        hasError = false
        errorMessage = nil

        if !forceRefresh, capacityAnalysis != nil {
            // Check if cache is stale (older than 30 minutes)
            if let metadata = cacheService.getCacheMetadataSync(filename: cacheKey),
               Date().timeIntervalSince(metadata.lastUpdated) < 1800 {
                return
            }
        }

        if capacityAnalysis == nil {
            isLoading = true
        }

        do {
            let response = try await apiService.getCapacityAnalysis(days: 30)
            capacityAnalysis = response
            cacheService.saveJSONSync(response, filename: cacheKey, expiration: 1800)
            print("CapacityAnalysis: Fetched and cached")
            isLoading = false
        } catch {
            print("CapacityAnalysis: Error - \(error.localizedDescription)")
            isLoading = false
            if capacityAnalysis == nil {
                hasError = true
                errorMessage = error.localizedDescription
            }
        }
    }

    func refresh() async {
        await fetchCapacityAnalysis(forceRefresh: true)
    }
}

// MARK: - Predictions Tile Type Extension
enum PredictionsTileType {
    case insights

    var title: String { "Insights" }
    var icon: String { "chart.line.uptrend.xyaxis" }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "8B5CF6"), Color(hex: "6D28D9")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Preview
#Preview {
    PredictionsDetailView()
}
