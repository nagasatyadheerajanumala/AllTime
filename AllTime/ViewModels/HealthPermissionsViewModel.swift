import Foundation
import Combine
import SwiftUI
import HealthKit

/// ViewModel for managing Health permissions UI state
/// NOTE: Authorization is requested via HealthKitManager.safeRequestIfNeeded() after login
@MainActor
class HealthPermissionsViewModel: ObservableObject {
    @Published var isAuthorized = false
    @Published var isSyncing = false
    @Published var hasSyncedOnce = false
    @Published var showDeniedAlert = false
    @Published var errorMessage: String?
    
    private let healthSyncService = HealthSyncService.shared
    private let healthKitManager = HealthKitManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe sync state
        healthSyncService.$isSyncing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSyncing)
        
        // Observe HealthKitManager permission state
        healthKitManager.$permissionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] permissionState in
                self?.updateAuthorizationState(permissionState)
            }
            .store(in: &cancellables)
        
    }
    
    /// Update authorization state based on HealthKitManager permission state
    private func updateAuthorizationState(_ state: HealthKitManager.HealthPermissionState) {
        switch state {
        case .authorized:
            isAuthorized = true
            showDeniedAlert = false
            errorMessage = nil
        case .denied:
            isAuthorized = false
            showDeniedAlert = true
            errorMessage = "Health access is turned off for AllTime.\n\nTo sync your wellness insights, enable permissions:\n\nSettings → Health → Apps → AllTime → Turn All On."
        case .notDetermined, .requesting, .unknown:
            isAuthorized = false
            showDeniedAlert = false
            errorMessage = nil
        }
    }
    
    /// Refresh authorization state (call on view appear)
    func refreshAuthStateOnAppear() async {
        // Check current state from HealthKitManager
        let currentState = healthKitManager.permissionState
        
        switch currentState {
        case .authorized:
            isAuthorized = true
            showDeniedAlert = false
            errorMessage = nil
        case .denied:
            isAuthorized = false
            showDeniedAlert = true
            errorMessage = "Health access is turned off for AllTime.\n\nTo sync your wellness insights, enable permissions:\n\nSettings → Health → Apps → AllTime → Turn All On."
        case .notDetermined, .requesting, .unknown:
            isAuthorized = false
            showDeniedAlert = false
            errorMessage = nil
        }
        
        // Check if we've synced before
        hasSyncedOnce = healthSyncService.lastSyncDate != nil
    }
    
    /// Handle tap on "Enable Health Data" button
    /// If denied, opens Health app settings
    /// If not determined, triggers safeRequestIfNeeded
    func tapEnableHealthButton() async {
        errorMessage = nil
        
        // Check current state
        let currentState = healthKitManager.permissionState
        
        if currentState == .denied {
            // Open Health app settings (falls back to iOS Settings)
            HealthAppHelper.openHealthAppSettings()
        } else if currentState == .notDetermined || currentState == .unknown {
            // Request authorization
            healthKitManager.safeRequestIfNeeded()
        } else if currentState == .authorized {
            // Already authorized, trigger sync
            await triggerInitialSync()
        }
    }
    
    /// Trigger initial sync of last N days
    private func triggerInitialSync() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        errorMessage = nil
        
        // Sync last 14 days on first authorization
        await healthSyncService.syncLastNDaysToBackend(14)
        
        hasSyncedOnce = healthSyncService.lastSyncDate != nil
        isSyncing = false
    }
}
