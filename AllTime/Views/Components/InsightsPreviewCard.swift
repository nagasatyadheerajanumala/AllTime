import SwiftUI
import Combine

// MARK: - Insights Preview Card
/// Single entry point to Insights from Today screen.
/// Shows Capacity Score prominently with expandable details,
/// plus Clara's weekly narrative.
struct InsightsPreviewCard: View {
    @StateObject private var viewModel = InsightsPreviewViewModel()
    @State private var isCapacityExpanded = false
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Main card content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                if viewModel.isLoading && viewModel.capacityScore == nil {
                    skeletonContent
                } else {
                    // Header with capacity score
                    headerWithCapacityScore

                    // Clara's narrative (brief)
                    if !viewModel.narrative.isEmpty {
                        Text(viewModel.narrative)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(isCapacityExpanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Expandable Capacity Details
                    if isCapacityExpanded && viewModel.hasCapacityDetails {
                        capacityDetailsSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // View full insights button
                    viewInsightsButton
                }
            }
            .insightsCard()
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Header with Capacity Score
    private var headerWithCapacityScore: some View {
        HStack(alignment: .center, spacing: 12) {
            // Left: Weekly Insights label
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                Text("Weekly Insights")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            // Right: Capacity Score Badge (tappable)
            if let score = viewModel.capacityScore {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isCapacityExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        // Score circle
                        ZStack {
                            Circle()
                                .fill(scoreColor(score).opacity(0.2))
                                .frame(width: 32, height: 32)

                            Text("\(score)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(scoreColor(score))
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Text("Capacity")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            Text(scoreStatus(score))
                                .font(.caption.weight(.medium))
                                .foregroundColor(scoreColor(score))
                        }

                        Image(systemName: isCapacityExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Capacity Details Section (Expandable)
    private var capacityDetailsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.vertical, 4)

            // Title
            Text("Patterns to Watch")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))

            // Capacity insights (from API)
            ForEach(viewModel.capacityInsights.prefix(3), id: \.title) { insight in
                CapacityInsightRow(insight: insight)
            }
        }
    }

    // MARK: - View Insights Button
    private var viewInsightsButton: some View {
        Button(action: onTap) {
            HStack {
                Text("View Full Insights")
                    .font(.caption.weight(.medium))
                Image(systemName: "arrow.right")
                    .font(.caption2)
            }
            .foregroundColor(.white.opacity(0.7))
            .padding(.top, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Skeleton
    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 120, height: 16)
                Spacer()
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 100, height: 32)
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.08))
                .frame(height: 14)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.06))
                .frame(width: 200, height: 14)
        }
    }

    // MARK: - Helpers
    private func scoreColor(_ score: Int) -> Color {
        if score >= 70 {
            return DesignSystem.Colors.emerald // Green
        } else if score >= 40 {
            return DesignSystem.Colors.amber // Orange
        } else {
            return DesignSystem.Colors.errorRed // Red
        }
    }

    private func scoreStatus(_ score: Int) -> String {
        if score >= 70 {
            return "Healthy"
        } else if score >= 40 {
            return "Moderate"
        } else {
            return "Overloaded"
        }
    }
}

// MARK: - Capacity Insight Row
private struct CapacityInsightRow: View {
    let insight: InsightsPreviewViewModel.CapacityInsightPreview

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Icon
            Image(systemName: insight.icon)
                .font(.caption)
                .foregroundColor(insight.color.opacity(0.9))
                .frame(width: 20)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.9))

                if let detail = insight.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// MARK: - Preview ViewModel
@MainActor
class InsightsPreviewViewModel: ObservableObject {
    @Published var narrative: String = ""
    @Published var capacityScore: Int?
    @Published var capacityInsights: [CapacityInsightPreview] = []
    @Published var isLoading = false

    struct CapacityInsightPreview {
        let icon: String
        let title: String
        let detail: String?
        let color: Color
    }

    var hasCapacityDetails: Bool {
        !capacityInsights.isEmpty
    }

    private let apiService = APIService.shared
    private let cacheService = CacheService.shared

