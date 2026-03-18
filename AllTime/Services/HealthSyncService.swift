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
        // One-time reset: force full 30-day resync after sync date range bug fix
        if !userDefaults.bool(forKey: "syncDateRangeFixApplied_v1") {
            userDefaults.removeObject(forKey: lastSyncKey)
            userDefaults.set(true, forKey: "syncDateRangeFixApplied_v1")
            lastSyncDate = nil
        } else if let dateString = userDefaults.string(forKey: lastSyncKey),
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
            // Update timezone on backend to ensure accurate date calculations
            let timezone = TimeZone.current.identifier
            try? await apiService.updateTimezone(timezone)
            os_log("🌐 Updated backend timezone to %@", log: Self.logger, type: .info, timezone)

            // Check authorization state using HealthMetricsService
            await healthMetricsService.checkAuthorizationStatus()

            if !healthMetricsService.isAuthorized {
                os_log("HealthKit readiness uncertain, attempting sync anyway", log: Self.logger, type: .info)
            } else {
                os_log("HealthKit ready, proceeding with sync", log: Self.logger, type: .info)
            }
            
            // Determine date range to sync
            let calendar = Calendar.current
            let now = Date()
            let todayStart = calendar.startOfDay(for: now)

            let startDate: Date
            if let lastSync = lastSyncDate {
                // Always sync at least the last 7 days to keep backend data fresh.
                // This prevents stale/missing data when the initial full sync failed
                // or HealthKit updated historical entries retroactively.
                let lastSyncStart = calendar.startOfDay(for: lastSync)
                let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
                startDate = min(lastSyncStart, sevenDaysAgo)
            } else {
                // First sync: sync last 30 days (to match capacity analysis period)
                startDate = calendar.date(byAdding: .day, value: -30, to: todayStart) ?? todayStart
            }

            let endDate = now
            
            os_log("Syncing health metrics from %@ to %@", log: Self.logger, type: .info, Self.dateFormatter.string(from: startDate), Self.dateFormatter.string(from: endDate))

            // CRITICAL: Clear the cache to ensure we get fresh data from HealthKit
            // This fixes stale sleep data issues
            healthMetricsService.clearCache()

            // Fetch metrics for date range using HealthMetricsService
            let metrics = try await healthMetricsService.fetchDailyMetrics(for: startDate, endDate: endDate)
            
            os_log("Fetched %d days of metrics", log: Self.logger, type: .info, metrics.count)

            // Log a sample of what we're sending
            if let firstMetric = metrics.first {
                os_log("📊 Sample metric - Date: %@, Steps: %d, Sleep: %d min, HR: %.0f",
                       log: Self.logger, type: .info,
                       firstMetric.date,
                       firstMetric.steps ?? 0,
                       firstMetric.sleepMinutes ?? 0,
                       firstMetric.restingHeartRate ?? 0)
            }

            guard !metrics.isEmpty else {
                os_log("No metrics to sync (HealthKit may not have data for this range)", log: Self.logger, type: .info)
                isSyncing = false
                // Don't advance lastSyncDate when nothing was fetched
                return
            }

            // Filter out days where ALL health fields are null — sending empty records
            // causes the backend to overwrite previously good data with nulls
            let nonEmptyMetrics = metrics.filter { Self.hasAnyData($0) }

            os_log("📊 Filtered: %d total → %d with data (skipping %d empty days)",
                   log: Self.logger, type: .info,
                   metrics.count, nonEmptyMetrics.count, metrics.count - nonEmptyMetrics.count)

            await cacheService.mergeHealthMetricsHistory(metrics)

            guard !nonEmptyMetrics.isEmpty else {
                os_log("No non-empty metrics to sync after filtering", log: Self.logger, type: .info)
                isSyncing = false
                return
            }

            // Submit only non-empty metrics to backend
            let response = try await apiService.submitDailyHealthMetrics(nonEmptyMetrics)

            os_log("Successfully synced %d records", log: Self.logger, type: .info, response.recordsUpserted)

            // Log any failures for debugging
            if let failedCount = response.recordsFailed, failedCount > 0 {
                os_log("⚠️ %d records failed to sync", log: Self.logger, type: .error, failedCount)
                if let failedDates = response.failedDates {
                    os_log("⚠️ Failed dates: %@", log: Self.logger, type: .error, failedDates.joined(separator: ", "))
                }
            }

            isSyncing = false

            // Only advance lastSyncDate if we got a reasonable amount of data.
            // If HealthKit returned mostly empty (e.g., background context or auth issue),
            // keep the old lastSyncDate so we retry those days on the next sync.
            let dataRatio = metrics.count > 0 ? Double(nonEmptyMetrics.count) / Double(metrics.count) : 0
            if dataRatio >= 0.3 || nonEmptyMetrics.count >= 3 {
                let syncTime = Date()
                lastSyncDate = syncTime
                userDefaults.set(Self.dateFormatter.string(from: syncTime), forKey: lastSyncKey)
                os_log("✅ Sync complete, advanced lastSyncDate (%.0f%% data coverage)", log: Self.logger, type: .info, dataRatio * 100)
            } else {
                os_log("⚠️ Sync had low data coverage (%.0f%%) — NOT advancing lastSyncDate to retry next time", log: Self.logger, type: .info, dataRatio * 100)
            }

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
            let now = Date()
            let todayStart = calendar.startOfDay(for: now)
            guard let startDate = calendar.date(byAdding: .day, value: -n, to: todayStart) else {
                os_log("Failed to calculate start date", log: Self.logger, type: .error)
                isSyncing = false
                return
            }
            let metrics = try await healthMetricsService.fetchDailyMetrics(for: startDate, endDate: now)
            
            guard !metrics.isEmpty else {
                os_log("No metrics to sync", log: Self.logger, type: .info)
                isSyncing = false
                return
            }

            // Filter out days where ALL health fields are null
            let nonEmptyMetrics = metrics.filter { Self.hasAnyData($0) }

            os_log("📊 Filtered: %d total → %d with data", log: Self.logger, type: .info, metrics.count, nonEmptyMetrics.count)

            await cacheService.mergeHealthMetricsHistory(metrics)

            guard !nonEmptyMetrics.isEmpty else {
                os_log("No non-empty metrics to sync after filtering", log: Self.logger, type: .info)
                isSyncing = false
                return
            }

            // Submit only non-empty metrics to backend
            let response = try await apiService.submitDailyHealthMetrics(nonEmptyMetrics)

            os_log("Successfully synced %d records", log: Self.logger, type: .info, response.recordsUpserted)

            // Log any failures for debugging
            if let failedCount = response.recordsFailed, failedCount > 0 {
                os_log("⚠️ %d records failed to sync", log: Self.logger, type: .error, failedCount)
                if let failedDates = response.failedDates {
                    os_log("⚠️ Failed dates: %@", log: Self.logger, type: .error, failedDates.joined(separator: ", "))
                }
            }

            isSyncing = false
            let syncTime = Date()  // Use actual sync time, not start of day
            lastSyncDate = syncTime
            userDefaults.set(Self.dateFormatter.string(from: syncTime), forKey: lastSyncKey)

        } catch {
            os_log("Sync failed: %@", log: Self.logger, type: .error, error.localizedDescription)
            isSyncing = false
            syncError = error.localizedDescription
        }
    }


    /// Returns true if the metric has at least one non-null health field
    private static func hasAnyData(_ m: DailyHealthMetrics) -> Bool {
        m.steps != nil || m.activeMinutes != nil || m.activeEnergyBurned != nil ||
        m.sleepMinutes != nil || m.restingHeartRate != nil || m.hrv != nil ||
        m.workoutsCount != nil || m.standMinutes != nil ||
        m.walkingDistanceMeters != nil || m.runningDistanceMeters != nil ||
        m.cyclingDistanceMeters != nil || m.swimmingDistanceMeters != nil ||
        m.flightsClimbed != nil ||
        m.bodyWeight != nil || m.bodyFatPercentage != nil || m.leanBodyMass != nil ||
        m.bloodOxygenSaturation != nil || m.respiratoryRate != nil ||
        m.bloodPressureSystolic != nil || m.bloodPressureDiastolic != nil ||
        m.bloodGlucose != nil || m.vo2Max != nil || m.mindfulMinutes != nil ||
        m.activeHeartRate != nil || m.maxHeartRate != nil || m.minHeartRate != nil
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"  // Include time for accurate "last synced" display
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Force a complete resync of all health data (last 30 days)
    /// Call this when health data appears incorrect or missing
    func forceFullResync() async {
        os_log("🔄 Force full health resync requested", log: Self.logger, type: .info)

        // Clear the last sync date to force a full resync
        userDefaults.removeObject(forKey: lastSyncKey)
        lastSyncDate = nil

        // Clear the health metrics cache
        healthMetricsService.clearCache()

        // Sync last 30 days
        await syncLastNDaysToBackend(30)

        os_log("✅ Force full resync completed", log: Self.logger, type: .info)
    }

    /// Clear the last sync date (for debugging)
    func clearLastSyncDate() {
        userDefaults.removeObject(forKey: lastSyncKey)
        lastSyncDate = nil
        os_log("🗑️ Last sync date cleared", log: Self.logger, type: .info)
    }
}
