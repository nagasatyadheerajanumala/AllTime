import Foundation
import SwiftUI
import Combine

@MainActor
class ConnectedCalendarsViewModel: ObservableObject {
    @Published var calendars: [ConnectedCalendar] = []
    @Published var upcomingEvents: [CalendarEvent] = []
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let apiService = APIService()
    
    // Legacy compatibility - providers with calculated event counts
    var providers: [Provider] {
        calendars
    }
    
    // Get event count for a specific calendar
    func getEventCount(for calendar: ConnectedCalendar) -> Int {
        return eventCountForProvider(provider: calendar.provider)
    }
    
    var totalEventCount: Int {
        upcomingEvents.count
    }
    
    var lastSyncText: String {
        // Use SyncScheduler's lastSyncTime instead of createdAt
        if let lastSync = SyncScheduler.shared.lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: lastSync, relativeTo: Date())
        }
        return "Never"
    }
    
    // Calculate event count for a specific provider
    func eventCountForProvider(provider: String) -> Int {
        return upcomingEvents.filter { $0.source.lowercased() == provider.lowercased() }.count
    }
    
    // Calculate event count for today for a specific provider
    func eventCountForToday(provider: String) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return upcomingEvents.filter { event in
            guard event.source.lowercased() == provider.lowercased(),
                  let startDate = event.startDate else {
                return false
            }
            return startDate >= today && startDate < tomorrow
        }.count
    }
    
    func loadProviders() async {
        print("📅 ConnectedCalendarsViewModel: Loading calendars...")
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.getConnectedCalendars()
            calendars = response.calendars
            print("✅ ConnectedCalendarsViewModel: Loaded \(calendars.count) calendars")
            
            // Also load upcoming events
            await loadUpcomingEvents()
        } catch {
            print("❌ ConnectedCalendarsViewModel: Failed to load calendars: \(error)")
            errorMessage = "Failed to load calendars: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func loadUpcomingEvents(days: Int = 60) async {
        // Load 60 days to include past 30 days and future 30 days
        print("📅 ConnectedCalendarsViewModel: Loading upcoming events for \(days) days (past 30 + future 30)...")
        
        do {
            // Use getAllEvents with date range to get past 30 days + future 30 days
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            let endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
            
            let response = try await apiService.getAllEvents(start: startDate, end: endDate)
            upcomingEvents = response.events
            #if DEBUG
            print("✅ ConnectedCalendarsViewModel: Loaded \(response.totalEvents) events (from \(startDate) to \(endDate))")
            #endif
        } catch {
            #if DEBUG
            print("❌ ConnectedCalendarsViewModel: Failed to load events: \(error)")
            #endif
            // Fallback to upcoming events only if getAllEvents fails
            do {
                let response = try await apiService.getUpcomingEvents(days: days)
                upcomingEvents = response.events
                #if DEBUG
                print("✅ ConnectedCalendarsViewModel: Loaded \(response.totalEvents) upcoming events (fallback)")
                #endif
            } catch {
                print("❌ ConnectedCalendarsViewModel: Failed to load events (fallback): \(error)")
            }
        }
    }
    
    func syncProvider(_ providerId: Int) async {
        print("🔄 ConnectedCalendarsViewModel: Syncing provider \(providerId)...")
        isSyncing = true
        
        // Use sync scheduler for manual sync (handles errors internally)
        await SyncScheduler.shared.manualSync()
        
        // Check if sync had an error
        if let syncError = SyncScheduler.shared.syncError {
            errorMessage = "Failed to sync calendar: \(syncError)"
        }
        
        // Reload calendars and events
        await loadProviders()
        
        isSyncing = false
    }
    
    func syncGoogleCalendar() async {
        print("🔄 ConnectedCalendarsViewModel: Syncing Google Calendar...")
        isSyncing = true
        
        // Use sync scheduler for manual sync (handles errors internally)
        await SyncScheduler.shared.manualSync()
        
        // Check if sync had an error
        if let syncError = SyncScheduler.shared.syncError {
            errorMessage = "Failed to sync Google Calendar: \(syncError)"
        }
        
        // Reload calendars and events
        await loadProviders()
        
        isSyncing = false
    }
    
    func disconnectProvider(_ provider: String) async {
        print("🗑️ ConnectedCalendarsViewModel: Disconnecting provider '\(provider)'...")
        
        errorMessage = nil
        successMessage = nil
        
        do {
            let response = try await apiService.disconnectProvider(provider)
            print("✅ ConnectedCalendarsViewModel: Provider disconnected successfully")
            print("   - Status: \(response.status)")
            print("   - Message: \(response.message)")
            
            // Show success message
            successMessage = response.message
            
            // Remove from local list
            calendars.removeAll { $0.provider.lowercased() == provider.lowercased() }
            
            // Reload providers to ensure UI is in sync
            await loadProviders()
            
            // Clear success message after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                successMessage = nil
            }
        } catch let error as NSError {
            print("❌ ConnectedCalendarsViewModel: Failed to disconnect provider: \(error)")
            
            // Provide user-friendly error messages
            var errorMsg = "Failed to disconnect calendar"
            
            switch error.code {
            case 401:
                errorMsg = "Session expired. Please sign in again."
            case 404:
                errorMsg = "Calendar connection not found. It may have already been disconnected."
            case 400:
                errorMsg = error.localizedDescription
            default:
                errorMsg = error.localizedDescription
            }
            
            errorMessage = errorMsg
        } catch {
            print("❌ ConnectedCalendarsViewModel: Failed to disconnect provider: \(error)")
            errorMessage = "Failed to disconnect calendar: \(error.localizedDescription)"
        }
    }
}

