import Foundation
import HealthKit
import Combine
import UIKit

/// Handles HealthKit permissions safely
final class HealthKitManager: ObservableObject {

    static let shared = HealthKitManager()
    private init() { printRuntimeInfo() }

    let healthStore = HKHealthStore()

    // MARK: - Permission State
    @Published var permissionState: HealthPermissionState = .unknown

    enum HealthPermissionState {
        case unknown
        case notDetermined
        case requesting
        case authorized
        case denied
    }

    private var hasRequested = false
    private let lock = NSLock()

    // MARK: - Required HK Types
    // CRITICAL: Use CANONICAL source - HealthKitTypes.all
    // This ensures EXACT same instances for requestAuthorization and authorizationStatus
    var readTypes: Set<HKObjectType> {
        return HealthKitTypes.all
    }

    // MARK: - Safe Permission Request
    func safeRequestIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

        // CRITICAL: Check app state first
        guard UIApplication.shared.applicationState == .active else {
            print("⚠️ HealthKit: App is NOT active (state: \(UIApplication.shared.applicationState.rawValue))")
            print("   Will check when app becomes active")
            return
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            permissionState = .denied
            print("❌ HealthKit unavailable on this device.")
            return
        }

        // CRITICAL: Log bundle ID for verification
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        print("🔐 HealthKit: Checking authorization (Bundle: \(bundleID))")

        // Evaluate current statuses using canonical types
        let statuses = HealthKitTypes.all.map { healthStore.authorizationStatus(for: $0) }

        let allDenied = statuses.allSatisfy { $0 == .sharingDenied }
        let allUnknown = statuses.allSatisfy { $0 == .notDetermined }
        let someUnknown = statuses.contains { $0 == .notDetermined }
        let someAuthorized = statuses.contains { $0 == .sharingAuthorized }

        // CRITICAL: Log current statuses before deciding
        print("🔐 Current authorization statuses (using canonical types):")
        HealthKitTypes.debugPrintInstanceAddresses()
        for (index, type) in HealthKitTypes.all.enumerated() {
            let status = statuses[index]
            let icon = status == .sharingAuthorized ? "✅" : (status == .sharingDenied ? "❌" : "⚠️")
            let typeName = HealthKitTypes.typeName(type)
            print("   \(icon) \(typeName): \(status)")
        }

        if allDenied {
            permissionState = .denied
            print("⚠️ ALL permissions denied — iOS will NOT show popup.")
            print("   User must enable in Settings → Health → Data Access & Devices → AllTime")
            return
        }

