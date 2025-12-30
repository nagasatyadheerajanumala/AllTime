import Foundation
import Combine
import SwiftUI

/// ViewModel for Weekly Insights Summary
/// Optimized with InMemoryCache, request deduplication, and task cancellation
@MainActor
class WeeklyInsightsViewModel: ObservableObject {
    @Published var insights: WeeklyInsightsSummaryResponse?
    @Published var availableWeeks: [WeekOption] = []
    @Published var selectedWeek: WeekOption?
    @Published var isLoading = false
    @Published var isLoadingWeeks = false
    @Published var hasError = false
    @Published var errorMessage: String?

    // Capacity Analysis
    @Published var capacityAnalysis: CapacityAnalysisResponse?
    @Published var isLoadingCapacity = false

    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    private let memoryCache = InMemoryCache.shared
    private var currentTask: Task<Void, Never>?

    // MARK: - Cache Keys
    private var memoryCacheKey: String { "mem_weekly_insights_\(selectedWeek?.weekStart ?? currentWeekStart)" }
    private var weeksCacheKey: String { "mem_available_weeks" }

    init() {
        loadCachedData()
    }

    // MARK: - Task Cancellation

    /// Cancel any in-flight requests (call in onDisappear)
    func cancelPendingRequests() {
        currentTask?.cancel()
        currentTask = nil
    }

    deinit {
        currentTask?.cancel()
    }

    // MARK: - Cache Loading (Instant UI)

    private func loadCachedData() {
        // Try memory cache first (instant)
        Task {
            if let memCached: WeeklyInsightsSummaryResponse = await memoryCache.get(memoryCacheKey) {
                insights = memCached
                return
            }
        }

        // Fall back to disk cache
        if let cached = cacheService.loadJSONSync(WeeklyInsightsSummaryResponse.self, filename: "weekly_insights_current") {
            print("WeeklyInsights: Loaded from disk cache")
            insights = cached
            // Populate memory cache
            Task {
                await memoryCache.set(memoryCacheKey, value: cached, ttl: 300) // 5 min
            }
        }

        // Load available weeks
        if let cached = cacheService.loadJSONSync(AvailableWeeksResponse.self, filename: "available_weeks") {
            print("WeeklyInsights: Loaded available weeks from cache")
            availableWeeks = cached.weeks
            if selectedWeek == nil, let firstWeek = availableWeeks.first {
                selectedWeek = firstWeek
            }
        }
    }

