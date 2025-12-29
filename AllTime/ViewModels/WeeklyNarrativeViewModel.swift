import Foundation
import Combine
import SwiftUI

/// ViewModel for the new calm, notebook-style Weekly Narrative Insights.
/// Uses stale-while-revalidate caching pattern with request deduplication.
@MainActor
class WeeklyNarrativeViewModel: ObservableObject {
    @Published var narrative: WeeklyNarrativeResponse?
    @Published var availableWeeks: [WeekOption] = []
    @Published var selectedWeek: WeekOption?
    @Published var isLoading = false
    @Published var isLoadingWeeks = false
    @Published var hasError = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    private let memoryCache = InMemoryCache.shared
    private var currentTask: Task<Void, Never>?

    // MARK: - Cache Keys
    private var memoryCacheKey: String { "mem_weekly_narrative_\(selectedWeek?.weekStart ?? currentWeekStart)" }
    private var diskCacheKey: String { "weekly_narrative_\(selectedWeek?.weekStart ?? currentWeekStart)" }
    private var weeksCacheKey: String { "mem_available_weeks" }

    init() {
        loadCachedData()
    }

    // MARK: - Task Cancellation

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
            if let memCached: WeeklyNarrativeResponse = await memoryCache.get(memoryCacheKey) {
                narrative = memCached
                return
            }
        }

        // Fall back to disk cache
        if let cached = cacheService.loadJSONSync(WeeklyNarrativeResponse.self, filename: diskCacheKey) {
            print("WeeklyNarrative: Loaded from disk cache")
            narrative = cached
            // Populate memory cache
            Task {
                await memoryCache.set(memoryCacheKey, value: cached, ttl: 300) // 5 min
            }
        }

        // Load available weeks
        if let cached = cacheService.loadJSONSync(AvailableWeeksResponse.self, filename: "available_weeks") {
            print("WeeklyNarrative: Loaded available weeks from cache")
            availableWeeks = cached.weeks
            if selectedWeek == nil, let firstWeek = availableWeeks.first {
                selectedWeek = firstWeek
            }
        }
    }

    private func cacheNarrative(_ response: WeeklyNarrativeResponse, weekStart: String) {
        let filename = "weekly_narrative_\(weekStart)"

        // Memory cache first (instant for next access)
        Task {
            await memoryCache.set("mem_weekly_narrative_\(weekStart)", value: response, ttl: 300)
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

    /// Fetch weekly narrative insights for the specified or current week.
    /// Uses request deduplication to prevent duplicate API calls.
    func fetchNarrative(weekStart: String? = nil, forceRefresh: Bool = false) async {
        let targetWeek = weekStart ?? currentWeekStart
        let memCacheKey = "mem_weekly_narrative_\(targetWeek)"

        // 1. Try memory cache first (instant)
        if !forceRefresh {
            if let memCached: WeeklyNarrativeResponse = await memoryCache.get(memCacheKey) {
                narrative = memCached

                // Check if needs background refresh
                if await memoryCache.needsRefresh(memCacheKey) {
                    refreshInBackgroundNonBlocking(weekStart: targetWeek)
                }
                return
            }
        }

        // 2. Check disk cache freshness
        if !forceRefresh, let cachedNarrative = narrative, cachedNarrative.weekStart == targetWeek {
            if let metadata = cacheService.getCacheMetadataSync(filename: "weekly_narrative_\(targetWeek)"),
               Date().timeIntervalSince(metadata.lastUpdated) < 1800 {
                // Stale - refresh in background
                refreshInBackgroundNonBlocking(weekStart: targetWeek)
                return
            }
        }

        // 3. Show loading only if we don't have data
        if narrative == nil || narrative?.weekStart != targetWeek {
            isLoading = true
        }
        hasError = false
        errorMessage = nil

        // 4. Fetch with request deduplication
        do {
            let response = try await RequestDeduplicator.shared.dedupe(key: "weekly_narrative_\(targetWeek)") {
                try await self.apiService.getWeeklyNarrativeInsights(weekStart: targetWeek)
            }

            guard !Task.isCancelled else { return }

            narrative = response
            cacheNarrative(response, weekStart: targetWeek)
            isLoading = false
            print("WeeklyNarrative: Fetched successfully for \(targetWeek)")
        } catch {
            if Task.isCancelled { return }

            print("WeeklyNarrative: Error - \(error.localizedDescription)")
            isLoading = false
            if narrative == nil {
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
            let response = try await apiService.getWeeklyNarrativeInsights(weekStart: weekStart)

            guard !Task.isCancelled else { return }

            // Update memory cache first
            await memoryCache.set("mem_weekly_narrative_\(weekStart)", value: response, ttl: 300)

            await MainActor.run {
                self.narrative = response
            }

            // Save to disk in background
            Task.detached(priority: .utility) {
                CacheService.shared.saveJSONSync(response, filename: "weekly_narrative_\(weekStart)", expiration: 1800)
            }
        } catch {
            #if DEBUG
            if !Task.isCancelled {
                print("WeeklyNarrative: Background refresh failed: \(error.localizedDescription)")
            }
            #endif
        }
    }

    /// Force refresh narrative
    func refresh() async {
        let weekStart = selectedWeek?.weekStart ?? currentWeekStart
        await fetchNarrative(weekStart: weekStart, forceRefresh: true)
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
            print("WeeklyNarrative: Available weeks already loaded from cache")
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

            print("WeeklyNarrative: Failed to fetch available weeks - \(error.localizedDescription)")
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

    /// Select a week and fetch its narrative
    func selectWeek(_ week: WeekOption) async {
        selectedWeek = week
        await fetchNarrative(weekStart: week.weekStart)
    }

    // MARK: - Computed Properties for UI

    /// Greeting based on time of day
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    /// Formatted week range for display
    var weekRangeLabel: String {
        guard let n = narrative else {
            return selectedWeek?.label ?? "This Week"
        }
        return n.weekLabel
    }

    /// Whether we have meaningful data to display
    var hasData: Bool {
        guard let n = narrative else { return false }
        return n.aggregates.totalMeetings > 0 || n.aggregates.totalFocusMinutes > 0
    }

    /// Check if this is current week
    var isCurrentWeek: Bool {
        return selectedWeek?.weekStart == currentWeekStart || selectedWeek == nil
    }
}
