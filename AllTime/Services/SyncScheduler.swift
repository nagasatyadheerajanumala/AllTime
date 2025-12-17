import Foundation
import SwiftUI
import Combine

/// Manages automated calendar sync scheduling
/// - Syncs on app launch
/// - Syncs when app comes to foreground
/// - Syncs periodically while app is active (every 15 minutes)
@MainActor
class SyncScheduler: ObservableObject {
    static let shared = SyncScheduler()
    
    @Published var lastSyncTime: Date?
    @Published var isSyncing = false
    @Published var syncError: String?
    
    private let apiService = APIService()
    private var syncTimer: Timer?
    
    // Sync intervals
    private let syncInterval: TimeInterval = 15 * 60 // 15 minutes
    private let minimumSyncInterval: TimeInterval = 5 * 60 // Minimum 5 minutes between syncs
    
    private init() {
        print("🔄 SyncScheduler: Initializing...")
        loadLastSyncTime()
    }
    
    // MARK: - Last Sync Time Management
    
    private func loadLastSyncTime() {
        if let timestamp = UserDefaults.standard.object(forKey: "lastSyncTime") as? Date {
            lastSyncTime = timestamp
            print("🔄 SyncScheduler: Last sync time: \(timestamp)")
        } else {
            print("🔄 SyncScheduler: No previous sync found")
        }
    }
    
    private func saveLastSyncTime() {
        lastSyncTime = Date()
        UserDefaults.standard.set(lastSyncTime, forKey: "lastSyncTime")
        print("🔄 SyncScheduler: Saved sync time: \(lastSyncTime!)")
    }
    
    // MARK: - Sync Methods
    
    /// Trigger sync immediately (called on app launch or foreground)
    func syncOnAppLaunch() async {
        print("🔄 SyncScheduler: ===== SYNC ON APP LAUNCH =====")

        // First, check connection health to detect any issues early
        await checkConnectionHealthBeforeSync()

        // Check if we synced recently (within minimum interval)
        if let lastSync = lastSyncTime,
           Date().timeIntervalSince(lastSync) < minimumSyncInterval {
            print("🔄 SyncScheduler: Skipping sync - synced \(Int(Date().timeIntervalSince(lastSync) / 60)) minutes ago")
            return
        }

        await performSync(reason: "app_launch")
    }

    /// Check connection health before syncing to detect reconnection needs early
    private func checkConnectionHealthBeforeSync() async {
        print("🏥 SyncScheduler: Checking connection health...")

        do {
            let health = try await apiService.checkConnectionHealth()

            if health.healthy {
                print("✅ SyncScheduler: All connections healthy")
            } else if health.needsReconnect {
                print("⚠️ SyncScheduler: One or more connections need reconnection")
                // The APIService.checkConnectionHealth already posts notifications
                // which will be handled by CalendarViewModel to show alerts
            } else {
                print("⚠️ SyncScheduler: Some connections have issues but don't require reconnection")
            }
        } catch {
            // Don't block sync if health check fails - just log and continue
            print("⚠️ SyncScheduler: Connection health check failed: \(error.localizedDescription)")
        }
    }
    
    /// Trigger sync when app comes to foreground
    func syncOnForeground() async {
        print("🔄 SyncScheduler: ===== SYNC ON FOREGROUND =====")
        
        // Always sync when coming to foreground (user might have changed calendar)
        await performSync(reason: "foreground")
    }
    
