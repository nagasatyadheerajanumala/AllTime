import Foundation
import HealthKit
import Combine
import UIKit

/// Simplified HealthKit permission orchestration.
/// Apple only exposes write-authorization status; read access cannot be inferred.
/// This manager now focuses solely on showing the permission sheet when needed and
/// always attempts to read after the user has been prompted once.
final class HealthKitManager: ObservableObject {
    
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()
    
    // Published so the UI can reflect whether we've prompted the user yet.
    @Published var permissionState: HealthPermissionState = .unknown
    
    enum HealthPermissionState {
        case unknown
        case notDetermined
        case requesting
        case authorized
        case denied
    }
    
    private init() {
        printRuntimeInfo()
    }
    
    var readTypes: Set<HKObjectType> { HealthKitTypes.all }
    
    /// Entry point used across the app. It matches the snippet from the user request:
    /// - Only checks for `.notDetermined` to decide if we must present the sheet.
    /// - Always calls the completion handler so callers can continue syncing.
    func ensureHealthKitReady(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit unavailable on this device")
            permissionState = .denied
            completion(false)
            return
        }
        
        let needsRequest = HealthKitTypes.all.contains {
            healthStore.authorizationStatus(for: $0) == .notDetermined
        }
        
        if needsRequest {
            permissionState = .notDetermined
            requestAuthorization(completion: completion)
        } else {
            permissionState = .authorized
            completion(true)
        }
    }
    
    /// Async/await convenience wrapper.
    func ensureHealthKitReady() async -> Bool {
        await withCheckedContinuation { continuation in
            ensureHealthKitReady { ready in
                continuation.resume(returning: ready)
            }
        }
    }
    
    /// Wrapper used by older call sites that expected a synchronous trigger.
    func safeRequestIfNeeded() {
        ensureHealthKitReady { _ in }
    }
    
    /// Called when the app re-enters the foreground. It simply re-runs the ready check.
    func forceRecheckAuthorization() {
        safeRequestIfNeeded()
    }
    
    /// Helpful diagnostics for internal builds.
    func diagnoseHealthKitSetup() {
        print("\n🔬 ===== HEALTHKIT DIAGNOSTIC =====")
        let available = HKHealthStore.isHealthDataAvailable()
        print("1. HealthKit Available: \(available ? "✅" : "❌")")
        let canCreateStepType = HKQuantityType.quantityType(forIdentifier: .stepCount) != nil
        print("2. Can Create HealthKit Types: \(canCreateStepType ? "✅" : "❌")")
        
        print("3. Authorization Sheet Needed:")
        for type in HealthKitTypes.all {
            let status = healthStore.authorizationStatus(for: type)
            let icon = status == .notDetermined ? "⚠️" : "ℹ️"
            print("   \(icon) \(HealthKitTypes.typeName(type)): \(status)")
        }
        print("=================================\n")
    }
    
    // MARK: - Private helpers
    
    private func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard UIApplication.shared.applicationState == .active else {
            print("⚠️ Cannot show HealthKit sheet while app state = \(UIApplication.shared.applicationState.rawValue)")
            completion(false)
            return
        }
        
        permissionState = .requesting
        logPlannedRequestStatusPrediction()
        
        healthStore.requestAuthorization(toShare: [], read: HealthKitTypes.all) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ HealthKit authorization error: \(error.localizedDescription)")
                } else {
                    print("✅ HealthKit authorization finished (success: \(success))")
                }
                // Regardless of the result, we proceed with reads. Apple does not expose read status.
                self.permissionState = .authorized
                completion(error == nil)
            }
        }
    }
    
    private func printRuntimeInfo() {
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        print("🏥 HealthKitManager Init — Bundle: \(bundleID)")
    }
    
    private func logPlannedRequestStatusPrediction() {
        healthStore.getRequestStatusForAuthorization(toShare: [], read: HealthKitTypes.all) { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🧪 getRequestStatus error: \(error.localizedDescription)")
                    return
                }
                let description: String
                switch status {
                case .shouldRequest: description = "shouldRequest"
                case .unnecessary: description = "unnecessary"
                case .unknown: fallthrough
                @unknown default: description = "unknown"
                }
                print("🧪 Predicted request status: \(description)")
            }
        }
    }
}
