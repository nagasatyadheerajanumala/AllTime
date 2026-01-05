import Foundation
import Combine
import os.log

/// Production-grade service for syncing health metrics to the backend
@MainActor
class HealthSyncService: ObservableObject {
    static let shared = HealthSyncService()
    
    @Published var lastSyncDate: Date?
    @Published var isSyncing = false
    @Published var syncError: String?
    
    private let apiService = APIService()
    private let healthMetricsService = HealthMetricsService.shared
    private let cacheService = CacheService.shared
    private let userDefaults = UserDefaults.standard
    private let lastSyncKey = "health_last_sync_date"
    private static let logger = OSLog(subsystem: "com.storillc.AllTime", category: "HealthSyncService")
    
    // Debouncing
    private var syncTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 2.0 // 2 seconds
    
    private init() {
        // Load last sync date
        if let dateString = userDefaults.string(forKey: lastSyncKey),
           let date = Self.dateFormatter.date(from: dateString) {
            lastSyncDate = date
        }
    }
    
    /// Sync health metrics for recent days (debounced)
    func syncRecentDays() async {
        // Cancel previous sync task
        syncTask?.cancel()
        
        // Create new debounced task
        syncTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            
            await performSyncRecentDays()
        }
        
        // Wait for debounce, but don't block
        _ = await syncTask?.value
    }
    
    /// Perform the actual sync (internal, called after debounce)
    private func performSyncRecentDays() async {
        guard !isSyncing else {
            os_log("Sync already in progress, skipping", log: Self.logger, type: .info)
            return
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Check authorization state using HealthMetricsService
            await healthMetricsService.checkAuthorizationStatus()
            
            if !healthMetricsService.isAuthorized {
                os_log("HealthKit readiness uncertain, attempting sync anyway", log: Self.logger, type: .info)
            } else {
                os_log("HealthKit ready, proceeding with sync", log: Self.logger, type: .info)
            }
            
            // Determine date range to sync
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            
            let startDate: Date
            if let lastSync = lastSyncDate {
                // Sync from last sync date forward
                startDate = lastSync
            } else {
                // First sync: sync last 30 days (to match capacity analysis period)
                startDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
            }
            
            let endDate = today
            
            os_log("Syncing health metrics from %@ to %@", log: Self.logger, type: .info, Self.dateFormatter.string(from: startDate), Self.dateFormatter.string(from: endDate))

            // CRITICAL: Clear the cache to ensure we get fresh data from HealthKit
            // This fixes stale sleep data issues
            healthMetricsService.clearCache()

            // Fetch metrics for date range using HealthMetricsService
            let metrics = try await healthMetricsService.fetchDailyMetrics(for: startDate, endDate: endDate)
            
            os_log("Fetched %d days of metrics", log: Self.logger, type: .info, metrics.count)
            
            guard !metrics.isEmpty else {
                os_log("No metrics to sync (HealthKit may not have data for this range)", log: Self.logger, type: .info)
                isSyncing = false
                lastSyncDate = endDate
                userDefaults.set(Self.dateFormatter.string(from: endDate), forKey: lastSyncKey)
                return
            }
            
            await cacheService.mergeHealthMetricsHistory(metrics)
            
            // HealthMetricsService already returns DailyHealthMetrics, so use directly
            // Submit to backend
            let response = try await apiService.submitDailyHealthMetrics(metrics)
            
            os_log("Successfully synced %d records", log: Self.logger, type: .info, response.recordsUpserted)
            
            isSyncing = false
            lastSyncDate = endDate
            userDefaults.set(Self.dateFormatter.string(from: endDate), forKey: lastSyncKey)
            
        } catch {
            os_log("Sync failed: %@", log: Self.logger, type: .error, error.localizedDescription)
            isSyncing = false
            syncError = error.localizedDescription
        }
    }
    
    /// Sync last N days to backend (for initial sync after authorization)
    func syncLastNDaysToBackend(_ n: Int) async {
        guard !isSyncing else {
            os_log("Sync already in progress, skipping", log: Self.logger, type: .info)
            return
        }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Check authorization state using HealthMetricsService
            await healthMetricsService.checkAuthorizationStatus()
            
            if !healthMetricsService.isAuthorized {
                os_log("HealthKit readiness uncertain, attempting sync anyway", log: Self.logger, type: .info)
            } else {
                os_log("HealthKit ready, proceeding with sync", log: Self.logger, type: .info)
            }
            
            os_log("Syncing last %d days to backend", log: Self.logger, type: .info, n)

            // CRITICAL: Clear the cache to ensure we get fresh data from HealthKit
            healthMetricsService.clearCache()

            // Fetch metrics using HealthMetricsService
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let startDate = calendar.date(byAdding: .day, value: -n, to: today) else {
                os_log("Failed to calculate start date", log: Self.logger, type: .error)
                isSyncing = false
                return
            }
            let metrics = try await healthMetricsService.fetchDailyMetrics(for: startDate, endDate: today)
            
            guard !metrics.isEmpty else {
                os_log("No metrics to sync", log: Self.logger, type: .info)
                isSyncing = false
                return
            }
            
            await cacheService.mergeHealthMetricsHistory(metrics)
            
            // HealthMetricsService already returns DailyHealthMetrics, so use directly
            // Submit to backend
            let response = try await apiService.submitDailyHealthMetrics(metrics)
            
            os_log("Successfully synced %d records", log: Self.logger, type: .info, response.recordsUpserted)
            
            isSyncing = false
            lastSyncDate = today
            userDefaults.set(Self.dateFormatter.string(from: today), forKey: lastSyncKey)
            
        } catch {
            os_log("Sync failed: %@", log: Self.logger, type: .error, error.localizedDescription)
            isSyncing = false
            syncError = error.localizedDescription
        }
    }
    
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
