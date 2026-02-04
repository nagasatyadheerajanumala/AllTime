import Foundation
import Combine

@MainActor
class HealthSummaryViewModel: ObservableObject {
    @Published var summary: HealthSummary?
    @Published var goals: UserHealthGoals?
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var expiresAt: Date?
    @Published var createdAt: Date?

    // NEW: Advanced AI Summary fields
    @Published var advancedSummary: AdvancedSummary?
    @Published var patterns: [String] = []
    @Published var eventSpecificAdvice: [EventAdvice] = []
    @Published var healthSuggestions: [HealthSuggestion] = []

    // Health Goal Streaks
    @Published var streaks: HealthStreaksSummary?
    @Published var isLoadingStreaks = false

    private let apiService = APIService()
    private let cacheKey = "health_summary"
    private let streaksCacheKey = "health_streaks"
    private let cacheExpiration: TimeInterval = 24 * 60 * 60 // 24 hours
    private let streaksCacheExpiration: TimeInterval = 5 * 60 // 5 minutes for streaks (fresher data)
    
    init() {
        print("🏥 HealthSummaryViewModel: Initializing...")
        // CRITICAL: Load cache SYNCHRONOUSLY on init for instant UI
        // This ensures user sees content immediately when opening app
        loadCacheSync()
    }
    
    /// Load cache synchronously for instant UI (called on init)
    private func loadCacheSync() {
        // Load from cache SYNCHRONOUSLY (instant, no async delay)
        if let cached = CacheService.shared.loadJSONSync(HealthSummaryResponse.self, filename: cacheKey) {
            print("✅ HealthSummaryViewModel: Loaded cache SYNCHRONOUSLY on init - instant UI")
            summary = cached.summary
            createdAt = cached.createdAt
            expiresAt = cached.expiresAt
            
            // Check if cache is still valid
            if let expiresAt = expiresAt, expiresAt > Date() {
                print("✅ HealthSummaryViewModel: Cache is valid until \(expiresAt)")
                isLoading = false
                isGenerating = false
            } else {
                print("⚠️ HealthSummaryViewModel: Cache expired, will refresh in background")
                isLoading = false
                isGenerating = false
            }
        } else {
            print("💾 HealthSummaryViewModel: No cache found on init - will load from API")
        }
    }
    
    // MARK: - Load Summary
    
    /// Loads summary from cache first (instant UI), then refreshes if expired
    func loadSummary(forceRefresh: Bool = false) async {
        errorMessage = nil

        // Load goals and streaks in parallel
        Task {
            await loadGoals()
        }
        Task {
            await loadStreaks(forceRefresh: forceRefresh)
        }
        
        // Step 1: Try to load from cache SYNCHRONOUSLY FIRST (instant UI, no async delay)
        // This ensures user sees content immediately
        if !forceRefresh {
            // Load synchronously for instant UI
            if let cached = CacheService.shared.loadJSONSync(HealthSummaryResponse.self, filename: cacheKey) {
                print("✅ HealthSummaryViewModel: Loaded cached summary SYNCHRONOUSLY - instant UI")
                summary = cached.summary
                createdAt = cached.createdAt
                expiresAt = cached.expiresAt
                
                // Check if cache is still valid
                if let expiresAt = expiresAt, expiresAt > Date() {
                    print("✅ HealthSummaryViewModel: Cache is valid until \(expiresAt)")
                    isLoading = false
                    isGenerating = false
                    
                    // Refresh in background if cache expires soon (within 1 hour)
                    // This ensures data stays fresh without blocking UI
                    if expiresAt.timeIntervalSinceNow < 3600 {
                        print("🔄 HealthSummaryViewModel: Cache expires soon (< 1 hour), refreshing in background...")
                        Task.detached(priority: .utility) { [weak self] in
                            guard let self = self else { return }
                            await self.refreshSummary(showLoading: false)
                        }
                    }
                    
                    return // Exit early - cache is valid, UI updated instantly
                } else {
                    print("⚠️ HealthSummaryViewModel: Cache expired, will refresh in background")
                    // Don't show loading - keep showing cached content while refreshing
                    isLoading = false
                    isGenerating = false
                    // Will refresh below
                }
            } else {
                print("❌ HealthSummaryViewModel: No cache found")
            }
        }
        
        // No cache or force refresh - show loading only if no existing summary
        if !forceRefresh {
            if summary == nil {
                isLoading = true
            }
        } else {
            if summary != nil {
                isGenerating = true
            } else {
                isLoading = true
            }
        }
        
        // Step 2: Try to fetch from API (only if forceRefresh or no valid cache)
        if forceRefresh || summary == nil || (expiresAt != nil && expiresAt! <= Date()) {
            await refreshSummary(showLoading: summary == nil)
        }
    }
    