    func loadData() async {
        // First, try loading from prefetched cache for instant display
        loadFromCache()

        // If no cached data, show loading state
        if capacityScore == nil {
            isLoading = true
        }

        // Fetch fresh data in background
        await loadCapacityAnalysis()

        // Load weekly narrative from cache
        if let cached = cacheService.loadJSONSync(CachedPreviewData.self, filename: "insights_dashboard") {
            narrative = cached.narrative
        }

        isLoading = false
    }

    /// Load capacity analysis from prefetched cache
    private func loadFromCache() {
        if let cached = cacheService.loadJSONSync(CapacityAnalysisResponse.self, filename: "capacity_analysis") {
            print("📊 InsightsPreview: Using prefetched capacity data")
            processCapacityAnalysis(cached)
        }
    }

    private func loadCapacityAnalysis() async {
        // Check if cache is fresh (30 min)
        if let metadata = cacheService.getCacheMetadataSync(filename: "capacity_analysis"),
           Date().timeIntervalSince(metadata.lastUpdated) < 1800,
           capacityScore != nil {
            print("📊 InsightsPreview: Cache still fresh, skipping fetch")
            return
        }

        do {
            let analysis = try await apiService.getCapacityAnalysis()
            processCapacityAnalysis(analysis)

            // Update cache
            cacheService.saveJSONSync(analysis, filename: "capacity_analysis", expiration: 1800)
        } catch {
            // Only log if we don't have cached data
            if capacityScore == nil {
                print("Failed to load capacity analysis: \(error)")
            }
        }
    }

    private func processCapacityAnalysis(_ analysis: CapacityAnalysisResponse) {
        // Set capacity score
        capacityScore = analysis.summary.capacityScore

        // Build insights from the analysis
        var insights: [CapacityInsightPreview] = []

        // Schedule overload
        if analysis.summary.highIntensityDays > 2 {
            insights.append(CapacityInsightPreview(
                icon: "calendar.badge.exclamationmark",
                title: "Schedule Overload",
                detail: "\(analysis.summary.highIntensityDays) high-intensity days this week",
                color: DesignSystem.Colors.amber
            ))
        }

        // Back-to-back meetings
        if let b2b = analysis.meetingPatterns.backToBackStats,
           let count = b2b.totalBackToBackOccurrences, count > 3 {
            insights.append(CapacityInsightPreview(
                icon: "arrow.left.arrow.right",
                title: "Back-to-Back Meetings",
                detail: "\(count) occurrences - consider adding buffers",
                color: DesignSystem.Colors.blue
            ))
        }

        // Sleep impact from meetings
        if let health = analysis.healthImpact,
           let sleep = health.sleepCorrelation,
           sleep.hasSignificantCorrelation == true {
            insights.append(CapacityInsightPreview(
                icon: "bed.double.fill",
                title: "Meetings Affecting Sleep",
                detail: sleep.formattedDifference + " less on meeting days",
                color: DesignSystem.Colors.violet
            ))
        }

        // Add from API insights if we don't have enough
        if insights.count < 3, let apiInsights = analysis.insights {
            for insight in apiInsights.prefix(3 - insights.count) {
                insights.append(CapacityInsightPreview(
                    icon: insight.severityIcon,
                    title: insight.title,
                    detail: insight.description,
                    color: insight.severityColor
                ))
            }
        }

        capacityInsights = insights
    }
}

// MARK: - Cache Model
private struct CachedPreviewData: Codable {
    let narrative: String
    let metrics: [CachedMetric]

    struct CachedMetric: Codable {
        let icon: String
        let value: String
        let label: String
    }

    enum CodingKeys: String, CodingKey {
        case narrative
        case metrics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        narrative = try container.decode(String.self, forKey: .narrative)

        if let rawMetrics = try? container.decode([[String: String]].self, forKey: .metrics) {
            metrics = rawMetrics.compactMap { dict in
                guard let icon = dict["icon"],
                      let value = dict["value"],
                      let label = dict["label"] else { return nil }
                return CachedMetric(icon: icon, value: value, label: label)
            }
        } else if let decodedMetrics = try? container.decode([CachedMetric].self, forKey: .metrics) {
            metrics = decodedMetrics
        } else {
            metrics = []
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        InsightsPreviewCard(onTap: {})
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
