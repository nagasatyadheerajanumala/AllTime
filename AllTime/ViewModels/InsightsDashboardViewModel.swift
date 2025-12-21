import Foundation
import Combine

/// Unified ViewModel for the Insights Dashboard
/// Single source of truth with clean state management
@MainActor
class InsightsDashboardViewModel: ObservableObject {

    // MARK: - State

    enum ViewState: Equatable {
        case loading
        case loaded
        case error(String)

        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): return true
            case (.loaded, .loaded): return true
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    @Published var state: ViewState = .loading
    @Published var isRefreshing = false

    // MARK: - Data Models

    /// Clara's AI narrative for the hero section
    @Published var claraNarrative: String = ""

    /// Key metrics for the current state
    @Published var keyMetrics: [InsightMetric] = []

    /// Ranked issues from the past week
    @Published var issues: [RankedIssue] = []

    /// Action recommendations for next week
    @Published var recommendations: [ActionRecommendation] = []

    /// Selected week info
    @Published var selectedWeekLabel: String = "This Week"
    @Published var availableWeeks: [WeekOption] = []
    @Published var selectedWeek: WeekOption?

    // MARK: - Models

    struct InsightMetric: Identifiable {
        let id = UUID()
        let icon: String
        let value: String
        let label: String
        let color: String // Hex color
        let trend: Trend?

        enum Trend {
            case up, down, stable
        }
    }

    struct RankedIssue: Identifiable {
        let id = UUID()
        let rank: Int
        let title: String
        let detail: String
        let severity: Severity

        enum Severity: String {
            case high, medium, low
        }
    }

    struct ActionRecommendation: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let icon: String
        let colorHex: String
        let category: Category

