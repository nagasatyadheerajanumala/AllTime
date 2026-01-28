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
    // AppDelegate adapter to handle APNs device token registration
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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

    // Navigation manager for global tab control
    @ObservedObject private var navigationManager = NavigationManager.shared
    
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
                .environmentObject(navigationManager)
                .preferredColorScheme(themeManager.colorScheme) // Use ThemeManager for light/dark/system
                .onOpenURL { url in
                    print("🔵 AllTimeApp: ===== DEEP LINK RECEIVED =====")
                    print("🔵 AllTimeApp: Full URL: \(url.absoluteString)")
                    print("🔵 AllTimeApp: Scheme: \(url.scheme ?? "nil")")
                    print("🔵 AllTimeApp: Host: \(url.host ?? "nil")")
                    print("🔵 AllTimeApp: Path: \(url.path)")
                    print("🔵 AllTimeApp: Query: \(url.query ?? "nil")")
                    
                    // Handle deep links for OAuth callbacks
                    if url.scheme == Constants.OAuth.callbackScheme {
                        print("🔵 AllTimeApp: OAuth callback scheme matched: \(Constants.OAuth.callbackScheme)")
                        
                        if url.host == "oauth" {
                            print("🔵 AllTimeApp: OAuth callback host matched: oauth")
                            
                            // Parse query parameters
                            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                            let queryItems = components?.queryItems ?? []
                            
                            // Check if it's a success or error callback
                            if url.path.contains("success") || url.path == "/success" {
                                print("✅ AllTimeApp: ===== OAUTH SUCCESS CALLBACK =====")
                                
                                // Extract authorization code if present
                                if let code = queryItems.first(where: { $0.name == "code" })?.value {
                                    print("🔵 AllTimeApp: Authorization code found: \(code.prefix(10))...")
                                }
                                
                                // Extract provider if specified
                                let provider = queryItems.first(where: { $0.name == "provider" })?.value ?? "unknown"
                                print("🔵 AllTimeApp: Provider: \(provider)")
                                
                                // Post notification for OAuth managers to handle
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("OAuthSuccess"),
                                    object: nil,
                                    userInfo: [
                                        "url": url,
                                        "provider": provider,
                                        "code": queryItems.first(where: { $0.name == "code" })?.value as Any
                                    ]
                                )
                                
                                // Also notify GoogleAuthManager and MicrosoftAuthManager directly
                                if provider == "google" || provider == "unknown" {
                                    print("🔵 AllTimeApp: Notifying GoogleAuthManager")
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("GoogleOAuthDeepLink"),
                                        object: nil,
                                        userInfo: ["url": url]
                                    )
                                }
                                
                                if provider == "microsoft" || provider == "unknown" {
                                    print("🔵 AllTimeApp: Notifying MicrosoftAuthManager")
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("MicrosoftOAuthDeepLink"),
                                        object: nil,
                                        userInfo: ["url": url]
                                    )
                                }
                                
                            } else if url.path.contains("error") || url.path == "/error" {
                                print("❌ AllTimeApp: ===== OAUTH ERROR CALLBACK =====")
                                
                                // Parse error message
                                let errorMessage = queryItems.first(where: { $0.name == "message" })?.value ?? 
                                                 queryItems.first(where: { $0.name == "error" })?.value ?? 
                                                 "Unknown error"
                                
                                print("❌ AllTimeApp: Error message: \(errorMessage)")
                                
                                // Extract provider if specified
                                let provider = queryItems.first(where: { $0.name == "provider" })?.value ?? "unknown"
                                
                                // Post notification for OAuth managers to handle
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("OAuthError"),
                                    object: nil,
                                    userInfo: [
                                        "url": url,
                                        "error": errorMessage,
                                        "provider": provider
                                    ]
                                )
                                
                                // Also notify specific managers
                                if provider == "google" || provider == "unknown" {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("GoogleOAuthDeepLinkError"),
                                        object: nil,
                                        userInfo: ["error": errorMessage]
                                    )
                                }
                                
                                if provider == "microsoft" || provider == "unknown" {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("MicrosoftOAuthDeepLinkError"),
                                        object: nil,
                                        userInfo: ["error": errorMessage]
                                    )
                                }
                            } else {
                                print("⚠️ AllTimeApp: Unknown OAuth callback path: \(url.path)")
                            }
                        } else {
                            print("⚠️ AllTimeApp: OAuth callback but host is not 'oauth': \(url.host ?? "nil")")
                        }
                        
                        // Also route to OAuthManager for backward compatibility
                        oauthManager.handleOAuthCallback(url: url)
                    } else {
                        print("⚠️ AllTimeApp: Deep link with unknown scheme: \(url.scheme ?? "nil")")
                        // Handle other deep links
                        oauthManager.handleOAuthCallback(url: url)
                    }
                }
                .onAppear {
                    print("🚀 AllTimeApp: App launched successfully on device")
                    // Set up notification delegate
                    UNUserNotificationCenter.current().delegate = pushManager
                    // HealthKit permissions are requested automatically in HealthKitManager.init()

                    // Initialize notification services to schedule daily notifications
                    // These are singletons, accessing .shared triggers their init and schedules notifications
                    _ = MorningBriefingNotificationService.shared
                    _ = EveningSummaryNotificationService.shared
                    print("🔔 AllTimeApp: Morning and Evening notification services initialized")
                }
        }
    }
}