    /// Perform the actual sync
    private func performSync(reason: String, force: Bool = false) async {
        guard !isSyncing else {
            print("🔄 SyncScheduler: Sync already in progress, skipping...")
            return
        }
        
        // Check authentication
        guard KeychainManager.shared.hasValidTokens() else {
            print("🔄 SyncScheduler: No valid tokens, skipping sync")
            return
        }
        
        // Check timing constraints (unless forced)
        if !force {
            if let lastSync = lastSyncTime,
               Date().timeIntervalSince(lastSync) < minimumSyncInterval {
                print("🔄 SyncScheduler: Skipping sync - synced \(Int(Date().timeIntervalSince(lastSync) / 60)) minutes ago (minimum: \(Int(minimumSyncInterval / 60)) minutes)")
                return
            }
        } else {
            print("🔄 SyncScheduler: Force sync - ignoring timing constraints")
        }
        
        isSyncing = true
        syncError = nil
        
        print("🔄 SyncScheduler: ===== STARTING SYNC (reason: \(reason), force: \(force)) =====")
        print("🔄 SyncScheduler: Calling backend sync endpoint...")
        
        do {
            // Sync both Google and Microsoft calendars
            var totalEventsSynced = 0
            var syncResponse: SyncResponse?
            
            // Sync Google Calendar
            do {
                print("🔄 SyncScheduler: Starting Google Calendar sync...")
                let googleSyncResponse = try await apiService.syncGoogleCalendar()
                totalEventsSynced += googleSyncResponse.eventsSynced
                syncResponse = googleSyncResponse
                print("✅ SyncScheduler: Google Calendar sync completed - \(googleSyncResponse.eventsSynced) events synced")
                print("✅ SyncScheduler: Sync status: \(googleSyncResponse.status)")
                
                // Check if sync failed
                if googleSyncResponse.status.lowercased() == "failed" {
                    print("❌ SyncScheduler: Google Calendar sync failed with status: \(googleSyncResponse.status)")
                    print("❌ SyncScheduler: Error message: \(googleSyncResponse.message)")
                }
            } catch {
                print("❌ SyncScheduler: Google Calendar sync failed: \(error.localizedDescription)")
                print("❌ SyncScheduler: Error type: \(type(of: error))")
            }
            
            // Sync Microsoft Calendar
            do {
                let microsoftSyncResponse = try await apiService.syncMicrosoftCalendar()
                totalEventsSynced += microsoftSyncResponse.eventsSynced
                if syncResponse == nil {
                    syncResponse = microsoftSyncResponse
                }
                print("✅ SyncScheduler: Microsoft Calendar synced - \(microsoftSyncResponse.eventsSynced) events")
            } catch {
                print("⚠️ SyncScheduler: Microsoft Calendar sync failed: \(error.localizedDescription)")
            }
            
            guard let finalSyncResponse = syncResponse else {
                throw NSError(domain: "SyncScheduler", code: -1, userInfo: [NSLocalizedDescriptionKey: "All sync attempts failed"])
            }
            
            print("✅ SyncScheduler: ===== SYNC COMPLETED SUCCESSFULLY =====")
            print("✅ SyncScheduler: Total events synced: \(totalEventsSynced)")
            print("✅ SyncScheduler: Google Calendar events: \(finalSyncResponse.eventsSynced)")
            print("✅ SyncScheduler: Status: \(finalSyncResponse.status)")
            print("✅ SyncScheduler: Message: \(finalSyncResponse.message)")
            print("✅ SyncScheduler: User ID: \(finalSyncResponse.userId)")
            
            if finalSyncResponse.eventsSynced == 0 && totalEventsSynced == 0 {
                print("⚠️ SyncScheduler: ===== WARNING: SYNC RETURNED 0 EVENTS =====")
                print("⚠️ SyncScheduler: This could mean:")
                print("   1. Google Calendar is empty (no events in date range)")
                print("   2. Events are outside the sync date range")
                print("   3. Google API returned no events (permissions issue?)")
                print("   4. Backend sync logic may not be fetching events correctly")
                print("⚠️ SyncScheduler: Check backend logs for sync details")
            } else {
                print("✅ SyncScheduler: Successfully synced \(totalEventsSynced) total events (Google: \(finalSyncResponse.eventsSynced))")
            }
            
            saveLastSyncTime()
            
            // Post notification for UI to refresh (with sync status)
            NotificationCenter.default.post(
                name: NSNotification.Name("CalendarSynced"),
                object: nil,
                userInfo: [
                    "status": finalSyncResponse.status,
                    "eventsSynced": finalSyncResponse.eventsSynced
                ]
            )
            
        } catch {
            let errorMsg = error.localizedDescription
            syncError = errorMsg
            
            // UPDATED: Check for transient failure (new error format)
            if let nsError = error as NSError?,
               let errorType = nsError.userInfo["error_type"] as? String,
               errorType == "transient_failure" {
                let retryable = nsError.userInfo["retryable"] as? Bool ?? true
                let provider = nsError.userInfo["provider"] as? String ?? "calendar"
                
                print("⚠️ SyncScheduler: ===== TRANSIENT FAILURE DETECTED =====")
                print("⚠️ SyncScheduler: Transient failure - retryable: \(retryable)")
                print("⚠️ SyncScheduler: Provider: \(provider)")
                print("⚠️ SyncScheduler: Error: \(errorMsg)")
                
                if retryable {
                    syncError = "\(provider.capitalized) Calendar sync failed temporarily. Please try again."
                } else {
                    syncError = errorMsg
                }
            } else {
                print("❌ SyncScheduler: ===== SYNC FAILED =====")
                print("❌ SyncScheduler: Error: \(errorMsg)")
                print("❌ SyncScheduler: Error type: \(type(of: error))")
                if let nsError = error as NSError? {
                    print("❌ SyncScheduler: Error domain: \(nsError.domain), code: \(nsError.code)")
                    if let userInfo = nsError.userInfo as? [String: Any] {
                        print("❌ SyncScheduler: Error userInfo: \(userInfo)")
                    }
                }
            }
            
            // Don't save sync time on error
        }
        
        isSyncing = false
        print("🔄 SyncScheduler: ===== SYNC PROCESS COMPLETE =====")
    }
    
    // MARK: - Periodic Sync
    
    /// Start periodic sync timer
    func startPeriodicSync() {
        print("🔄 SyncScheduler: Starting periodic sync (interval: \(syncInterval / 60) minutes)")
        
        // Stop existing timer
        stopPeriodicSync()
        
        // Create timer that fires every syncInterval
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performSync(reason: "periodic")
            }
        }
        
        // Make timer work in background
        if let timer = syncTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    /// Stop periodic sync timer
    func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        print("🔄 SyncScheduler: Stopped periodic sync")
    }
    
    
    // MARK: - Manual Sync
    
    /// Manually trigger sync (for user-initiated sync or when events are needed)
    func manualSync() async {
        print("🔄 SyncScheduler: Manual sync triggered")
        // Check if last sync was more than 1 hour ago - if so, force sync
        if let lastSync = lastSyncTime {
            let hoursSinceSync = Date().timeIntervalSince(lastSync) / 3600
            if hoursSinceSync > 1 {
                print("🔄 SyncScheduler: Last sync was \(Int(hoursSinceSync)) hours ago - forcing sync")
                await performSync(reason: "manual (stale)", force: true)
            } else {
                await performSync(reason: "manual")
            }
        } else {
            await performSync(reason: "manual", force: true)
        }
    }
    
    /// Force sync regardless of timing (used when no events found or user requests)
    func forceSync() async {
        print("🔄 SyncScheduler: Force sync triggered (ignoring timing constraints)")
        await performSync(reason: "force", force: true)
    }
}

