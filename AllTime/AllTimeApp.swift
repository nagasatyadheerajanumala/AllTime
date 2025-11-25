//
//  AllTimeApp.swift
//  AllTime
//
//  Created by Naga Satya Dheeraj Anumala on 10/16/25.
//

import SwiftUI
import UserNotifications
import CoreLocation
import HealthKit
import os.log

@main
struct AllTimeApp: App {
    @State private var authService = AuthenticationService()
    @State private var userManager = UserManager()
    @State private var calendarManager = CalendarManager()
    @State private var summaryManager = SummaryManager()
    @State private var pushManager = PushNotificationManager.shared
    @State private var oauthManager = OAuthManager()
    
    // ViewModels
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var summaryViewModel = SummaryViewModel()
    @StateObject private var dailySummaryViewModel = DailySummaryViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    // Theme Manager
    @StateObject private var themeManager = ThemeManager()
    
    // Sync scheduler
    @StateObject private var syncScheduler = SyncScheduler.shared
    
    init() {
        print("🚀 AllTimeApp: ===== APP INITIALIZING =====")
        // DO NOT call HealthKitManager.shared here - it will trigger init too early
        // HealthKit permissions will be requested later when UI is ready and user is logged in
        print("🚀 AllTimeApp: HealthKit authorization will be requested after login and UI is ready")
        
        #if DEBUG
        print("🚀 AllTimeApp: DEBUG mode - call HealthKitManager.shared.printAllAuthorizationStatuses() to debug")
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(userManager)
                .environmentObject(calendarManager)
                .environmentObject(summaryManager)
                .environmentObject(pushManager)
                .environmentObject(oauthManager)
                .environmentObject(calendarViewModel)
                .environmentObject(summaryViewModel)
                .environmentObject(dailySummaryViewModel)
                .environmentObject(settingsViewModel)
                .environmentObject(syncScheduler)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .onOpenURL { url in
                    print("🔗 AllTimeApp: Received URL: \(url)")
                    // Handle deep links for OAuth callbacks
                    if url.scheme == Constants.OAuth.callbackScheme {
                        // Route to appropriate OAuth manager based on callback URL
                        // Both Google and Microsoft use the same callback scheme
                        // The backend will handle routing internally
                        if url.host == "oauth" {
                            // Check if it's a success or error callback
                            if url.path.contains("success") {
                                print("✅ AllTimeApp: OAuth success callback received")
                                // Both managers will handle their own callbacks via ASWebAuthenticationSession
                                // This is just a fallback for deep links
                            } else if url.path.contains("error") {
                                print("❌ AllTimeApp: OAuth error callback received")
                                // Parse error message
                                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                                   let message = components.queryItems?.first(where: { $0.name == "message" })?.value {
                                    print("❌ AllTimeApp: Error message: \(message)")
                                }
                            }
                        }
                        // Also route to OAuthManager for backward compatibility
                        oauthManager.handleOAuthCallback(url: url)
                    } else {
                        // Handle other deep links
                        oauthManager.handleOAuthCallback(url: url)
                    }
                }
                .onAppear {
                    print("🚀 AllTimeApp: App launched successfully on device")
                    // Set up notification delegate
                    UNUserNotificationCenter.current().delegate = pushManager
                    // HealthKit permissions are requested automatically in HealthKitManager.init()
                }
        }
    }
}
