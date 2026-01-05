import Foundation
import Combine

@MainActor
class MeetingClashesViewModel: ObservableObject {
    @Published var clashes: ClashResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDateRange: (start: Date, end: Date)?
    
    private let apiService = APIService()
    private let cacheKey = "meeting_clashes"
    private let cacheExpiration: TimeInterval = 60 * 60 // 1 hour
    
    init() {
        print("📅 MeetingClashesViewModel: Initializing...")
    }
    
    // MARK: - Load Clashes
    
    /// Load clashes for a date range
    /// - Parameters:
    ///   - startDate: Start date (defaults to today)
    ///   - endDate: End date (defaults to today + 7 days)
    ///   - forceRefresh: Force refresh from API (defaults to false)
    func loadClashes(startDate: Date? = nil, endDate: Date? = nil, forceRefresh: Bool = false) async {
        print("📅 MeetingClashesViewModel: ===== LOADING CLASHES =====")
        
        // Calculate date range
        let calendar = Calendar.current
        let start = startDate ?? Date()
        let end = endDate ?? calendar.date(byAdding: .day, value: 7, to: start) ?? start
        
        selectedDateRange = (start: start, end: end)
        
        // Step 1: Load from cache first (if not forcing refresh)
        if !forceRefresh {
            if let cached = await loadCachedClashes() {
                print("✅ MeetingClashesViewModel: Loaded cached clashes")
                clashes = cached
                isLoading = false
                
                // Check if cache is still valid
                if await isCacheValid() {
                    print("✅ MeetingClashesViewModel: Cache is valid - using cached data")
                    return
                } else {
                    print("⚠️ MeetingClashesViewModel: Cache expired - will refresh")
                }
            }
        }
        
        // Step 2: Fetch from API
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.fetchMeetingClashes(
                startDate: start,
                endDate: end,
                timezone: TimeZone.current.identifier
            )
            
            print("✅ MeetingClashesViewModel: Fetched clashes from API")
            print("✅ MeetingClashesViewModel: Total clashes: \(response.effectiveTotalClashes)")
            
            clashes = response
            
            // Cache the response
            await cacheClashes(response)
            
            isLoading = false
        } catch {
            print("❌ MeetingClashesViewModel: Failed to fetch clashes: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    /// Get clashes for a specific date
    func clashesForDate(_ date: Date) -> [ClashInfo] {
        guard let clashes = clashes else { return [] }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateString = formatter.string(from: date)
        
        return clashes.clashesByDate[dateString] ?? []
    }
    
    /// Check if there are any clashes
    var hasClashes: Bool {
        guard let clashes = clashes else { return false }
        return clashes.effectiveTotalClashes > 0
    }
    
    /// Get all clash dates
    var clashDates: [String] {
        guard let clashes = clashes else { return [] }
        return Array(clashes.clashesByDate.keys).sorted()
    }
    
    // MARK: - Cache Management
    
    private func loadCachedClashes() async -> ClashResponse? {
        return await CacheService.shared.loadJSON(ClashResponse.self, filename: cacheKey)
    }
    
    private func cacheClashes(_ response: ClashResponse) async {
        await CacheService.shared.saveJSON(response, filename: cacheKey, expiration: cacheExpiration)
    }
    
    private func isCacheValid() async -> Bool {
        return await CacheService.shared.isCacheValid(filename: cacheKey, expiration: cacheExpiration)
    }
    
    /// Clear cache
    func clearCache() async {
        await CacheService.shared.delete(filename: cacheKey)
        print("🗑️ MeetingClashesViewModel: Cache cleared")
    }
    
    /// Retry after error
    func retry() async {
        errorMessage = nil
        if let range = selectedDateRange {
            await loadClashes(startDate: range.start, endDate: range.end, forceRefresh: true)
        } else {
            await loadClashes(forceRefresh: true)
        }
    }
}