    // MARK: - Health Goal Streaks

    /// Loads health goal streaks - from cache first, then API
    func loadStreaks(forceRefresh: Bool = false) async {
        // Try to load from cache first (quick)
        if !forceRefresh {
            if let cached = await CacheService.shared.loadJSON(HealthStreaksSummary.self, filename: streaksCacheKey) {
                streaks = cached
                print("✅ HealthSummaryViewModel: Loaded streaks from cache - \(cached.totalActiveStreaks) active")

                // Refresh in background if we have cached data
                Task.detached(priority: .utility) { [weak self] in
                    guard let self = self else { return }
                    await self.fetchStreaksFromAPI()
                }
                return
            }
        }

        // No cache or force refresh - fetch from API
        await fetchStreaksFromAPI()
    }

    /// Fetches streaks directly from API
    private func fetchStreaksFromAPI() async {
        isLoadingStreaks = true

        do {
            let fetchedStreaks = try await apiService.getHealthStreaks()
            streaks = fetchedStreaks
            print("✅ HealthSummaryViewModel: Loaded streaks from API - \(fetchedStreaks.totalActiveStreaks) active")

            // Cache for next time
            await CacheService.shared.saveJSON(fetchedStreaks, filename: streaksCacheKey, expiration: streaksCacheExpiration)
        } catch {
            print("⚠️ HealthSummaryViewModel: Failed to load streaks: \(error.localizedDescription)")
            // Don't set error - streaks are supplementary, not critical
        }

        isLoadingStreaks = false
    }

    /// Recalculate streaks manually (e.g., after syncing health data)
    func recalculateStreaks() async {
        isLoadingStreaks = true

        do {
            let updatedStreaks = try await apiService.recalculateHealthStreaks()
            streaks = updatedStreaks
            print("✅ HealthSummaryViewModel: Recalculated streaks - \(updatedStreaks.totalActiveStreaks) active")

            // Update cache
            await CacheService.shared.saveJSON(updatedStreaks, filename: streaksCacheKey, expiration: streaksCacheExpiration)
        } catch {
            print("⚠️ HealthSummaryViewModel: Failed to recalculate streaks: \(error.localizedDescription)")
        }

        isLoadingStreaks = false
    }

    // MARK: - Health Goals

    /// Loads health goals - from cache first, then API
    func loadGoals() async {
        // Try to load from cache first (same cache as HealthGoalsViewModel)
        let goalsCacheKey = "health_goals"
        if let cached = await CacheService.shared.loadJSON(UserHealthGoals.self, filename: goalsCacheKey) {
            goals = cached
            print("✅ HealthSummaryViewModel: Loaded health goals from cache")
            print("   - Sleep: \(cached.sleepHours ?? 0), Steps: \(cached.steps ?? 0)")
            return
        }

        // Fallback to API
        do {
            let fetched = try await apiService.getHealthGoals()
            goals = fetched
            print("✅ HealthSummaryViewModel: Loaded health goals from API")
            // Cache for next time
            await CacheService.shared.saveJSON(fetched, filename: goalsCacheKey)
        } catch {
            print("⚠️ HealthSummaryViewModel: Failed to load goals: \(error.localizedDescription)")
            // Don't set error - goals are optional
        }
    }
    