    private func cacheInsights(_ response: WeeklyInsightsSummaryResponse, weekStart: String) {
        let filename = weekStart == currentWeekStart ? "weekly_insights_current" : "weekly_insights_\(weekStart)"

        // Memory cache first (instant for next access)
        Task {
            await memoryCache.set("mem_weekly_insights_\(weekStart)", value: response, ttl: 300)
        }

        // Disk cache in background
        Task.detached(priority: .utility) {
            CacheService.shared.saveJSONSync(response, filename: filename, expiration: 1800) // 30 min
        }
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
    /// Uses request deduplication to prevent duplicate API calls
    func fetchInsights(weekStart: String? = nil, forceRefresh: Bool = false) async {
        let targetWeek = weekStart ?? currentWeekStart
        let cacheKey = "mem_weekly_insights_\(targetWeek)"
        let diskFilename = targetWeek == currentWeekStart ? "weekly_insights_current" : "weekly_insights_\(targetWeek)"

        // 1. Try memory cache first (instant)
        if !forceRefresh {
            if let memCached: WeeklyInsightsSummaryResponse = await memoryCache.get(cacheKey) {
                insights = memCached

                // Check if needs background refresh
                if await memoryCache.needsRefresh(cacheKey) {
                    refreshInBackgroundNonBlocking(weekStart: targetWeek)
                }
                return
            }
        }

        // 2. Try disk cache for the target week (instant UI when switching weeks)
        if !forceRefresh {
            if let diskCached = cacheService.loadJSONSync(WeeklyInsightsSummaryResponse.self, filename: diskFilename) {
                print("WeeklyInsights: Loaded \(targetWeek) from disk cache")
                insights = diskCached

                // Populate memory cache
                Task {
                    await memoryCache.set(cacheKey, value: diskCached, ttl: 300)
                }

                // Check if disk cache is stale and needs background refresh
                if let metadata = cacheService.getCacheMetadataSync(filename: diskFilename),
                   Date().timeIntervalSince(metadata.lastUpdated) > 900 { // Refresh after 15 min
                    refreshInBackgroundNonBlocking(weekStart: targetWeek)
                }
                return
            }
        }

        // 3. Show loading only if we don't have data for target week
        if insights == nil || insights?.weekStart != targetWeek {
            isLoading = true
        }
        hasError = false
        errorMessage = nil

        // 4. Fetch with request deduplication
        do {
            let response = try await RequestDeduplicator.shared.dedupe(key: "weekly_insights_\(targetWeek)") {
                try await self.apiService.getWeeklyInsights(weekStart: targetWeek)
            }

            guard !Task.isCancelled else { return }

            insights = response
            cacheInsights(response, weekStart: targetWeek)
            isLoading = false
            print("WeeklyInsights: Fetched successfully for \(targetWeek)")
        } catch {
            if Task.isCancelled { return }

            print("WeeklyInsights: Error - \(error.localizedDescription)")
            isLoading = false
            if insights == nil {
                hasError = true
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Non-blocking background refresh
    private func refreshInBackgroundNonBlocking(weekStart: String) {
        currentTask?.cancel()
        currentTask = Task.detached(priority: .utility) { [weak self] in
            await self?.refreshInBackground(weekStart: weekStart)
        }
    }

    private func refreshInBackground(weekStart: String) async {
        guard !Task.isCancelled else { return }

        do {
            let response = try await apiService.getWeeklyInsights(weekStart: weekStart)

            guard !Task.isCancelled else { return }

            // Update memory cache first
            await memoryCache.set("mem_weekly_insights_\(weekStart)", value: response, ttl: 300)

            // Capture currentWeek on MainActor before detached task
            let currentWeek = await MainActor.run { self.currentWeekStart }

            await MainActor.run {
                self.insights = response
            }

            // Save to disk in background
            Task.detached(priority: .utility) {
                let filename = weekStart == currentWeek ? "weekly_insights_current" : "weekly_insights_\(weekStart)"
                CacheService.shared.saveJSONSync(response, filename: filename, expiration: 1800)
            }
        } catch {
            #if DEBUG
            if !Task.isCancelled {
                print("⚠️ WeeklyInsights background refresh failed: \(error.localizedDescription)")
            }
            #endif
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

            guard !Task.isCancelled else { return }

            insights = response
            cacheInsights(response, weekStart: weekStart)
            isLoading = false
        } catch {
            if Task.isCancelled { return }

            print("WeeklyInsights: Refresh error - \(error.localizedDescription)")
            isLoading = false
            hasError = true
            errorMessage = error.localizedDescription
        }
    }

    /// Fetch available weeks with deduplication
    func fetchAvailableWeeks() async {
        // Check memory cache first
        if let memCached: AvailableWeeksResponse = await memoryCache.get(weeksCacheKey) {
            availableWeeks = memCached.weeks
            if selectedWeek == nil, let firstWeek = availableWeeks.first {
                selectedWeek = firstWeek
            }
            return
        }

        // Skip if we already have weeks from disk cache
        if !availableWeeks.isEmpty {
            print("WeeklyInsights: Available weeks already loaded from cache")
            return
        }

        isLoadingWeeks = true

        do {
            let response = try await RequestDeduplicator.shared.dedupe(key: "available_weeks") {
                try await self.apiService.getAvailableWeeks()
            }

            guard !Task.isCancelled else { return }

            availableWeeks = response.weeks

            // Cache to memory (instant for next access)
            await memoryCache.set(weeksCacheKey, value: response, ttl: 3600)

            // Cache to disk in background
            Task.detached(priority: .utility) {
                CacheService.shared.saveJSONSync(response, filename: "available_weeks", expiration: 3600)
            }

            // Set current week as selected if none selected
            if selectedWeek == nil, let firstWeek = availableWeeks.first {
                selectedWeek = firstWeek
            }

            isLoadingWeeks = false
        } catch {
            if Task.isCancelled { return }

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

    // MARK: - Capacity Analysis

    /// Fetch capacity analysis for the current week
    func fetchCapacityAnalysis() async {
        // Check cache first
        if let cached = cacheService.loadJSONSync(CapacityAnalysisResponse.self, filename: "capacity_analysis") {
            capacityAnalysis = cached

            // Check if needs refresh (30 min cache)
            if let metadata = cacheService.getCacheMetadataSync(filename: "capacity_analysis"),
               Date().timeIntervalSince(metadata.lastUpdated) < 1800 {
                return
            }
        }

        if capacityAnalysis == nil {
            isLoadingCapacity = true
        }

        do {
            let response = try await apiService.getCapacityAnalysis()

            guard !Task.isCancelled else { return }

            capacityAnalysis = response
            isLoadingCapacity = false

            // Cache in background
            Task.detached(priority: .utility) {
                CacheService.shared.saveJSONSync(response, filename: "capacity_analysis", expiration: 1800)
            }
        } catch {
            if Task.isCancelled { return }

            print("WeeklyInsights: Capacity analysis error - \(error.localizedDescription)")
            isLoadingCapacity = false
        }
    }

    // MARK: - Capacity Computed Properties

    var capacityScore: Int? {
        capacityAnalysis?.summary.capacityScore
    }

    var capacityStatus: String {
        guard let score = capacityScore else { return "Unknown" }
        if score >= 70 { return "Healthy" }
        if score >= 40 { return "Moderate" }
        return "Overloaded"
    }

    var capacityInsights: [CapacityInsightDisplay] {
        var insights: [CapacityInsightDisplay] = []

        guard let analysis = capacityAnalysis else { return insights }

        // Schedule overload
        if analysis.summary.highIntensityDays > 2 {
            insights.append(CapacityInsightDisplay(
                icon: "calendar.badge.exclamationmark",
                title: "Schedule Overload",
                detail: "\(analysis.summary.highIntensityDays) high-intensity days this week",
                color: .orange
            ))
        }

        // Back-to-back meetings
        if let b2b = analysis.meetingPatterns.backToBackStats,
           let count = b2b.totalBackToBackOccurrences, count > 3 {
            insights.append(CapacityInsightDisplay(
                icon: "arrow.left.arrow.right",
                title: "Back-to-Back Meetings",
                detail: "\(count) occurrences - consider adding buffers",
                color: .blue
            ))
        }

        // Sleep impact from meetings
        if let health = analysis.healthImpact,
           let sleep = health.sleepCorrelation,
           sleep.hasSignificantCorrelation == true {
            insights.append(CapacityInsightDisplay(
                icon: "bed.double.fill",
                title: "Meetings Affecting Sleep",
                detail: sleep.formattedDifference + " less on meeting days",
                color: .purple
            ))
        }

        // Add from API insights if we don't have enough
        if insights.count < 3, let apiInsights = analysis.insights {
            for insight in apiInsights.prefix(3 - insights.count) {
                insights.append(CapacityInsightDisplay(
                    icon: insight.severityIcon,
                    title: insight.title,
                    detail: insight.description,
                    color: insight.severityColor
                ))
            }
        }

        return insights
    }
}

// MARK: - Capacity Insight Display Model
struct CapacityInsightDisplay: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let color: Color
}