        enum Category {
            case schedule
            case health
            case focus
            case recovery
        }
    }

    // MARK: - Dependencies

    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        loadCachedData()
    }

    // MARK: - Data Loading

    /// Load data from cache first, then refresh from network
    func loadData(forceRefresh: Bool = false) async {
        // If we have cached data, show it immediately
        if !forceRefresh && state != .loading {
            isRefreshing = true
        } else if claraNarrative.isEmpty {
            state = .loading
        }

        do {
            // Fetch weekly insights
            let weekStart = selectedWeek?.weekStart ?? currentWeekStart
            let weeklyInsights = try await apiService.getWeeklyInsights(weekStart: weekStart)

            // Process the response
            processWeeklyInsights(weeklyInsights)

            // Cache the data
            cacheData()

            state = .loaded
            isRefreshing = false
        } catch {
            print("InsightsDashboard: Error loading data - \(error.localizedDescription)")

            // Only show error if we have no cached data
            if claraNarrative.isEmpty && issues.isEmpty {
                state = .error(error.localizedDescription)
            }
            isRefreshing = false
        }
    }

    /// Force refresh all data
    func refresh() async {
        isRefreshing = true

        do {
            let weekStart = selectedWeek?.weekStart ?? currentWeekStart
            let weeklyInsights = try await apiService.refreshWeeklyInsights(weekStart: weekStart)

            processWeeklyInsights(weeklyInsights)
            cacheData()

            state = .loaded
            isRefreshing = false
        } catch {
            print("InsightsDashboard: Refresh error - \(error.localizedDescription)")
            isRefreshing = false
            // Keep existing data on refresh error
        }
    }

    /// Fetch available weeks for selection
    func fetchAvailableWeeks() async {
        do {
            let response = try await apiService.getAvailableWeeks()
            availableWeeks = response.weeks

            if selectedWeek == nil, let firstWeek = availableWeeks.first {
                selectedWeek = firstWeek
                selectedWeekLabel = firstWeek.label
            }
        } catch {
            print("InsightsDashboard: Failed to fetch weeks - \(error.localizedDescription)")
            generateFallbackWeeks()
        }
    }

    /// Select a different week
    func selectWeek(_ week: WeekOption) async {
        selectedWeek = week
        selectedWeekLabel = week.label
        await loadData(forceRefresh: true)
    }

    // MARK: - Data Processing

    private func processWeeklyInsights(_ response: WeeklyInsightsSummaryResponse) {
        // Extract Clara's narrative from recap headline
        claraNarrative = response.recap.headline

        // Process key metrics
        keyMetrics = response.recap.keyMetrics.map { metric in
            InsightMetric(
                icon: mapMetricIcon(metric.label),
                value: metric.value,
                label: metric.label,
                color: mapMetricColor(metric.label),
                trend: nil
            )
        }

        // Process issues (what went wrong)
        var rankCounter = 1
        issues = (response.recap.whatWentWrong ?? []).map { problem in
            let issue = RankedIssue(
                rank: rankCounter,
                title: problem.title,
                detail: problem.detail,
                severity: mapSeverity(rankCounter)
            )
            rankCounter += 1
            return issue
        }

        // Process recommendations (priorities + suggested blocks)
        var recs: [ActionRecommendation] = []

        // Add priorities as recommendations
        for priority in response.nextWeekFocus.priorities {
            recs.append(ActionRecommendation(
                title: priority.title,
                description: priority.detail,
                icon: priority.sfSymbol,
                colorHex: "3B82F6", // Blue
                category: .schedule
            ))
        }

        // Add suggested blocks as recommendations
        if let blocks = response.nextWeekFocus.suggestedBlocks {
            for block in blocks.prefix(3) { // Limit to 3 blocks
                recs.append(ActionRecommendation(
                    title: "\(block.dayOfWeek): \(block.formattedTime)",
                    description: block.reason,
                    icon: block.typeIcon,
                    colorHex: mapBlockTypeColor(block.type),
                    category: mapBlockCategory(block.type)
                ))
            }
        }

        recommendations = recs

        // Update week label
        selectedWeekLabel = response.weekLabel
    }

    // MARK: - Mapping Helpers

    private func mapMetricIcon(_ label: String) -> String {
        switch label.lowercased() {
        case "meetings": return "calendar"
        case "busy time": return "clock.fill"
        case "overload days": return "exclamationmark.triangle.fill"
        case "longest focus block": return "brain.head.profile"
        case "back-to-back": return "arrow.left.arrow.right"
        case "avg sleep": return "moon.fill"
        case "avg steps": return "figure.walk"
        default: return "chart.bar.fill"
        }
    }

    private func mapMetricColor(_ label: String) -> String {
        switch label.lowercased() {
        case "meetings": return "3B82F6" // Blue
        case "busy time": return "8B5CF6" // Purple
        case "overload days": return "EF4444" // Red
        case "longest focus block": return "10B981" // Green
        case "back-to-back": return "F59E0B" // Orange
        case "avg sleep": return "6366F1" // Indigo
        case "avg steps": return "06B6D4" // Cyan
        default: return "6B7280" // Gray
        }
    }

    private func mapSeverity(_ rank: Int) -> RankedIssue.Severity {
        switch rank {
        case 1: return .high
        case 2: return .medium
        default: return .low
        }
    }

    private func mapBlockTypeColor(_ type: String) -> String {
        switch type {
        case "focus": return "10B981" // Green
        case "buffer": return "F59E0B" // Orange
        case "break": return "3B82F6" // Blue
        default: return "6B7280" // Gray
        }
    }

    private func mapBlockCategory(_ type: String) -> ActionRecommendation.Category {
        switch type {
        case "focus": return .focus
        case "buffer": return .recovery
        case "break": return .recovery
        default: return .schedule
        }
    }

    // MARK: - Week Helpers

    private var currentWeekStart: String {
        let calendar = Calendar.current
        let today = Date()
        guard let monday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: monday)
    }

    private func generateFallbackWeeks() {
        let calendar = Calendar.current
        let today = Date()
        var weeks: [WeekOption] = []

        for i in 0..<8 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: today),
                  let monday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)),
                  let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else {
                continue
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let startStr = formatter.string(from: monday)
            let endStr = formatter.string(from: sunday)

            let label: String
            if i == 0 {
                label = "This Week"
            } else if i == 1 {
                label = "Last Week"
            } else {
                let monthFormatter = DateFormatter()
                monthFormatter.dateFormat = "MMM d"
                label = "\(monthFormatter.string(from: monday)) - \(calendar.component(.day, from: sunday))"
            }

            weeks.append(WeekOption(weekStart: startStr, weekEnd: endStr, label: label))
        }

        availableWeeks = weeks
        if selectedWeek == nil, let firstWeek = weeks.first {
            selectedWeek = firstWeek
            selectedWeekLabel = firstWeek.label
        }
    }

    // MARK: - Caching

    private func loadCachedData() {
        if let cached = cacheService.loadJSONSync(CachedInsightsData.self, filename: "insights_dashboard") {
            claraNarrative = cached.narrative
            keyMetrics = cached.metrics.map { m in
                InsightMetric(
                    icon: m.icon,
                    value: m.value,
                    label: m.label,
                    color: m.color,
                    trend: m.trendUp.map { $0 ? .up : .down }
                )
            }
            issues = cached.issues.enumerated().map { (index, issue) in
                RankedIssue(
                    rank: index + 1,
                    title: issue.title,
                    detail: issue.detail,
                    severity: RankedIssue.Severity(rawValue: issue.severity) ?? .low
                )
            }
            recommendations = cached.recommendations.map { rec in
                ActionRecommendation(
                    title: rec.title,
                    description: rec.description,
                    icon: rec.icon,
                    colorHex: rec.colorHex,
                    category: .schedule
                )
            }
            selectedWeekLabel = cached.weekLabel

            if !claraNarrative.isEmpty {
                state = .loaded
            }
        }
    }

    private func cacheData() {
        let cachedData = CachedInsightsData(
            narrative: claraNarrative,
            weekLabel: selectedWeekLabel,
            metrics: keyMetrics.map { m in
                CachedMetric(
                    icon: m.icon,
                    value: m.value,
                    label: m.label,
                    color: m.color,
                    trendUp: m.trend.map { $0 == .up }
                )
            },
            issues: issues.map { issue in
                CachedIssue(
                    title: issue.title,
                    detail: issue.detail,
                    severity: issue.severity.rawValue
                )
            },
            recommendations: recommendations.map { rec in
                CachedRecommendation(
                    title: rec.title,
                    description: rec.description,
                    icon: rec.icon,
                    colorHex: rec.colorHex
                )
            }
        )

        cacheService.saveJSONSync(cachedData, filename: "insights_dashboard", expiration: 1800) // 30 min
    }
}

// MARK: - Cache Models

private struct CachedInsightsData: Codable {
    let narrative: String
    let weekLabel: String
    let metrics: [CachedMetric]
    let issues: [CachedIssue]
    let recommendations: [CachedRecommendation]
}

private struct CachedMetric: Codable {
    let icon: String
    let value: String
    let label: String
    let color: String
    let trendUp: Bool?
}

private struct CachedIssue: Codable {
    let title: String
    let detail: String
    let severity: String
}

private struct CachedRecommendation: Codable {
    let title: String
    let description: String
    let icon: String
    let colorHex: String
}
