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
    
    private let apiService = APIService()
    private let cacheKey = "health_summary"
    private let cacheExpiration: TimeInterval = 24 * 60 * 60 // 24 hours
    
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
        
        // Load goals in parallel
        Task {
            await loadGoals()
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
    
    /// Loads health goals
    func loadGoals() async {
        do {
            goals = try await apiService.getHealthGoals()
            print("✅ HealthSummaryViewModel: Loaded health goals")
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

