import Foundation
import Combine

/// ViewModel for Health Insights with caching and debouncing
@MainActor
class HealthInsightsViewModel: ObservableObject {
    @Published var insights: HealthInsightsResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService()
    private let cacheService = CacheService.shared
    
    // In-memory cache per date range (7, 14, 30 days) - for instant UI updates
    private var cache: [String: HealthInsightsResponse] = [:]
    private var inFlightTasks: [String: Task<Void, Never>] = [:]
    
    /// Check if we have any health data across all days
    var hasAnyHealthData: Bool {
        guard let insights = insights else { return false }
        return insights.perDayMetrics.contains { day in
            (day.steps != nil && day.steps! > 0) ||
            (day.sleepMinutes != nil && day.sleepMinutes! > 0) ||
            (day.activeMinutes != nil && day.activeMinutes! > 0) ||
            (day.workoutsCount != nil && day.workoutsCount! > 0) ||
            (day.restingHeartRate != nil && day.restingHeartRate! > 0) ||
            (day.hrv != nil && day.hrv! > 0) ||
            (day.activeEnergyBurned != nil && day.activeEnergyBurned! > 0) ||
            (day.walkingDistance != nil && day.walkingDistance! > 0) ||
            (day.bodyWeight != nil && day.bodyWeight! > 0)
        }
    }
    
    /// Load health insights for a date range with caching and debouncing
    func loadInsights(startDate: Date, endDate: Date) async {
        let cacheKey = cacheKey(for: startDate, endDate: endDate)
        
        // Step 1: Load from disk cache first (instant UI update)
        let daysDiff = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        if daysDiff == 0 {
            // Single day - use 1-day cache
            if let cached = await cacheService.loadCachedHealthInsights(for: startDate) {
                await MainActor.run {
                    self.insights = cached
                    self.cache[cacheKey] = cached
                    self.isLoading = false
                }
            }
        } else if daysDiff <= 7 {
            // 7-day range - use 7-day cache
            if let cached = await cacheService.loadCachedHealthInsights7Day(startDate: startDate, endDate: endDate) {
                await MainActor.run {
                    self.insights = cached
                    self.cache[cacheKey] = cached
                    self.isLoading = false
                }
            }
        }
        
        // Step 2: Return in-memory cache if available (instant UI update)
        if let cached = cache[cacheKey] {
            insights = cached
            isLoading = false
        }
        
        // Cancel any in-flight request for this range
        inFlightTasks[cacheKey]?.cancel()
        
        isLoading = true
        errorMessage = nil
        
        // Step 3: Fetch from backend in background
        let task = Task { [apiService, cacheService] in
            do {
                // Small delay for debouncing (cancel if user switches tabs quickly)
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                let fetchedInsights = try await Task.detached {
                    try await apiService.fetchHealthInsights(startDate: startDate, endDate: endDate)
                }.value
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                // Save to disk cache
                let daysDiff = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
                if daysDiff == 0 {
                    await cacheService.cacheHealthInsights(fetchedInsights, for: startDate)
                } else if daysDiff <= 7 {
                    await cacheService.cacheHealthInsights7Day(fetchedInsights, startDate: startDate, endDate: endDate)
                }
                
                await MainActor.run {
                    self.insights = fetchedInsights
                    self.cache[cacheKey] = fetchedInsights
                    self.isLoading = false
                    self.inFlightTasks.removeValue(forKey: cacheKey)
                    print("✅ HealthInsightsViewModel: Loaded insights for \(cacheKey)")
                }
            } catch {
                guard !Task.isCancelled else { return }
                
                // On error, keep cached data if available
                await MainActor.run {
                    if self.insights == nil {
                        self.errorMessage = error.localizedDescription
                    }
                    self.isLoading = false
                    self.inFlightTasks.removeValue(forKey: cacheKey)
                    print("❌ HealthInsightsViewModel: Failed to load insights: \(error.localizedDescription)")
                }
            }
        }
        
        inFlightTasks[cacheKey] = task
    }
    
    /// Load day health insights
    func loadDayInsights(date: Date) async {
        // Step 1: Load from disk cache first (instant UI update)
        if let cached = await cacheService.loadCachedHealthInsights(for: date) {
            await MainActor.run {
                self.insights = cached
                self.isLoading = false
            }
        }
        
        isLoading = true
        errorMessage = nil
        
        // Step 2: Fetch from backend in background
        do {
            let fetchedInsights = try await Task.detached { [apiService] in
                try await apiService.fetchDayHealthInsights(date: date)
            }.value
            
            // Save to disk cache
            await cacheService.cacheHealthInsights(fetchedInsights, for: date)
            
            await MainActor.run {
                self.insights = fetchedInsights
                self.isLoading = false
            }
        } catch {
            // On error, keep cached data if available
            await MainActor.run {
                if self.insights == nil {
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
                print("❌ HealthInsightsViewModel: Failed to load day insights: \(error.localizedDescription)")
            }
        }
    }
    
    func clearCache() {
        cache.removeAll()
        insights = nil
    }
    
    private func cacheKey(for startDate: Date, endDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: startDate))_\(formatter.string(from: endDate))"
    }
}

