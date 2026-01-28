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

    // Next Week Forecast (predictive intelligence)
    @Published var nextWeekForecast: NextWeekForecastResponse?
    @Published var isLoadingForecast = false

    // Pattern Intelligence (Clara Knows You)
    @Published var patternIntelligence: PatternIntelligenceReport?
    @Published var isLoadingPatternIntelligence = false

    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    private let memoryCache = InMemoryCache.shared
    private var currentTask: Task<Void, Never>?
    private var forecastTask: Task<Void, Never>?
    private var patternTask: Task<Void, Never>?

    // MARK: - Cache Keys
    private var memoryCacheKey: String { "mem_weekly_narrative_\(selectedWeek?.weekStart ?? currentWeekStart)" }
    private var diskCacheKey: String { "weekly_narrative_\(selectedWeek?.weekStart ?? currentWeekStart)" }
    private var weeksCacheKey: String { "mem_available_weeks" }
    private let forecastMemCacheKey = "mem_next_week_forecast"
    private let forecastDiskCacheKey = "next_week_forecast"
    private let patternMemCacheKey = "mem_pattern_intelligence"
    private let patternDiskCacheKey = "pattern_intelligence"

    init() {
        loadCachedData()
    }

    // MARK: - Task Cancellation

    func cancelPendingRequests() {
        currentTask?.cancel()
        currentTask = nil
        forecastTask?.cancel()
        forecastTask = nil
    }

    deinit {
        currentTask?.cancel()
        forecastTask?.cancel()
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
            // Check if cached data is outdated (missing scoreBreakdown when comparison exists)
            let needsUpdate = cached.comparison != nil && cached.comparison?.scoreBreakdown == nil

            if !needsUpdate {
                print("WeeklyNarrative: Loaded from disk cache")
                narrative = cached
                // Populate memory cache
                Task {
                    await memoryCache.set(memoryCacheKey, value: cached, ttl: 300) // 5 min
                }
            } else {
                print("WeeklyNarrative: Disk cache outdated (missing scoreBreakdown), will fetch fresh")
            }
        }

        // Load available weeks
        if let cached = cacheService.loadJSONSync(AvailableWeeksResponse.self, filename: "available_weeks") {
            print("WeeklyNarrative: Loaded available weeks from cache")
            // Always prepend "Next Week" to cached weeks
            availableWeeks = prependNextWeek(to: cached.weeks)
            if selectedWeek == nil {
                // Find "This Week" by matching currentWeekStart, not by array index
                selectedWeek = availableWeeks.first { $0.weekStart == currentWeekStart }
                    ?? availableWeeks.first { $0.label == "This Week" }
                    ?? (availableWeeks.count > 1 ? availableWeeks[1] : availableWeeks.first)
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
        // Use provided weekStart, then selectedWeek if set, then compute current week
        let targetWeek = weekStart ?? selectedWeek?.weekStart ?? currentWeekStart
        print("📊 WeeklyNarrative: fetchNarrative for week \(targetWeek), selectedWeek=\(selectedWeek?.weekStart ?? "nil"), currentWeekStart=\(currentWeekStart)")
        let memCacheKey = "mem_weekly_narrative_\(targetWeek)"
        let diskFilename = "weekly_narrative_\(targetWeek)"

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

        // 2. Try disk cache for the target week (instant UI when switching weeks)
        if !forceRefresh {
            if let diskCached = cacheService.loadJSONSync(WeeklyNarrativeResponse.self, filename: diskFilename) {
                print("WeeklyNarrative: Loaded \(targetWeek) from disk cache")

                // Check if cached data is outdated (missing scoreBreakdown when comparison exists)
                let needsUpdate = diskCached.comparison != nil &&
                                  diskCached.comparison?.scoreBreakdown == nil

                if needsUpdate {
                    print("WeeklyNarrative: Cache outdated (missing scoreBreakdown), fetching fresh data")
                    // Don't use stale cache, fetch fresh data instead
                } else {
                    narrative = diskCached

                    // Populate memory cache
                    Task {
                        await memoryCache.set(memCacheKey, value: diskCached, ttl: 300)
                    }

                    // Check if disk cache is stale and needs background refresh
                    if let metadata = cacheService.getCacheMetadataSync(filename: diskFilename),
                       Date().timeIntervalSince(metadata.lastUpdated) > 900 { // Refresh after 15 min
                        refreshInBackgroundNonBlocking(weekStart: targetWeek)
                    }
                    return
                }
            }
        }

        // 3. Show loading only if we don't have data for target week
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
            // Always prepend "Next Week" to cached weeks
            availableWeeks = prependNextWeek(to: memCached.weeks)
            if selectedWeek == nil {
                // Find "This Week" by matching currentWeekStart, not by array index
                selectedWeek = availableWeeks.first { $0.weekStart == currentWeekStart }
                    ?? availableWeeks.first { $0.label == "This Week" }
                    ?? (availableWeeks.count > 1 ? availableWeeks[1] : availableWeeks.first)
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

            // Always prepend "Next Week" to the API response
            availableWeeks = prependNextWeek(to: response.weeks)

            // Cache to memory (instant for next access)
            await memoryCache.set(weeksCacheKey, value: response, ttl: 3600)

            // Cache to disk in background
            Task.detached(priority: .utility) {
                CacheService.shared.saveJSONSync(response, filename: "available_weeks", expiration: 3600)
            }

            // Set current week as selected if none selected
            if selectedWeek == nil {
                // Find "This Week" by matching currentWeekStart, not by array index
                selectedWeek = availableWeeks.first { $0.weekStart == currentWeekStart }
                    ?? availableWeeks.first { $0.label == "This Week" }
                    ?? (availableWeeks.count > 1 ? availableWeeks[1] : availableWeeks.first)
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

    /// Prepends "Next Week" option to a list of weeks
    private func prependNextWeek(to weeks: [WeekOption]) -> [WeekOption] {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let nextWeekDate = calendar.date(byAdding: .weekOfYear, value: 1, to: today),
              let nextMonday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: nextWeekDate)),
              let nextSunday = calendar.date(byAdding: .day, value: 6, to: nextMonday) else {
            return weeks
        }

        let startStr = formatter.string(from: nextMonday)
        let endStr = formatter.string(from: nextSunday)
        let nextWeekOption = WeekOption(weekStart: startStr, weekEnd: endStr, label: "Next Week")

        // Don't duplicate if already present
        if weeks.contains(where: { $0.label == "Next Week" }) {
            return weeks
        }

        return [nextWeekOption] + weeks
    }

    private func generateFallbackWeeks() {
        let calendar = Calendar.current
        let today = Date()
        var weeks: [WeekOption] = []

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Add "Next Week" first
        if let nextWeekDate = calendar.date(byAdding: .weekOfYear, value: 1, to: today),
           let nextMonday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: nextWeekDate)),
           let nextSunday = calendar.date(byAdding: .day, value: 6, to: nextMonday) {
            let startStr = formatter.string(from: nextMonday)
            let endStr = formatter.string(from: nextSunday)
            weeks.append(WeekOption(weekStart: startStr, weekEnd: endStr, label: "Next Week"))
        }

        // Add past weeks
        for i in 0..<8 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: today),
                  let monday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)),
                  let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else {
                continue
            }

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
        // Default to "This Week" by matching currentWeekStart
        if selectedWeek == nil {
            selectedWeek = weeks.first { $0.weekStart == currentWeekStart }
                ?? weeks.first { $0.label == "This Week" }
                ?? (weeks.count > 1 ? weeks[1] : weeks.first)
        }
    }

    /// Select a week and fetch its narrative
    /// Uses instant cache lookup for immediate UI update
    func selectWeek(_ week: WeekOption) async {
        // Check if we're switching to a different week
        let isSwitchingWeek = selectedWeek?.weekStart != week.weekStart
        selectedWeek = week

        let memCacheKey = "mem_weekly_narrative_\(week.weekStart)"
        let diskFilename = "weekly_narrative_\(week.weekStart)"

        // 1. Try memory cache first - INSTANT
        if let memCached: WeeklyNarrativeResponse = await memoryCache.get(memCacheKey) {
            narrative = memCached
            isLoading = false
            print("WeeklyNarrative: Week \(week.weekStart) loaded instantly from memory cache")

            // Background refresh if stale (don't change isLoading)
            if await memoryCache.needsRefresh(memCacheKey) {
                refreshInBackgroundNonBlocking(weekStart: week.weekStart)
            }
            return
        }

        // 2. Try disk cache - still very fast
        if let diskCached = cacheService.loadJSONSync(WeeklyNarrativeResponse.self, filename: diskFilename) {
            // Check if cached data is outdated (missing scoreBreakdown when comparison exists)
            let needsUpdate = diskCached.comparison != nil &&
                              diskCached.comparison?.scoreBreakdown == nil

            if needsUpdate {
                print("WeeklyNarrative: Cache outdated (missing scoreBreakdown), fetching fresh data")
                // Fall through to fetch fresh data
            } else {
                narrative = diskCached
                isLoading = false
                print("WeeklyNarrative: Week \(week.weekStart) loaded instantly from disk cache")

                // Populate memory cache for next time
                Task {
                    await memoryCache.set(memCacheKey, value: diskCached, ttl: 300)
                }

                // Background refresh if stale (don't change isLoading)
                if let metadata = cacheService.getCacheMetadataSync(filename: diskFilename),
                   Date().timeIntervalSince(metadata.lastUpdated) > 900 {
                    refreshInBackgroundNonBlocking(weekStart: week.weekStart)
                }
                return
            }
        }

        // 3. No cache - clear old data and show loading state
        if isSwitchingWeek {
            narrative = nil  // Clear old week's data to prevent showing stale content
            isLoading = true
        }
        await fetchNarrative(weekStart: week.weekStart)
    }

    // MARK: - Computed Properties for UI

    /// Greeting based on time of day, personalized with user's name
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        if hour < 12 {
            timeGreeting = "Good morning"
        } else if hour < 17 {
            timeGreeting = "Good afternoon"
        } else {
            timeGreeting = "Good evening"
        }

        // Add user's first name if available
        if let firstName = UserDefaults.standard.string(forKey: "user_first_name"), !firstName.isEmpty {
            return "\(timeGreeting), \(firstName)"
        }
        return timeGreeting
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
        // Check aggregates if available, otherwise check if we have any time buckets or overview
        if let agg = n.aggregates {
            return agg.totalMeetings > 0 || agg.totalFocusMinutes > 0
        }
        // Fallback: check if we have any content
        return !n.weeklyOverview.isEmpty || (n.timeBuckets?.isEmpty == false)
    }

    /// Check if this is current week
    var isCurrentWeek: Bool {
        return selectedWeek?.weekStart == currentWeekStart || selectedWeek == nil
    }

    /// Check if narrative matches the selected week (prevents showing stale data)
    var hasNarrativeForSelectedWeek: Bool {
        guard let narrative = narrative else { return false }
        let targetWeek = selectedWeek?.weekStart ?? currentWeekStart
        return narrative.weekStart == targetWeek
    }

    // MARK: - Next Week Forecast (Predictive Intelligence)

    /// Fetch next week's forecast - predictive, forward-looking data
    func fetchNextWeekForecast(forceRefresh: Bool = false) async {
        // 1. Try memory cache first (instant)
        if !forceRefresh {
            if let memCached: NextWeekForecastResponse = await memoryCache.get(forecastMemCacheKey) {
                nextWeekForecast = memCached
                print("NextWeekForecast: Loaded from memory cache")

                // Background refresh if stale
                if await memoryCache.needsRefresh(forecastMemCacheKey) {
                    refreshForecastInBackground()
                }
                return
            }
        }

        // 2. Try disk cache
        if !forceRefresh {
            if let diskCached = cacheService.loadJSONSync(NextWeekForecastResponse.self, filename: forecastDiskCacheKey) {
                nextWeekForecast = diskCached
                print("NextWeekForecast: Loaded from disk cache")

                // Populate memory cache
                Task {
                    await memoryCache.set(forecastMemCacheKey, value: diskCached, ttl: 300)
                }

                // Background refresh if stale (after 15 min)
                if let metadata = cacheService.getCacheMetadataSync(filename: forecastDiskCacheKey),
                   Date().timeIntervalSince(metadata.lastUpdated) > 900 {
                    refreshForecastInBackground()
                }
                return
            }
        }

        // 3. Show loading if no cached data
        if nextWeekForecast == nil {
            isLoadingForecast = true
        }

        // 4. Fetch from API
        do {
            let response = try await RequestDeduplicator.shared.dedupe(key: "next_week_forecast") {
                try await self.apiService.getNextWeekForecast()
            }

            guard !Task.isCancelled else { return }

            nextWeekForecast = response
            isLoadingForecast = false

            // Cache to memory
            await memoryCache.set(forecastMemCacheKey, value: response, ttl: 300)

            // Cache to disk in background
            Task.detached(priority: .utility) {
                CacheService.shared.saveJSONSync(response, filename: self.forecastDiskCacheKey, expiration: 1800)
            }

            print("NextWeekForecast: Fetched successfully - \(response.headline)")
        } catch {
            if Task.isCancelled { return }

            print("NextWeekForecast: Error - \(error.localizedDescription)")
            isLoadingForecast = false
        }
    }

    /// Background refresh for forecast
    private func refreshForecastInBackground() {
        forecastTask?.cancel()
        forecastTask = Task.detached(priority: .utility) { [weak self] in
            guard let self = self, !Task.isCancelled else { return }

            do {
                let response = try await self.apiService.getNextWeekForecast()
                guard !Task.isCancelled else { return }

                await self.memoryCache.set(self.forecastMemCacheKey, value: response, ttl: 300)

                await MainActor.run {
                    self.nextWeekForecast = response
                }

                CacheService.shared.saveJSONSync(response, filename: self.forecastDiskCacheKey, expiration: 1800)
            } catch {
                #if DEBUG
                if !Task.isCancelled {
                    print("NextWeekForecast: Background refresh failed: \(error.localizedDescription)")
                }
                #endif
            }
        }
    }

    /// Whether forecast is for a meaningful future (has data)
    var hasForecastData: Bool {
        guard let forecast = nextWeekForecast else { return false }
        return !forecast.dailyForecasts.isEmpty
    }

    /// Whether to show forecast (only for current week view)
    var shouldShowForecast: Bool {
        isCurrentWeek && hasForecastData
    }

    // MARK: - Next Week Selection & Pattern Intelligence

    /// Check if "Next Week" is selected
    var isNextWeekSelected: Bool {
        guard let selected = selectedWeek else { return false }
        return selected.label == "Next Week" || selected.weekStart == nextWeekStart
    }

    /// Get next week's start date string
    var nextWeekStart: String {
        let calendar = Calendar.current
        let today = Date()
        guard let nextWeekDate = calendar.date(byAdding: .weekOfYear, value: 1, to: today),
              let nextMonday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: nextWeekDate)) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: nextMonday)
    }

    /// Whether we have pattern intelligence data
    var hasPatternData: Bool {
        guard let pattern = patternIntelligence else { return false }
        return !pattern.days.isEmpty
    }

    /// Fetch pattern intelligence for next week
    func fetchPatternIntelligence(forceRefresh: Bool = false) async {
        // 1. Try memory cache first
        if !forceRefresh {
            if let memCached: PatternIntelligenceReport = await memoryCache.get(patternMemCacheKey) {
                patternIntelligence = memCached
                print("PatternIntelligence: Loaded from memory cache")
                return
            }
        }

        // 2. Try disk cache
        if !forceRefresh {
            if let diskCached = cacheService.loadJSONSync(PatternIntelligenceReport.self, filename: patternDiskCacheKey) {
                patternIntelligence = diskCached
                print("PatternIntelligence: Loaded from disk cache")

                Task {
                    await memoryCache.set(patternMemCacheKey, value: diskCached, ttl: 600)
                }
                return
            }
        }

        // 3. Show loading if no cached data
        if patternIntelligence == nil {
            isLoadingPatternIntelligence = true
        }

        // 4. Fetch from API
        do {
            let response = try await RequestDeduplicator.shared.dedupe(key: "pattern_intelligence") {
                try await self.apiService.getPatternIntelligence()
            }

            guard !Task.isCancelled else { return }

            patternIntelligence = response
            isLoadingPatternIntelligence = false

            // Cache to memory
            await memoryCache.set(patternMemCacheKey, value: response, ttl: 600)

            // Cache to disk in background
            Task.detached(priority: .utility) {
                CacheService.shared.saveJSONSync(response, filename: self.patternDiskCacheKey, expiration: 3600)
            }

            print("PatternIntelligence: Fetched successfully - \(response.totalHistoricalDays) historical days analyzed")
        } catch {
            if Task.isCancelled { return }

            print("PatternIntelligence: Error - \(error.localizedDescription)")
            isLoadingPatternIntelligence = false
        }
    }
}
