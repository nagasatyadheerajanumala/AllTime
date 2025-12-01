import Foundation
import Combine

@MainActor
class DailySummaryViewModel: ObservableObject {
    @Published var summary: DailyAISummaryResponse?
    @Published var isLoading = false
    @Published var isRefreshing = false // Separate flag for background refresh
    @Published var errorMessage: String?
    @Published var selectedDate = Date()
    
    private let apiService = APIService()
    private let cacheService = CacheService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // CRITICAL: Load cache SYNCHRONOUSLY on init for instant UI
        // This ensures user sees content immediately when opening app
        loadCacheSync()
    }
    
    /// Load cache synchronously for instant UI (called on init)
    private func loadCacheSync() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: selectedDate)
        let cacheKey = "daily_summary_\(dateStr)"
        
        // Load from cache SYNCHRONOUSLY (instant, no async delay)
        if let cached = cacheService.loadJSONSync(DailyAISummaryResponse.self, filename: cacheKey) {
            print("✅ DailySummaryViewModel: Loaded cache SYNCHRONOUSLY on init - instant UI")
            summary = cached
            isLoading = false
        } else {
            print("💾 DailySummaryViewModel: No cache found on init - will load from API")
        }
    }
    
    func loadSummary(for date: Date, forceRefresh: Bool = false) async {
        let previousDate = selectedDate
        selectedDate = date
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        let cacheKey = "daily_summary_\(dateStr)"
        
        print("📝 DailySummaryViewModel: Loading summary for date: \(dateStr), forceRefresh: \(forceRefresh)")
        
        // Step 1: Try to load from cache SYNCHRONOUSLY FIRST (instant UI, no async delay)
        // This ensures user sees content immediately, even if date changed
        if !forceRefresh {
            // Load synchronously for instant UI
            if let cached = cacheService.loadJSONSync(DailyAISummaryResponse.self, filename: cacheKey) {
                print("✅ DailySummaryViewModel: Loaded from cache SYNCHRONOUSLY - instant UI")
                summary = cached
                isLoading = false
                isRefreshing = false
                
                // Refresh in background if cache is old (older than 1 hour)
                // This ensures data stays fresh without blocking UI
                if let metadata = cacheService.getCacheMetadataSync(filename: cacheKey),
                   Date().timeIntervalSince(metadata.lastUpdated) > 3600 {
                    print("🔄 DailySummaryViewModel: Cache is old (>1 hour), refreshing in background...")
                    Task.detached(priority: .utility) { [weak self] in
                        guard let self = await self else { return }
                        await self.refreshInBackground(for: date)
                    }
                }
                
                return // Exit early - cache loaded, UI updated instantly
            } else {
                print("❌ DailySummaryViewModel: No cache found for \(cacheKey)")
            }
        }
        
        // No cache or force refresh - show loading only if no existing summary
        if summary == nil {
            isLoading = true
            isRefreshing = false
        } else if forceRefresh {
            isRefreshing = true
            isLoading = false
        }
        
        errorMessage = nil
        
        // Step 2: Refresh from backend (only if no cache or force refresh)
        do {
            let response = try await apiService.getDailyAISummary(date: date)
            summary = response
            
            // ALWAYS save to cache immediately after fetch (synchronously for critical data)
            print("💾 DailySummaryViewModel: Saving to cache with key: \(cacheKey)")
            cacheService.saveJSONSync(response, filename: cacheKey, expiration: 24 * 60 * 60)
            print("💾 DailySummaryViewModel: Cache saved successfully (synchronously)")
            
            // Also save async in background for redundancy
            Task.detached(priority: .utility) { [cacheService, cacheKey, response] in
                await cacheService.saveJSON(response, filename: cacheKey, expiration: 24 * 60 * 60)
            }
            
            isLoading = false
            isRefreshing = false
        } catch {
            print("❌ DailySummaryViewModel: Failed to load summary: \(error.localizedDescription)")
            // Only show error if we don't have cached data
            if summary == nil {
                errorMessage = error.localizedDescription
            }
            isLoading = false
            isRefreshing = false
        }
    }
    
    /// Background refresh (non-blocking, updates cache silently)
    private func refreshInBackground(for date: Date) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        let cacheKey = "daily_summary_\(dateStr)"
        
        print("🔄 DailySummaryViewModel: Background refresh for \(dateStr)...")
        
        do {
            let response = try await apiService.getDailyAISummary(date: date)
            
            // Update summary if still on same date
            await MainActor.run {
                if self.selectedDate == date {
                    self.summary = response
                    print("✅ DailySummaryViewModel: Background refresh completed - summary updated")
                }
            }
            
            // Save to cache (synchronously for immediate persistence)
            cacheService.saveJSONSync(response, filename: cacheKey, expiration: 24 * 60 * 60)
            print("💾 DailySummaryViewModel: Background refresh - cache updated (synchronously)")
        } catch {
            print("⚠️ DailySummaryViewModel: Background refresh failed: \(error.localizedDescription)")
            // Don't show error - user already has cached data
        }
    }
    
    func refreshSummary() async {
        await loadSummary(for: selectedDate, forceRefresh: true)
    }
    
    func selectDate(_ date: Date) {
        Task {
            await loadSummary(for: date)
        }
    }
}

