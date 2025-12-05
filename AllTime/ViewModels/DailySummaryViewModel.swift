import Foundation
import Combine

@MainActor
class DailySummaryViewModel: ObservableObject {
    @Published var summary: DailySummary?
    @Published var parsedSummary: ParsedSummary = ParsedSummary(
        sleepStatus: .good,
        dehydrationRisk: false,
        suggestedBreaks: [],
        totalMeetings: 0,
        meetingDuration: 0,
        criticalAlerts: [],
        warnings: []
    )
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDate = Date()

    // Health goals (from backend or UserDefaults)
    @Published var waterGoal: Double? = 2.5
    @Published var stepsGoal: Int? = 10000
    @Published var activeMinutesGoal: Int? = 30
    
    // Debug mode - set to true to use mock data
    var useMockData: Bool {
        get { UserDefaults.standard.bool(forKey: "use_mock_daily_summary") }
        set { UserDefaults.standard.set(newValue, forKey: "use_mock_daily_summary") }
    }

    private let apiService = APIService()
    private let cacheService = CacheService.shared
    private let parser = SummaryParser()
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Load cache synchronously for instant UI
        loadCacheSync()
    }

    /// Load cache synchronously for instant UI (called on init)
    private func loadCacheSync() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: selectedDate)
        let cacheKey = "enhanced_daily_summary_\(dateStr)"

        // Load from cache SYNCHRONOUSLY (instant, no async delay)
        if let cached = cacheService.loadJSONSync(DailySummary.self, filename: cacheKey) {
            print("✅ DailySummaryViewModel: Loaded cache SYNCHRONOUSLY on init - instant UI")
            summary = cached
            parsedSummary = parser.parse(cached)
            isLoading = false
        } else {
            print("💾 DailySummaryViewModel: No cache found on init - will load from API")
        }
    }

    func loadSummary(for date: Date, forceRefresh: Bool = false) async {
        selectedDate = date

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        let cacheKey = "enhanced_daily_summary_\(dateStr)"

        print("📝 DailySummaryViewModel: Loading summary for date: \(dateStr), forceRefresh: \(forceRefresh)")
        
        // DEBUG MODE: Use mock data if enabled
        if useMockData {
            print("🧪 DailySummaryViewModel: MOCK DATA MODE ENABLED")
            let mockSummary = MockDailySummaryData.generateMockSummary()
            summary = mockSummary
            parsedSummary = parser.parse(mockSummary)
            isLoading = false
            errorMessage = nil
            print("✅ DailySummaryViewModel: Loaded MOCK data successfully")
            return
        }

        // Step 1: Try to load from cache SYNCHRONOUSLY FIRST (instant UI)
        if !forceRefresh {
            // Load synchronously for instant UI
            if let cached = cacheService.loadJSONSync(DailySummary.self, filename: cacheKey) {
                print("✅ DailySummaryViewModel: Loaded from cache SYNCHRONOUSLY - instant UI")
                summary = cached
                parsedSummary = parser.parse(cached)
                isLoading = false

                // Refresh in background if cache is old (older than 1 hour)
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
        }

        errorMessage = nil

        // Step 2: Refresh from backend
        do {
            let response = try await apiService.getEnhancedDailySummary(date: date)
            summary = response
            parsedSummary = parser.parse(response)

            // Save to cache immediately
            print("💾 DailySummaryViewModel: Saving to cache with key: \(cacheKey)")
            cacheService.saveJSONSync(response, filename: cacheKey, expiration: 24 * 60 * 60)
            print("💾 DailySummaryViewModel: Cache saved successfully")

            isLoading = false
        } catch {
            print("❌ DailySummaryViewModel: Failed to load summary: \(error.localizedDescription)")
            // Only show error if we don't have cached data
            if summary == nil {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    /// Background refresh (non-blocking, updates cache silently)
    private func refreshInBackground(for date: Date) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        let cacheKey = "enhanced_daily_summary_\(dateStr)"

        print("🔄 DailySummaryViewModel: Background refresh for \(dateStr)...")

        do {
            let response = try await apiService.getEnhancedDailySummary(date: date)

            // Update summary if still on same date
            await MainActor.run {
                if self.selectedDate == date {
                    self.summary = response
                    self.parsedSummary = self.parser.parse(response)
                    print("✅ DailySummaryViewModel: Background refresh completed - summary updated")
                }
            }

            // Save to cache
            cacheService.saveJSONSync(response, filename: cacheKey, expiration: 24 * 60 * 60)
            print("💾 DailySummaryViewModel: Background refresh - cache updated")
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
