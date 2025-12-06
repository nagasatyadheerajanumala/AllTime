import Foundation
import Combine

@MainActor
class EnhancedDailySummaryViewModel: ObservableObject {
    @Published var summary: EnhancedDailySummaryResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDate = Date()
    
    // Debug mode - set to true to use mock data
    var useMockData: Bool {
        get { UserDefaults.standard.bool(forKey: "use_mock_enhanced_summary") }
        set { UserDefaults.standard.set(newValue, forKey: "use_mock_enhanced_summary") }
    }
    
    private let apiService = APIService()
    private let cacheService = CacheService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // In-memory cache for instant UI updates
    private var cachedSummary: EnhancedDailySummaryResponse?
    private var cachedDate: Date?
    
    init() {
        // Load cache SYNCHRONOUSLY on init for instant UI
        loadCacheSync()
    }
    
    /// Load cache synchronously for instant UI (called on init)
    private func loadCacheSync() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: selectedDate)
        let cacheKey = "enhanced_daily_summary_\(dateStr)"
        
        print("💾 EnhancedDailySummaryViewModel: Loading cache synchronously for \(dateStr)...")
        
        // Load from cache SYNCHRONOUSLY (instant, no async delay)
        if let cached = cacheService.loadJSONSync(EnhancedDailySummaryResponse.self, filename: cacheKey) {
            print("✅ EnhancedDailySummaryViewModel: Loaded cache SYNCHRONOUSLY - instant UI")
            summary = cached
            cachedSummary = cached
            cachedDate = selectedDate
            isLoading = false
        } else {
            print("💾 EnhancedDailySummaryViewModel: No cache found for \(cacheKey) - will load from API")
        }
    }
    
    func loadSummary(for date: Date) async {
        selectedDate = date
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        let cacheKey = "enhanced_daily_summary_\(dateStr)"
        
        print("📝 EnhancedDailySummaryViewModel: Loading summary for date: \(dateStr)")
        
        // Step 1: Check in-memory cache first (instant)
        if let cached = cachedSummary, 
           let cachedDate = cachedDate,
           Calendar.current.isDate(cachedDate, inSameDayAs: date) {
            print("✅ EnhancedDailySummaryViewModel: Using in-memory cache")
            summary = cached
            isLoading = false
            return
        }
        
        // Step 2: Load from disk cache synchronously (instant UI)
        if let cached = cacheService.loadJSONSync(EnhancedDailySummaryResponse.self, filename: cacheKey) {
            print("✅ EnhancedDailySummaryViewModel: Loaded from disk cache SYNCHRONOUSLY")
            summary = cached
            cachedSummary = cached
            cachedDate = date
            isLoading = false
            
            // Refresh in background if cache is old (>1 hour)
            if let metadata = cacheService.getCacheMetadataSync(filename: cacheKey),
               Date().timeIntervalSince(metadata.lastUpdated) > 3600 {
                print("🔄 EnhancedDailySummaryViewModel: Cache is old, refreshing in background...")
                Task.detached(priority: .utility) { [weak self] in
                    guard let self = await self else { return }
                    await self.refreshInBackground(for: date)
                }
            }
            return
        }
        
        // Step 3: No cache - fetch from backend
        print("💾 EnhancedDailySummaryViewModel: No cache found, fetching from backend...")
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch from backend
            let fetchedSummary = try await apiService.fetchDailySummary(date: date)
            
            // Save to cache
            cacheService.saveJSONSync(fetchedSummary, filename: cacheKey, expiration: 24 * 60 * 60)
            print("💾 EnhancedDailySummaryViewModel: Saved to cache: \(cacheKey)")
            
            // Update UI
            summary = fetchedSummary
            cachedSummary = fetchedSummary
            cachedDate = date
            isLoading = false
            
        } catch {
            // On error, keep cached data if available
            if summary == nil {
                errorMessage = error.localizedDescription
            }
            isLoading = false
            print("❌ EnhancedDailySummaryViewModel: Failed to load summary: \(error.localizedDescription)")
        }
    }
    
    /// Background refresh (non-blocking, updates cache silently)
    private func refreshInBackground(for date: Date) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        let cacheKey = "enhanced_daily_summary_\(dateStr)"
        
        print("🔄 EnhancedDailySummaryViewModel: Background refresh for \(dateStr)...")
        
        do {
            let fetchedSummary = try await apiService.fetchDailySummary(date: date)
            
            // Update summary if still on same date
            await MainActor.run {
                if Calendar.current.isDate(self.selectedDate, inSameDayAs: date) {
                    self.summary = fetchedSummary
                    self.cachedSummary = fetchedSummary
                    self.cachedDate = date
                    print("✅ EnhancedDailySummaryViewModel: Background refresh completed")
                }
            }
            
            // Save to cache
            cacheService.saveJSONSync(fetchedSummary, filename: cacheKey, expiration: 24 * 60 * 60)
            print("💾 EnhancedDailySummaryViewModel: Background refresh - cache updated")
        } catch {
            print("⚠️ EnhancedDailySummaryViewModel: Background refresh failed: \(error.localizedDescription)")
            // Don't show error - user already has cached data
        }
    }
    
    func refreshSummary() async {
        // Clear cache to force refresh
        cachedSummary = nil
        cachedDate = nil
        await loadSummary(for: selectedDate)
    }
    
    func selectDate(_ date: Date) {
        Task {
            await loadSummary(for: date)
        }
    }
}

