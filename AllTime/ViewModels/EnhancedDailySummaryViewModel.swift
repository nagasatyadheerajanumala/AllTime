import Foundation
import Combine

@MainActor
class EnhancedDailySummaryViewModel: ObservableObject {
    @Published var summary: EnhancedDailySummaryResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDate = Date()
    
    private let apiService = APIService()
    private let cacheService = CacheService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // In-memory cache for instant UI updates
    private var cachedSummary: EnhancedDailySummaryResponse?
    private var cachedDate: Date?
    
    init() {
        // Don't load in init - let view trigger
    }
    
    func loadSummary(for date: Date) async {
        selectedDate = date
        
        // Step 1: Load from disk cache first (instant UI update)
        if let cached = await cacheService.loadCachedDailySummary(for: date) {
            await MainActor.run {
                self.summary = cached
                self.cachedSummary = cached
                self.cachedDate = date
                self.isLoading = false
            }
        }
        
        // Step 2: Return in-memory cache if available (instant UI update)
        if let cached = cachedSummary, 
           let cachedDate = cachedDate,
           Calendar.current.isDate(cachedDate, inSameDayAs: date) {
            summary = cached
        }
        
        isLoading = true
        errorMessage = nil
        
        // Step 3: Fetch from backend in background
        do {
            // Fetch on background thread
            let fetchedSummary = try await Task.detached { [apiService] in
                try await apiService.fetchDailySummary(date: date)
            }.value
            
            // Save to disk cache
            await cacheService.cacheDailySummary(fetchedSummary, for: date)
            
            // Update on main thread
            await MainActor.run {
                self.summary = fetchedSummary
                self.cachedSummary = fetchedSummary
                self.cachedDate = date
                self.isLoading = false
            }
        } catch {
            // On error, keep cached data if available
            await MainActor.run {
                if self.summary == nil {
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
                print("❌ EnhancedDailySummaryViewModel: Failed to load summary: \(error.localizedDescription)")
            }
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

