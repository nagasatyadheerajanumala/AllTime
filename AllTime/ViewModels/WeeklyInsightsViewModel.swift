import Foundation
import Combine

/// ViewModel for Weekly Insights Summary
@MainActor
class WeeklyInsightsViewModel: ObservableObject {
    @Published var insights: WeeklyInsightsSummaryResponse?
    @Published var availableWeeks: [WeekOption] = []
    @Published var selectedWeek: WeekOption?
    @Published var isLoading = false
    @Published var isLoadingWeeks = false
    @Published var hasError = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared
    private let cacheService = CacheService.shared

    init() {
        loadCachedInsights()
    }

    // MARK: - Cache

    private func loadCachedInsights() {
        if let cached = cacheService.loadJSONSync(WeeklyInsightsSummaryResponse.self, filename: "weekly_insights_current") {
            print("WeeklyInsights: Loaded from cache")
            insights = cached
        }
    }

    private func cacheInsights(_ insights: WeeklyInsightsSummaryResponse, weekStart: String) {
        let filename = weekStart == currentWeekStart ? "weekly_insights_current" : "weekly_insights_\(weekStart)"
        cacheService.saveJSONSync(insights, filename: filename, expiration: 1800) // 30 min cache
    }

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

    // MARK: - Data Loading

    /// Fetch weekly insights for the specified or current week
    func fetchInsights(weekStart: String? = nil, forceRefresh: Bool = false) async {
        let targetWeek = weekStart ?? currentWeekStart

        // Check cache freshness
        if !forceRefresh, let cachedInsights = insights, cachedInsights.weekStart == targetWeek {
            if let metadata = cacheService.getCacheMetadataSync(filename: "weekly_insights_\(targetWeek)"),
               Date().timeIntervalSince(metadata.lastUpdated) < 1800 {
                return // Cache is fresh
            }
        }

        // Only show loading if we don't have data
        if insights == nil || insights?.weekStart != targetWeek {
            isLoading = true
        }
        hasError = false
        errorMessage = nil

        do {
            let response = try await apiService.getWeeklyInsights(weekStart: targetWeek)
            insights = response
            cacheInsights(response, weekStart: targetWeek)
            isLoading = false
            print("WeeklyInsights: Fetched successfully for \(targetWeek)")
        } catch {
            print("WeeklyInsights: Error - \(error.localizedDescription)")
            isLoading = false
            if insights == nil {
                hasError = true
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Force refresh insights
    func refresh() async {
        let weekStart = selectedWeek?.weekStart ?? currentWeekStart
        isLoading = true
        hasError = false
        errorMessage = nil

        do {
            let response = try await apiService.refreshWeeklyInsights(weekStart: weekStart)
            insights = response
            cacheInsights(response, weekStart: weekStart)
            isLoading = false
        } catch {
            print("WeeklyInsights: Refresh error - \(error.localizedDescription)")
            isLoading = false
            hasError = true
            errorMessage = error.localizedDescription
        }
    }

    /// Fetch available weeks
    func fetchAvailableWeeks() async {
        isLoadingWeeks = true

        do {
            let response = try await apiService.getAvailableWeeks()
            availableWeeks = response.weeks

            // Set current week as selected if none selected
            if selectedWeek == nil, let firstWeek = availableWeeks.first {
                selectedWeek = firstWeek
            }

            isLoadingWeeks = false
        } catch {
            print("WeeklyInsights: Failed to fetch available weeks - \(error.localizedDescription)")
            isLoadingWeeks = false
            // Generate fallback weeks locally
            generateFallbackWeeks()
        }
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
        }
    }

    /// Select a week and fetch its insights
    func selectWeek(_ week: WeekOption) async {
        selectedWeek = week
        await fetchInsights(weekStart: week.weekStart)
    }
}
