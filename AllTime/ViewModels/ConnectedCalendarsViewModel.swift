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

    // Holiday sync preference
    @Published var syncHolidays: Bool = true
    @Published var isLoadingHolidayPreference = false

    // Discovered calendars (multi-calendar support)
    @Published var discoveredCalendars: [DiscoveredCalendar] = []
    @Published var isDiscovering = false
    @Published var isTogglingCalendar: Int? = nil  // Calendar ID being toggled

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

    /// Disconnect a specific calendar connection by ID (for multi-account support)
    func disconnectConnection(_ connectionId: Int) async {
        print("🗑️ ConnectedCalendarsViewModel: Disconnecting connection ID \(connectionId)...")

        errorMessage = nil
        successMessage = nil

        do {
            let response = try await apiService.disconnectConnection(connectionId)
            print("✅ ConnectedCalendarsViewModel: Connection disconnected successfully")
            print("   - Status: \(response.status)")
            print("   - Message: \(response.message)")

            // Show success message
            successMessage = response.message

            // Remove from local list
            calendars.removeAll { $0.id == connectionId }

            // Reload providers to ensure UI is in sync
            await loadProviders()

            // Clear success message after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                successMessage = nil
            }
        } catch let error as NSError {
            print("❌ ConnectedCalendarsViewModel: Failed to disconnect connection: \(error)")

            var errorMsg = "Failed to disconnect calendar"
            switch error.code {
            case 401:
                errorMsg = "Session expired. Please sign in again."
            case 404:
                errorMsg = "Calendar connection not found. It may have already been disconnected."
            case 403:
                errorMsg = "You don't have permission to disconnect this calendar."
            default:
                errorMsg = error.localizedDescription
            }

            errorMessage = errorMsg
        } catch {
            print("❌ ConnectedCalendarsViewModel: Failed to disconnect connection: \(error)")
            errorMessage = "Failed to disconnect calendar: \(error.localizedDescription)"
        }
    }

    // MARK: - Holiday Sync Preference

    /// Load the holiday sync preference from the server
    func loadHolidaySyncPreference() async {
        print("🎄 ConnectedCalendarsViewModel: Loading holiday sync preference...")
        isLoadingHolidayPreference = true

        do {
            let preference = try await apiService.getHolidaySyncPreference()
            syncHolidays = preference
            print("✅ ConnectedCalendarsViewModel: Holiday sync preference: \(preference ? "enabled" : "disabled")")
        } catch {
            print("❌ ConnectedCalendarsViewModel: Failed to load holiday sync preference: \(error)")
            // Default to true if we can't load the preference
            syncHolidays = true
        }

        isLoadingHolidayPreference = false
    }

    /// Update the holiday sync preference
    /// When disabled, existing holiday events will be deleted on the server
    func updateHolidaySyncPreference(_ enabled: Bool) async {
        print("🎄 ConnectedCalendarsViewModel: Updating holiday sync preference to: \(enabled ? "enabled" : "disabled")...")

        do {
            let updated = try await apiService.updateHolidaySyncPreference(syncHolidays: enabled)
            syncHolidays = updated

            if enabled {
                successMessage = "Holidays will be synced on next calendar sync"
            } else {
                successMessage = "Holidays have been removed from your calendar"
            }
            print("✅ ConnectedCalendarsViewModel: Holiday sync preference updated to: \(updated ? "enabled" : "disabled")")

            // Clear success message after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                successMessage = nil
            }
        } catch {
            print("❌ ConnectedCalendarsViewModel: Failed to update holiday sync preference: \(error)")
            // Revert the toggle
            syncHolidays = !enabled
            errorMessage = "Failed to update holiday preference: \(error.localizedDescription)"
        }
    }

    // MARK: - Discovered Calendars (Multi-Calendar Support)

    /// Group discovered calendars by provider
    var discoveredCalendarsByProvider: [String: [DiscoveredCalendar]] {
        Dictionary(grouping: discoveredCalendars, by: { $0.provider })
    }

    /// Check if there are any Microsoft calendars connected
    var hasMicrosoftConnection: Bool {
        calendars.contains { $0.provider.lowercased() == "microsoft" }
    }

    /// Check if there are any Google calendars connected
    var hasGoogleConnection: Bool {
        calendars.contains { $0.provider.lowercased() == "google" }
    }

    /// Load discovered calendars from the server
    func loadDiscoveredCalendars() async {
        print("📅 ConnectedCalendarsViewModel: Loading discovered calendars...")

        do {
            let response = try await apiService.getDiscoveredCalendars()
            discoveredCalendars = response.calendars
            print("✅ ConnectedCalendarsViewModel: Loaded \(response.count) discovered calendars")
        } catch {
            print("❌ ConnectedCalendarsViewModel: Failed to load discovered calendars: \(error)")
            // Don't show error to user - discovered calendars are optional
        }
    }

    /// Trigger calendar discovery for Microsoft
    func discoverMicrosoftCalendars() async {
        print("🔍 ConnectedCalendarsViewModel: Discovering Microsoft calendars...")
        isDiscovering = true
        errorMessage = nil

        do {
            let response = try await apiService.discoverMicrosoftCalendars()

            if response.success {
                if let calendars = response.calendars {
                    discoveredCalendars = calendars
                    successMessage = "Found \(response.count ?? 0) calendar(s)"
                    print("✅ ConnectedCalendarsViewModel: Discovered \(response.count ?? 0) Microsoft calendars")
                }
            } else {
                errorMessage = response.error ?? "Failed to discover calendars"
                print("❌ ConnectedCalendarsViewModel: Discovery failed: \(response.error ?? "unknown")")
            }

            // Clear success message after 3 seconds
            if successMessage != nil {
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    successMessage = nil
                }
            }
        } catch {
            print("❌ ConnectedCalendarsViewModel: Failed to discover calendars: \(error)")
            errorMessage = "Failed to discover calendars: \(error.localizedDescription)"
        }

        isDiscovering = false
    }

    /// Toggle a discovered calendar's enabled state
    func toggleCalendarEnabled(_ calendarId: Int, enabled: Bool) async {
        print("🔄 ConnectedCalendarsViewModel: Toggling calendar \(calendarId) to \(enabled ? "enabled" : "disabled")...")
        isTogglingCalendar = calendarId

        do {
            let response = try await apiService.toggleCalendarEnabled(calendarId: calendarId, enabled: enabled)

            if response.success {
                // Update local state
                if let index = discoveredCalendars.firstIndex(where: { $0.id == calendarId }) {
                    // Create updated calendar with new enabled state
                    let oldCalendar = discoveredCalendars[index]
                    let newEnabled = response.enabled ?? enabled

                    // We need to recreate the calendar since it's a struct
                    // For now, reload from server to get fresh state
                    await loadDiscoveredCalendars()
                }
                print("✅ ConnectedCalendarsViewModel: Calendar \(calendarId) toggled successfully")
            } else {
                errorMessage = response.error ?? "Failed to toggle calendar"
                print("❌ ConnectedCalendarsViewModel: Toggle failed: \(response.error ?? "unknown")")
            }
        } catch {
            print("❌ ConnectedCalendarsViewModel: Failed to toggle calendar: \(error)")
            errorMessage = "Failed to toggle calendar: \(error.localizedDescription)"
        }

        isTogglingCalendar = nil
    }

    /// Sync all enabled Microsoft calendars using multi-calendar sync
    func syncMicrosoftMultiCalendar() async {
        print("🔄 ConnectedCalendarsViewModel: Syncing Microsoft multi-calendar...")
        isSyncing = true

        do {
            let response = try await apiService.syncMicrosoftMultiCalendar()

            if response.success {
                successMessage = "Synced \(response.eventsProcessed) events from \(response.calendarsProcessed) calendar(s)"
                print("✅ ConnectedCalendarsViewModel: Multi-calendar sync complete - \(response.calendarsProcessed) calendars, \(response.eventsProcessed) events")

                // Reload events
                await loadUpcomingEvents()

                // Clear success message after 3 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    successMessage = nil
                }
            } else {
                errorMessage = response.error ?? "Failed to sync calendars"
                print("❌ ConnectedCalendarsViewModel: Multi-calendar sync failed: \(response.error ?? "unknown")")
            }
        } catch {
            print("❌ ConnectedCalendarsViewModel: Failed to sync multi-calendar: \(error)")
            errorMessage = "Failed to sync calendars: \(error.localizedDescription)"
        }

        isSyncing = false
    }
}