    /// Refreshes summary from API (or generates if missing)
    func refreshSummary(showLoading: Bool = true) async {
        if showLoading {
            isLoading = true
        }
        errorMessage = nil
        
        do {
            // Try to get existing summary
            if let response = try await apiService.getHealthSummary() {
                print("✅ HealthSummaryViewModel: Fetched summary from API")
                summary = response.summary
                createdAt = response.createdAt
                expiresAt = response.expiresAt
                
            // ALWAYS save to cache immediately after fetch (synchronously for critical data)
            print("💾 HealthSummaryViewModel: Saving to cache")
            CacheService.shared.saveJSONSync(response, filename: cacheKey, expiration: cacheExpiration)
            print("💾 HealthSummaryViewModel: Cache saved successfully (synchronously)")
            
            // Also save async in background for redundancy
            Task.detached(priority: .utility) { [cacheKey, cacheExpiration, response] in
                await CacheService.shared.saveJSON(response, filename: cacheKey, expiration: cacheExpiration)
            }
                isLoading = false
            } else {
                // No summary exists (404) - need to generate
                print("ℹ️ HealthSummaryViewModel: No summary found, generating new one...")
                await generateSummary()
            }
        } catch {
            print("❌ HealthSummaryViewModel: Failed to fetch summary: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    /// Generates new AI suggestions (slow operation - 5-10 seconds)
    func generateSummary() async {
        isGenerating = true
        errorMessage = nil
        
        // Invalidate cache to force fresh generation with updated goals
        summary = nil
        await invalidateCache()
        
        // Reload goals to ensure we have the latest
        await loadGoals()
        
        print("🔄 HealthSummaryViewModel: Generating new summary with updated goals...")
        
        do {
            // UPDATED: New API format - no startDate/endDate, uses timezone parameter
            let response = try await apiService.generateHealthSuggestions(timezone: TimeZone.current.identifier)
            print("✅ HealthSummaryViewModel: Generated new summary")
            
            // Store legacy format if available (for backward compatibility)
            summary = response.summary
            createdAt = response.createdAt
            expiresAt = response.expiresAt
            
            // Store new advanced format
            advancedSummary = response.advancedSummary
            patterns = response.patterns ?? []
            eventSpecificAdvice = response.eventSpecificAdvice ?? []
            healthSuggestions = response.healthSuggestions ?? []
            
            print("✅ HealthSummaryViewModel: Advanced summary fields loaded")
            print("   - Patterns: \(patterns.count)")
            print("   - Event-specific advice: \(eventSpecificAdvice.count)")
            print("   - Health suggestions: \(healthSuggestions.count)")
            
            // ALWAYS save to cache immediately after fetch (synchronously for critical data)
            if let legacySummary = response.summary {
                let summaryResponse = HealthSummaryResponse(
                    summary: legacySummary,
                    createdAt: response.createdAt ?? Date(),
                    expiresAt: response.expiresAt ?? Date().addingTimeInterval(24 * 60 * 60)
                )
                CacheService.shared.saveJSONSync(summaryResponse, filename: cacheKey, expiration: cacheExpiration)
                print("💾 HealthSummaryViewModel: Cache saved successfully (synchronously)")
                
                // Also save async in background for redundancy
                Task.detached(priority: .utility) { [cacheKey, cacheExpiration, summaryResponse] in
                    await CacheService.shared.saveJSON(summaryResponse, filename: cacheKey, expiration: cacheExpiration)
                }
            }
            
            isGenerating = false
            isLoading = false
        } catch {
            print("❌ HealthSummaryViewModel: Failed to generate summary: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isGenerating = false
            isLoading = false
        }
    }
    
    /// Invalidate cache to force fresh generation
    private func invalidateCache() async {
        // Clear cached summary
        summary = nil
        print("🗑️ HealthSummaryViewModel: Invalidated cache - will regenerate with fresh goals")
    }
    
    /// Retry after error
    func retry() async {
        errorMessage = nil
        await loadSummary()
    }
    
    // MARK: - Cache Management
    
    private func loadCachedSummary() async -> HealthSummaryResponse? {
        // Try to load cached summary (async version - for background operations)
        if let cached = await CacheService.shared.loadJSON(HealthSummaryResponse.self, filename: cacheKey) {
            return cached
        }
        return nil
    }
    
    private func cacheSummary(_ response: HealthSummaryResponse) async {
        // ALWAYS save to cache immediately after fetch
        await CacheService.shared.saveJSON(response, filename: cacheKey, expiration: cacheExpiration)
        print("💾 HealthSummaryViewModel: Cache saved successfully")
    }
    
    /// Check if summary is expired
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return true }
        return expiresAt <= Date()
    }
    
    /// Get time until expiration as string
    var expirationText: String? {
        guard let expiresAt = expiresAt else { return nil }
        
        let now = Date()
        if expiresAt <= now {
            return "Expired"
        }
        
        let interval = expiresAt.timeIntervalSince(now)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "Expires in \(hours)h \(minutes)m"
        } else {
            return "Expires in \(minutes)m"
        }
    }
}