        if allUnknown || someUnknown {
            permissionState = .requesting
            print("🔐 Some types not determined - will request authorization")
            // Small delay to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.requestPermissions()
            }
            return
        }

        if someAuthorized {
            permissionState = .authorized
            print("✅ Already authorized.")
            return
        }

        permissionState = .denied
        print("⚠️ Unknown state → marking as denied.")
    }

    // MARK: - Actual Request
    private func requestPermissions() {
        lock.lock()
        defer { lock.unlock() }

        guard !hasRequested else {
            print("⚠️ HealthKit authorization already requested in this session")
            return
        }
        
        // CRITICAL: Check app state - request ONLY when app is active
        guard UIApplication.shared.applicationState == .active else {
            print("❌ CRITICAL: App is NOT active - cannot request HealthKit authorization")
            print("   App state: \(UIApplication.shared.applicationState.rawValue)")
            print("   Will retry when app becomes active")
            hasRequested = false // Allow retry when app becomes active
            return
        }
        
        hasRequested = true

        // CRITICAL: Verify bundle identifier matches
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        print("🔐 ===== HEALTHKIT AUTHORIZATION REQUEST =====")
        print("🔐 Bundle ID: \(bundleID)")
        print("🔐 App State: \(UIApplication.shared.applicationState.rawValue) (must be 0 = active)")
        print("🔐 Requesting \(HealthKitTypes.all.count) types in SINGLE call:")
        print("🔐 Using canonical HealthKitTypes.all (same instances for request + status check)")
        
        // Log each type
        for (index, type) in HealthKitTypes.all.enumerated() {
            let typeName = HealthKitTypes.typeName(type)
            print("   \(index + 1). \(typeName)")
        }
        
        // CRITICAL: Verify toShare is empty
        let toShareSet: Set<HKSampleType> = []
        print("🔐 toShare: \(toShareSet.count) types (MUST be 0 - read-only)")
        print("🔐 toRead: \(HealthKitTypes.all.count) types")
        
        // CRITICAL: Verify we're using canonical types
        print("✅ Using canonical HealthKitTypes.all (\(HealthKitTypes.all.count) types)")
        HealthKitTypes.debugPrintInstanceAddresses()

        // CRITICAL: Request all 8 types in a single call with empty toShare
        // Use canonical HealthKitTypes.all - EXACT same instances for status checks
        print("🔐 Calling requestAuthorization with canonical HealthKitTypes.all")
        healthStore.requestAuthorization(toShare: toShareSet, read: HealthKitTypes.all) { success, error in
            print("🔐 Authorization callback received:")
            print("   success: \(success)")
            if let error = error {
                print("   error: \(error.localizedDescription)")
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.permissionState = .denied
                    print("❌ Authorization request error:", error.localizedDescription)
                }
                return
            }
            
            print("🔐 Authorization request completed. Waiting 1.5s for iOS to update internal state...")
            
            // CRITICAL FIX: iOS needs 1.5 seconds to update authorization status after popup
            // Do NOT check immediately - delay the re-check
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.recheckAuthorizationStatus()
            }
        }
    }
    
    // MARK: - Delayed Re-check (CRITICAL FIX)
    private func recheckAuthorizationStatus() {
        lock.lock()
        defer { lock.unlock() }
        
        print("\n🔐 ===== RE-CHECKING AUTHORIZATION STATUS =====")
        print("🔐 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("🔐 Time since request: 1.5s")
        
        // CRITICAL: Re-create types to ensure we're checking the SAME instances
        // This ensures we're checking the exact types that were requested
        let typesToCheck = HealthKitTypes.all
        
        // Check actual authorization status after delay
        var statuses: [(type: HKObjectType, status: HKAuthorizationStatus, identifier: String)] = []
        for type in typesToCheck {
            let status = healthStore.authorizationStatus(for: type)
            // Workout type has no identifier, use "HKWorkoutType"
            let identifier = type is HKWorkoutType ? "HKWorkoutType" : type.identifier
            statuses.append((type: type, status: status, identifier: identifier))
        }
        
        let authorizedCount = statuses.filter { $0.status == .sharingAuthorized }.count
        let deniedCount = statuses.filter { $0.status == .sharingDenied }.count
        let notDeterminedCount = statuses.filter { $0.status == .notDetermined }.count
        
        print("🔐 Authorization Status Summary:")
        print("   - Authorized: \(authorizedCount)/\(statuses.count)")
        print("   - Denied: \(deniedCount)/\(statuses.count)")
        print("   - Not Determined: \(notDeterminedCount)/\(statuses.count)")
        print("\n🔐 Detailed Status for Each Type:")
        
        // Log each type's status with exact identifier (workout type has no identifier)
        for item in statuses.sorted(by: { item1, item2 in
            let id1 = item1.type is HKWorkoutType ? "HKWorkoutType" : item1.identifier
            let id2 = item2.type is HKWorkoutType ? "HKWorkoutType" : item2.identifier
            return id1 < id2
        }) {
            let icon: String
            switch item.status {
            case .sharingAuthorized:
                icon = "✅"
            case .sharingDenied:
                icon = "❌"
            case .notDetermined:
                icon = "⚠️"
            @unknown default:
                icon = "❓"
            }
            let typeName = item.type is HKWorkoutType ? "HKWorkoutType" : item.identifier
            print("   \(icon) \(typeName) → \(item.status)")
        }
        
        // CRITICAL: If all are denied but user enabled in Settings, there's a mismatch
        if deniedCount == statuses.count {
            print("\n❌ CRITICAL ISSUE: All types show .sharingDenied")
            print("   This means either:")
            print("   1. User denied in popup (check if popup appeared)")
            print("   2. Types requested don't match types in Settings")
            print("   3. Bundle ID mismatch")
            print("   4. Request happened before app was active")
            print("\n   VERIFICATION:")
            print("   - Check Settings → Health → Data Access & Devices → AllTime")
            print("   - Verify bundle ID matches: \(Bundle.main.bundleIdentifier ?? "unknown")")
            print("   - If permissions are ON in Settings but denied here → TYPE MISMATCH")
            
            permissionState = .denied
        } else if authorizedCount > 0 {
            permissionState = .authorized
            print("\n✅ HealthKit authorized for \(authorizedCount) of \(statuses.count) types")
            
            // Trigger sync if authorized
            Task { @MainActor in
                await HealthSyncService.shared.syncRecentDays()
            }
        } else {
            // Some not determined - might need another request
            permissionState = .denied
            print("\n⚠️ HealthKit permissions not fully determined after request")
            print("   Some types still .notDetermined - request may not have completed")
        }
        
        print("==========================================\n")
    }

    // MARK: - Debug Info
    private func printRuntimeInfo() {
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        print("🏥 HealthKitManager Init — Bundle:", bundleID)
    }

    func debugPrintStatuses() {
        print("\n🔍 HealthKit Authorization Statuses")
        print("🔍 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        for type in HealthKitTypes.all {
            let s = healthStore.authorizationStatus(for: type)
            let icon = s == .sharingAuthorized ? "✅" : (s == .sharingDenied ? "❌" : "⚠️")
            let typeName = HealthKitTypes.typeName(type)
            print("   \(icon) \(typeName) → \(s)")
        }
        print("=================================\n")
    }
    
    /// Force re-check authorization status (useful when app becomes active after user enables in Settings)
    func forceRecheckAuthorization() {
        lock.lock()
        defer { lock.unlock() }
        
        print("🔐 Force re-checking HealthKit authorization...")
        print("🔐 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("🔐 App State: \(UIApplication.shared.applicationState.rawValue)")
        
        // Re-check all statuses using canonical types
        let statuses = HealthKitTypes.all.map { healthStore.authorizationStatus(for: $0) }
        let authorizedCount = statuses.filter { $0 == .sharingAuthorized }.count
        let deniedCount = statuses.filter { $0 == .sharingDenied }.count
        
        print("🔐 Re-check results:")
        print("   - Authorized: \(authorizedCount)/\(statuses.count)")
        print("   - Denied: \(deniedCount)/\(statuses.count)")
        
        for (index, type) in HealthKitTypes.all.enumerated() {
            let status = statuses[index]
            let icon = status == .sharingAuthorized ? "✅" : (status == .sharingDenied ? "❌" : "⚠️")
            let typeName = type is HKWorkoutType ? "HKWorkoutType" : type.identifier
            print("   \(icon) \(typeName): \(status)")
        }
        
        if authorizedCount > 0 {
            permissionState = .authorized
            print("✅ HealthKit authorization detected - \(authorizedCount) types authorized")
            
            // Trigger sync
            Task { @MainActor in
                await HealthSyncService.shared.syncRecentDays()
            }
        } else if deniedCount == statuses.count {
            permissionState = .denied
            print("❌ All types still denied")
        }
    }
    
    /// Diagnostic function to check if HealthKit capability is properly configured
    func diagnoseHealthKitSetup() {
        print("\n🔬 ===== HEALTHKIT DIAGNOSTIC =====")
        
        // Check 1: HealthKit availability
        let isAvailable = HKHealthStore.isHealthDataAvailable()
        print("1. HealthKit Available: \(isAvailable ? "✅" : "❌")")
        
        // Check 2: Can create types (entitlements check)
        let canCreateStepType = HKQuantityType.quantityType(forIdentifier: .stepCount) != nil
        print("2. Can Create HealthKit Types: \(canCreateStepType ? "✅" : "❌")")
        if !canCreateStepType {
            print("   ⚠️ HealthKit capability may not be in provisioning profile!")
            print("   ⚠️ Delete app, clean build, and reinstall")
        }
        
        // Check 3: Current authorization statuses
        print("3. Authorization Statuses:")
        var authorizedCount = 0
        var deniedCount = 0
        var notDeterminedCount = 0
        
        for type in HealthKitTypes.all {
            let status = healthStore.authorizationStatus(for: type)
            let statusIcon: String
            switch status {
            case .sharingAuthorized:
                statusIcon = "✅"
                authorizedCount += 1
            case .sharingDenied:
                statusIcon = "❌"
                deniedCount += 1
            case .notDetermined:
                statusIcon = "⚠️"
                notDeterminedCount += 1
            @unknown default:
                statusIcon = "❓"
            }
            let typeName = HealthKitTypes.typeName(type)
            print("   \(statusIcon) \(typeName): \(status)")
        }
        
        print("\n4. Summary:")
        print("   - Authorized: \(authorizedCount)/\(HealthKitTypes.all.count)")
        print("   - Denied: \(deniedCount)/\(HealthKitTypes.all.count)")
        print("   - Not Determined: \(notDeterminedCount)/\(HealthKitTypes.all.count)")
        
        if deniedCount == HealthKitTypes.all.count && canCreateStepType {
            print("\n⚠️ ALL TYPES DENIED BUT CAPABILITY EXISTS")
            print("   → Permissions were denied in Settings")
            print("   → Go to: Settings → Health → Data Access & Devices → AllTime")
            print("   → Enable all health data types")
            print("   → Then force quit and reopen app")
        } else if deniedCount == HealthKitTypes.all.count && !canCreateStepType {
            print("\n❌ ALL TYPES DENIED AND CAN'T CREATE TYPES")
            print("   → HealthKit capability NOT in provisioning profile!")
            print("   → Solution:")
            print("     1. Delete app completely")
            print("     2. Clean build folder (Shift+Cmd+K)")
            print("     3. Rebuild and reinstall")
            print("     4. Verify capability in Xcode: Signing & Capabilities")
        }
        
        print("=================================\n")
    }
}
