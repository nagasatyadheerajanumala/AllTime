//
//  ContentView.swift
//  AllTime
//
//  Created by Naga Satya Dheeraj Anumala on 10/22/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var summaryManager: SummaryManager
    @EnvironmentObject var pushManager: PushNotificationManager
    @EnvironmentObject var calendarViewModel: CalendarViewModel
    
    @StateObject private var syncScheduler = SyncScheduler.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasDismissedProfileSetup = false

    var body: some View {
        Group {
            if authService.isAuthenticated {
                // Show profile setup only for new users who haven't completed profile
                // After user skips or completes, they go to main app
                // We use a state variable to track if user has dismissed the setup screen
                // Check hasDismissedProfileSetup FIRST to prevent re-evaluation during editing
                if !hasDismissedProfileSetup {
                    // Check if profile needs to be completed
                    if let user = authService.currentUser, 
                       let profileCompleted = user.profileCompleted, 
                       !profileCompleted {
                        ProfileSetupView(onDismiss: {
                            hasDismissedProfileSetup = true
                        })
                            .environmentObject(authService)
                    } else {
                        // Profile already completed or user object not available yet
                        // Show main app
                        PremiumTabView()
                    }
                } else {
                    // User has dismissed setup screen (completed or skipped)
                    PremiumTabView()
                }
            } else {
                SignInView()
            }
        }
        .onAppear {
            print("🔍 ContentView: Appeared, isAuthenticated: \(authService.isAuthenticated)")
            // Initialize app data when user is authenticated
            // But only if not on profile setup screen (to prevent premature navigation)
            if authService.isAuthenticated && hasDismissedProfileSetup {
                initializeAppData()
            }
            // NOTE: HealthKit permissions are requested in PremiumTabView.onAppear
            // This ensures UI is fully ready before requesting
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .onChange(of: authService.isAuthenticated) { oldValue, newValue in
            if newValue {
                // User just authenticated, sync immediately
                // Reset profile setup dismissal flag for new sign-in
                hasDismissedProfileSetup = false
                // Don't initialize app data here - wait until profile setup is done or skipped
                Task {
                    await syncScheduler.syncOnAppLaunch()
                }
            } else {
                // User signed out, stop periodic sync and reset flags
                syncScheduler.stopPeriodicSync()
                hasDismissedProfileSetup = false
            }
        }
        .onChange(of: hasDismissedProfileSetup) { oldValue, newValue in
            // When user dismisses profile setup (either by completing or skipping),
            // initialize app data if authenticated
            if newValue && authService.isAuthenticated {
                initializeAppData()
            }
        }
    }
    
    private func initializeAppData() {
        // User is already logged in, initialize app data
        userManager.fetchUserProfile()
        calendarManager.requestCalendarAccess()
        summaryManager.fetchTodaySummary()
        pushManager.registerForPushNotifications()
        
        // Start automated sync
        Task {
            // Sync immediately on app launch
            await syncScheduler.syncOnAppLaunch()
            
            // Sync health metrics on app launch (if authorized)
            await HealthSyncService.shared.syncRecentDays()
            
            // Start periodic sync (every 15 minutes while app is active)
            syncScheduler.startPeriodicSync()
        }
    }
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active (foreground)
            if authService.isAuthenticated {
                print("🔄 ContentView: App became active, triggering sync...")
                Task {
                    // CRITICAL: Re-check HealthKit authorization when app becomes active
                    // This handles the case where user enabled permissions in Settings while app was in background
                    HealthKitManager.shared.forceRecheckAuthorization()
                    
                    // Also check via HealthMetricsService
                    await HealthMetricsService.shared.checkAuthorizationStatus()
                    
                    await syncScheduler.syncOnForeground()
                    // Sync health metrics when app comes to foreground (if authorized)
                    await HealthSyncService.shared.syncRecentDays()
                }
            }
        case .inactive:
            print("🔄 ContentView: App became inactive")
        case .background:
            print("🔄 ContentView: App moved to background")
            // Stop periodic sync when app goes to background
            syncScheduler.stopPeriodicSync()
        @unknown default:
            break
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService())
}
