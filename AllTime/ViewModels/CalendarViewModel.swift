import Foundation
import Combine

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var selectedDate = Date()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRefreshing = false
    @Published var syncSuccessMessage: String?
    @Published var showReconnectAlert = false
    @Published var reconnectAlertMessage = ""
    
    // Sync status indicators
    @Published var isSyncing = false
    @Published var syncError: String?
    @Published var syncStatus: String? // "success" | "failed"
    @Published var showSyncError = false

    // Auto-reconnect flag to prevent duplicate OAuth attempts
    private var isAutoReconnecting = false
    
    private let apiService = APIService()
    private let cacheManager = EventCacheManager.shared
    private let cacheService = CacheService.shared
    private var cancellables = Set<AnyCancellable>()
    private var connectedProviders: Set<String> = [] // Track connected calendar providers
    
    // Pre-computed event indices by date (for O(1) lookup instead of O(n) filtering)
    private var eventsByDate: [Date: [Event]] = [:]
    private let calendar = Calendar.current
    
           init() {
               print("📅 CalendarViewModel: Initializing...")
               // Normalize initial selectedDate to start of day
               selectedDate = calendar.startOfDay(for: selectedDate)
               // Don't load events in init - let the view trigger loading on appear
               // This prevents duplicate loads and race conditions
               
               // Listen for sync completion notifications
               NotificationCenter.default.addObserver(
                   forName: NSNotification.Name("CalendarSynced"),
                   object: nil,
                   queue: .main
               ) { [weak self] _ in
                   Task { @MainActor [weak self] in
                       print("📅 CalendarViewModel: Received calendar sync notification, refreshing events...")
                       await self?.refreshEvents()
                   }
               }
               
               // Listen for Google Calendar connection notifications
               NotificationCenter.default.addObserver(
                   forName: NSNotification.Name("GoogleCalendarConnected"),
                   object: nil,
                   queue: .main
               ) { [weak self] _ in
                   Task { @MainActor [weak self] in
                       print("📅 CalendarViewModel: ===== GOOGLE CALENDAR RECONNECTED =====")
                       print("📅 CalendarViewModel: Received Google Calendar connection notification")
                       
                       // Step 1: Clear cache to force fresh sync
                       print("📅 CalendarViewModel: Step 1: Clearing cache after reconnection...")
                       self?.cacheManager.clearCache()
                       
                       // Step 2: Reload connected providers
                       print("📅 CalendarViewModel: Step 2: Reloading connected providers...")
                       await self?.loadConnectedProviders()
                       
                       // Step 3: Force a fresh sync
                       print("📅 CalendarViewModel: Step 3: Forcing fresh sync after reconnection...")
                       do {
                           let syncResponse = try await self?.apiService.syncGoogleCalendar()
                           print("✅ CalendarViewModel: Sync after reconnection completed: \(syncResponse?.eventsSynced ?? 0) events synced")
                       } catch {
                           print("❌ CalendarViewModel: Sync after reconnection failed: \(error.localizedDescription)")
                       }
                       
                       // Step 4: Refresh events to get newly synced data
                       print("📅 CalendarViewModel: Step 4: Refreshing events after reconnection...")
                       await self?.refreshEvents()
                   }
               }
               
               // Listen for Google Calendar token expiry notifications
               // Show error message instead of auto-triggering OAuth (which causes popup loops)
               NotificationCenter.default.addObserver(
                   forName: NSNotification.Name("GoogleCalendarTokenExpired"),
                   object: nil,
                   queue: .main
               ) { [weak self] notification in
                   Task { @MainActor [weak self] in
                       print("📅 CalendarViewModel: Received Google Calendar token expiry notification")
                       if let userInfo = notification.userInfo,
                          let errorMessage = userInfo["error"] as? String {
                           print("📅 CalendarViewModel: Token expiry error: \(errorMessage)")
                       }

                       guard let self = self else { return }

                       // Prevent duplicate notifications from triggering multiple alerts
                       guard !self.isAutoReconnecting else {
                           print("📅 CalendarViewModel: Already handling token expiry, skipping...")
                           return
                       }

                       self.isAutoReconnecting = true
                       self.reconnectProvider = "google"

                       // Show reconnect alert instead of auto-triggering OAuth
                       // This prevents the popup loop issue
                       print("📅 CalendarViewModel: Showing reconnect prompt for Google Calendar")
                       self.reconnectAlertMessage = "Your Google Calendar connection has expired. Please reconnect to continue syncing events."
                       self.showReconnectAlert = true

                       // Reset flag after a delay to allow retry if user dismisses
                       DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                           self.isAutoReconnecting = false
                       }
                   }
               }

               // Listen for Microsoft Calendar token expiry notifications
               // Auto-reconnect: Automatically trigger OAuth flow instead of showing alert
               NotificationCenter.default.addObserver(
                   forName: NSNotification.Name("MicrosoftCalendarTokenExpired"),
                   object: nil,
                   queue: .main
               ) { [weak self] notification in
                   Task { @MainActor [weak self] in
                       print("📅 CalendarViewModel: Received Microsoft Calendar token expiry notification")
                       if let userInfo = notification.userInfo,
                          let errorMessage = userInfo["error"] as? String {
                           print("📅 CalendarViewModel: Token expiry error: \(errorMessage)")
                       }

                       // AUTO-RECONNECT: Directly trigger OAuth flow for seamless UX
                       guard let self = self else { return }
                       print("📅 CalendarViewModel: Auto-triggering Microsoft OAuth reconnection flow...")
                       self.reconnectProvider = "microsoft"

                       // Automatically start the OAuth flow - no user action required
                       // TODO: Add MicrosoftAuthManager.shared.startMicrosoftOAuth() when Microsoft OAuth is implemented
                       // For now, show alert as fallback for Microsoft
                       self.reconnectAlertMessage = "Your Microsoft Calendar connection has expired. Please reconnect to continue syncing events."
                       self.showReconnectAlert = true
                   }
               }
               
               // Listen for event creation notifications
               NotificationCenter.default.addObserver(
                   forName: NSNotification.Name("EventCreated"),
                   object: nil,
                   queue: .main
               ) { [weak self] notification in
                   Task { @MainActor [weak self] in
                       print("📅 CalendarViewModel: Received event creation notification, refreshing events...")
                       if let eventResponse = notification.object as? CreateEventResponse {
                           print("📅 CalendarViewModel: Event '\(eventResponse.title)' was created")
                           print("   - Provider: \(eventResponse.syncStatus.provider)")
                           print("   - Synced: \(eventResponse.syncStatus.synced)")
                           if let attendeesCount = eventResponse.syncStatus.attendeesCount {
                               print("   - Attendees: \(attendeesCount)")
                           }
                       }
                       await self?.refreshEvents()
                   }
               }
           }
    
    func loadEvents() async {
        await loadEventsForViewMode(.month, selectedDate: selectedDate)
    }
    
    func loadEventsForViewMode(_ mode: CalendarViewMode, selectedDate: Date) async {
        #if DEBUG
        print("📅 CalendarViewModel: Loading events for mode: \(mode)")
        #endif
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            // Step 1: Load from cache first (instant UI update)
            let daysToFetch = 30
            print("📅 CalendarViewModel: ===== CACHE-FIRST LOADING =====")
            
            // Step 1a: Load connected providers first (needed for filtering)
            print("📅 CalendarViewModel: Step 1a: Loading connected providers...")
            await loadConnectedProviders()
            
            // Step 1b: Load and display cached events immediately
            if let cachedEvents = cacheManager.loadEvents(), cacheManager.hasCache() {
                // Filter on background, then update UI
                let filteredCached = await Task.detached(priority: .userInitiated) { [connectedProviders] in
                    return Self.filterEventsByConnectedProvidersStatic(cachedEvents, connectedProviders: connectedProviders)
                }.value
                
                await MainActor.run {
                    self.events = filteredCached
                    self.isLoading = false
                    // Rebuild index for fast lookups
                    self.rebuildEventIndex()
                }
                
                #if DEBUG
                print("💾 CalendarViewModel: Loaded \(filteredCached.count) cached events")
                #endif
            }
            
            print("📅 CalendarViewModel: ===== LOADING EVENTS FROM API =====")
            print("📅 CalendarViewModel: View mode: \(mode), days: \(daysToFetch), selected date: \(selectedDate)")
            print("📅 CalendarViewModel: Connected providers: \(connectedProviders)")
            
            // Step 2: Check if cache is valid or if we need to sync
            if cacheManager.isCacheValid() && cacheManager.hasCache() {
                print("💾 CalendarViewModel: Cache is valid - will check for updates in background")
            } else {
                print("💾 CalendarViewModel: Cache is invalid or missing - must fetch from API")
                isLoading = true // Show loading if no cache
            }
            
            // Step 3: Fetch events from API to check if we need to sync
            print("📅 CalendarViewModel: Step 3: Fetching events from API...")
            let initialResponse = try await apiService.getUpcomingEvents(days: daysToFetch)
            print("📅 CalendarViewModel: Found \(initialResponse.events.count) events from API")
            
            // Step 4: ALWAYS sync if we have connected providers AND no events (or events are stale)
            if !connectedProviders.isEmpty {
                var shouldSync: Bool
                
                if initialResponse.events.isEmpty {
                    print("📅 CalendarViewModel: Step 3: No events found - MUST SYNC to fetch from Google Calendar")
                    shouldSync = true
                } else {
                    // Check if we need to sync (if last sync was more than 1 hour ago, force sync)
                    print("📅 CalendarViewModel: Step 3: Events exist - checking if sync is needed...")
                    // Use sync scheduler to check if we should sync
                    if let lastSync = SyncScheduler.shared.lastSyncTime {
                        let timeSinceSync = Date().timeIntervalSince(lastSync)
                        let hoursSinceSync = timeSinceSync / 3600
                        // Sync if more than 1 hour has passed (to catch new events)
                        shouldSync = timeSinceSync > 3600 // 1 hour
                        print("📅 CalendarViewModel: Last sync was \(Int(hoursSinceSync)) hours ago - should sync: \(shouldSync)")
                        if hoursSinceSync > 24 {
                            print("⚠️ CalendarViewModel: Last sync was more than 24 hours ago - FORCING SYNC to get latest events")
                            shouldSync = true
                        }
                    } else {
                        // No sync recorded yet, should sync
                        shouldSync = true
                        print("📅 CalendarViewModel: No sync recorded - should sync")
                    }
                }
                
                if shouldSync {
                    print("📅 CalendarViewModel: Step 3: Syncing Google Calendar to fetch events...")
                    print("📅 CalendarViewModel: Connected providers: \(connectedProviders)")
                    print("📅 CalendarViewModel: This will fetch events from Google Calendar and store them in backend")
                    
                    // Always force sync to ensure we get latest events
                    print("📅 CalendarViewModel: Forcing sync to get latest events from Google Calendar...")
                    await SyncScheduler.shared.forceSync()
                    
                    // Wait a brief moment for sync to complete
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    
                    print("✅ CalendarViewModel: Sync completed")
                } else {
                    print("📅 CalendarViewModel: Step 3: Skipping sync - events are recent")
                }
            } else {
                print("📅 CalendarViewModel: Step 3: No connected providers - skipping sync")
                print("📅 CalendarViewModel: User needs to connect Google Calendar first")
            }
            
            // Step 5: Fetch events after sync (if sync was needed)
            // Fetch past 30 days + future 60 days to ensure we include the selected date and future months
            #if DEBUG
            print("📅 CalendarViewModel: Step 4: Fetching latest events from API (past 30 + future 60 days)...")
            #endif
            // Calculate date range to include selected date with buffer
            let calendar = Calendar.current
            let today = Date()
            let startDate = calendar.date(byAdding: .day, value: -30, to: today)!
            // Ensure end date includes selected date + buffer (at least 60 days from today, or selected date + 30 days, whichever is later)
            let selectedDatePlusBuffer = calendar.date(byAdding: .day, value: 30, to: selectedDate)!
            let future60Days = calendar.date(byAdding: .day, value: 60, to: today)!
            let endDate = max(selectedDatePlusBuffer, future60Days)
            
            print("📅 CalendarViewModel: Fetching events from \(startDate) to \(endDate)")
            print("📅 CalendarViewModel: Selected date: \(selectedDate)")
            
            // Format dates for logging
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
            dateFormatter.timeZone = TimeZone.current
            print("📅 CalendarViewModel: Start date (local): \(dateFormatter.string(from: startDate))")
            print("📅 CalendarViewModel: End date (local): \(dateFormatter.string(from: endDate))")
            print("📅 CalendarViewModel: Selected date (local): \(dateFormatter.string(from: selectedDate))")
            
            // Use the new structured GET /events endpoint
            let response = try await apiService.fetchEvents(startDate: startDate, endDate: endDate, period: "custom", autoSync: false)
            print("📅 CalendarViewModel: Step 5: API call successful, received \(response.events.count) events")
            
            // Diagnostic: Check if any events are in the selected date's month
            if response.events.count > 0 {
                let selectedComponents = calendar.dateComponents([.year, .month], from: selectedDate)
                let eventsInSelectedMonth = response.events.filter { event in
                    guard let eventDate = event.startDate else { return false }
                    let eventComponents = calendar.dateComponents([.year, .month], from: eventDate)
                    return eventComponents.year == selectedComponents.year && eventComponents.month == selectedComponents.month
                }
                print("📅 CalendarViewModel: Events in selected month (\(selectedComponents.year ?? 0)-\(selectedComponents.month ?? 0)): \(eventsInSelectedMonth.count)")
                
                // Show first few event dates
                let sortedEvents = response.events.sorted { event1, event2 in
                    guard let date1 = event1.startDate, let date2 = event2.startDate else { return false }
                    return date1 < date2
                }
                print("📅 CalendarViewModel: First 3 event dates from API:")
                for (idx, event) in sortedEvents.prefix(3).enumerated() {
                    if let eventDate = event.startDate {
                        print("📅 CalendarViewModel:   Event #\(idx + 1): '\(event.title)' on \(dateFormatter.string(from: eventDate))")
                    }
                }
            }
            
            // Step 6: Save to cache (both old and new cache systems)
            #if DEBUG
            print("💾 CalendarViewModel: Saving \(response.events.count) events to cache...")
            #endif
            cacheManager.saveEvents(response.events, daysFetched: daysToFetch)
            
            // Also save to new CacheService by month (async, non-blocking)
            Task.detached(priority: .utility) { [cacheService, selectedDate, response] in
                let calendar = Calendar.current
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
                await cacheService.cacheEvents(response.events, for: monthStart)
            }
            
            // Step 7: Process events on background, then update UI
            let allEvents = response.events
            
            // Filter on background thread (nonisolated function)
            let filteredEvents = await Task.detached(priority: .userInitiated) { [connectedProviders] in
                return Self.filterEventsByConnectedProvidersStatic(allEvents, connectedProviders: connectedProviders)
            }.value
            
            // Update UI on main actor - merge events instead of replacing to preserve future events
            await MainActor.run {
                // Merge new events with existing events, avoiding duplicates
                let existingEventIds = Set(self.events.map { $0.id })
                let newEvents = filteredEvents.filter { !existingEventIds.contains($0.id) }
                
                // Add new events
                self.events.append(contentsOf: newEvents)
                
                // Update existing events that might have changed
                for newEvent in filteredEvents {
                    if let index = self.events.firstIndex(where: { $0.id == newEvent.id }) {
                        self.events[index] = newEvent
                    }
                }
                
                // Rebuild index for fast lookups
                self.rebuildEventIndex()
            }
            
            #if DEBUG
            print("📅 CalendarViewModel: Updated UI with \(allEvents.count) total events, filtered to \(filteredEvents.count)")
            #endif
            
            // If still no events after sync, warn user with detailed diagnostics
            if response.events.isEmpty && !connectedProviders.isEmpty {
                #if DEBUG
                print("⚠️ CalendarViewModel: ===== NO EVENTS FOUND AFTER SYNC =====")
                print("⚠️ CalendarViewModel: Diagnostic information:")
                print("   - Connected providers: \(connectedProviders)")
                if let timeRange = response.timeRange {
                    print("   - Time range: \(timeRange.description)")
                }
                print("   - Total events in response: \(response.totalEvents)")
                #endif
                print("⚠️ CalendarViewModel: Possible issues:")
                print("   1. Google Calendar is empty (no events scheduled)")
                if let timeRange = response.timeRange {
                    print("   2. Events exist but outside the time range: \(timeRange.description)")
                } else {
                    print("   2. Events exist but outside the requested date range")
                }
                print("   3. Backend sync didn't fetch events from Google Calendar")
                print("   4. Events were synced but not stored in database")
                print("⚠️ CalendarViewModel: Check backend logs for sync details")
                errorMessage = "No events found. Your Google Calendar may be empty, or events may be outside the date range. Try pulling down to refresh."
            } else if !response.events.isEmpty {
                print("✅ CalendarViewModel: Successfully loaded \(response.events.count) events from backend and cached")
            }
            
            if filteredEvents.count < allEvents.count {
                let filteredCount = allEvents.count - filteredEvents.count
                print("⚠️ CalendarViewModel: Filtered out \(filteredCount) events from disconnected calendars")
            }
            
            if events.isEmpty {
                print("⚠️ CalendarViewModel: WARNING - API returned 0 events!")
                errorMessage = "No events found. Try refreshing or check if calendars are connected."
            } else {
                // Debug: Print all events and their dates
                for (index, event) in events.enumerated() {
                    if let startDate = event.startDate {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        print("✅ CalendarViewModel: Event #\(index + 1): '\(event.title)' on \(formatter.string(from: startDate))")
                    } else {
                        print("⚠️ CalendarViewModel: Event #\(index + 1): '\(event.title)' - NO START DATE (raw: \(event.startTime))")
                    }
                }
                
                // After loading, check how many match the selected date
                let matchingEvents = eventsForDate(selectedDate)
                print("📅 CalendarViewModel: After loading, found \(matchingEvents.count) events matching selected date")
            }
            
            isLoading = false
        } catch {
            let errorDesc = error.localizedDescription
            errorMessage = errorDesc
            isLoading = false
            print("❌ CalendarViewModel: ===== LOAD EVENTS FAILED =====")
            print("❌ CalendarViewModel: Error: \(errorDesc)")
            print("❌ CalendarViewModel: Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("❌ CalendarViewModel: Error domain: \(nsError.domain), code: \(nsError.code)")
            }
        }
    }
    
    func loadEventsForSelectedDate(_ date: Date) async {
        print("📅 CalendarViewModel: ===== LOADING EVENTS FOR SELECTED DATE =====")
        print("📅 CalendarViewModel: Selected date: \(date)")
        
        // Step 1: Show cached data IMMEDIATELY (no loading state, instant UI)
        if let cachedEvents = cacheManager.loadEvents(), cacheManager.hasCache() {
            print("📅 CalendarViewModel: Step 1: Loading cached events for instant UI...")
            let filteredCached = filterEventsByConnectedProviders(cachedEvents)
            
            // Merge with existing events
            let existingEventIds = Set(events.map { $0.id })
            let newCachedEvents = filteredCached.filter { !existingEventIds.contains($0.id) }
            events.append(contentsOf: newCachedEvents)
            
            // ALWAYS rebuild index after updating events
            print("📅 CalendarViewModel: Rebuilding index with cached events...")
            rebuildEventIndex()
            
            print("💾 CalendarViewModel: Loaded \(filteredCached.count) cached events")
        }
        
        // Step 2: Load fresh data in background (non-blocking)
        // CRITICAL: Use the same date range calculation as loadEventsForViewMode
        // to ensure the selected date is always included in the fetch
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = await self else { return }
            
            do {
                print("📅 CalendarViewModel: Step 2: Fetching fresh events in background...")
                
                // Load connected providers (lightweight)
                await self.loadConnectedProviders()
                
                // Calculate date range to include selected date with buffer
                // This matches the logic in loadEventsForViewMode
                let calendar = Calendar.current
                let today = Date()
                let startDate = calendar.date(byAdding: .day, value: -30, to: today)!
                // Ensure end date includes selected date + buffer
                let selectedDatePlusBuffer = calendar.date(byAdding: .day, value: 30, to: date)!
                let future60Days = calendar.date(byAdding: .day, value: 60, to: today)!
                let endDate = max(selectedDatePlusBuffer, future60Days)
                
                print("📅 CalendarViewModel: loadEventsForSelectedDate - Fetching events from \(startDate) to \(endDate) for selected date: \(date)")
                
                // Use fetchEvents with custom date range (NOT getUpcomingEvents)
                // This ensures we get events for the selected date, even if it's in the past
                let response = try await self.apiService.fetchEvents(startDate: startDate, endDate: endDate, period: "custom", autoSync: false)
                
                print("📅 CalendarViewModel: loadEventsForSelectedDate - Received \(response.events.count) events")
                print("📅 CalendarViewModel: Total events in response: \(response.totalEvents)")
                
                // Save to cache
                self.cacheManager.saveEvents(response.events, daysFetched: 30)
                
                // Filter and merge events
                let filteredEvents = await self.filterEventsByConnectedProviders(response.events)
                print("📅 CalendarViewModel: Filtered to \(filteredEvents.count) events from connected calendars")
                
                // Update UI on main actor (non-blocking)
                await MainActor.run {
                    let existingEventIds = Set(self.events.map { $0.id })
                    let newEvents = filteredEvents.filter { !existingEventIds.contains($0.id) }
                    self.events.append(contentsOf: newEvents)
                    
                    // Update existing events
                    for newEvent in filteredEvents {
                        if let index = self.events.firstIndex(where: { $0.id == newEvent.id }) {
                            self.events[index] = newEvent
                        }
                    }
                    
                    // ALWAYS rebuild index after updating events
                    print("📅 CalendarViewModel: Rebuilding event index after fetch...")
                    self.rebuildEventIndex()
                    print("✅ CalendarViewModel: Event index rebuilt with \(self.eventsByDate.keys.count) date keys")
                    
                    // Diagnostic: Check if events for selected date are now available
                    let matchingEvents = self.eventsForDate(date)
                    print("📅 CalendarViewModel: loadEventsForSelectedDate - After refresh, found \(matchingEvents.count) events for selected date")
                }
            } catch {
                // Log error but don't show to user (cached data is already shown)
                print("⚠️ CalendarViewModel: Background refresh failed: \(error.localizedDescription)")
                print("⚠️ CalendarViewModel: Error type: \(type(of: error))")
            }
        }
    }
    
    /// Fast refresh - just fetches events from backend without full calendar sync
    /// Use this after creating/updating events locally
    func refreshEventsFromBackend() async {
        print("📅 CalendarViewModel: ===== FAST REFRESH FROM BACKEND =====")

        do {
            // Calculate date range (current month +/- 1 month)
            let calendar = Calendar.current
            let now = Date()
            let startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let endDate = calendar.date(byAdding: .month, value: 2, to: now) ?? now

            print("📅 CalendarViewModel: Fetching events from \(startDate) to \(endDate)")

            let response = try await apiService.getAllEvents(
                start: startDate,
                end: endDate
            )

            await MainActor.run {
                // Store events directly - Event is a typealias for CalendarEvent
                self.events = response.events
                self.rebuildEventIndex()
                print("✅ CalendarViewModel: Fast refresh complete - \(self.events.count) events loaded")
            }
        } catch {
            print("❌ CalendarViewModel: Fast refresh failed: \(error.localizedDescription)")
        }
    }

    func refreshEvents() async {
        print("📅 CalendarViewModel: ===== REFRESHING EVENTS =====")
        print("📅 CalendarViewModel: Starting refresh at \(Date())")

        isRefreshing = true
        isSyncing = true
        errorMessage = nil
        syncError = nil
        syncStatus = nil
        showSyncError = false

        do {
            // Step 1: Clear cache BEFORE sync to force fresh data
            print("📅 CalendarViewModel: Step 1: Clearing cache for fresh sync...")
            cacheManager.clearCache()
            print("💾 CalendarViewModel: ✅ Cache cleared")
            
            // Step 2: Load connected providers
            print("📅 CalendarViewModel: Step 2: Loading connected providers...")
            await loadConnectedProviders()
            
            // Step 3: Sync Google Calendar
            print("📅 CalendarViewModel: Step 3: Syncing Google Calendar...")
            print("📅 CalendarViewModel: This will fetch latest events from Google Calendar API")
            
            let syncResponse = try await apiService.syncGoogleCalendar()
            
            print("✅ CalendarViewModel: ===== SYNC COMPLETE =====")
            print("✅ CalendarViewModel: Sync status: \(syncResponse.status)")
            print("✅ CalendarViewModel: Sync message: \(syncResponse.message)")
            print("✅ CalendarViewModel: Events synced: \(syncResponse.eventsSynced)")
            print("✅ CalendarViewModel: User ID: \(syncResponse.userId)")
            
            // Check sync status from response
            let syncStatusValue = syncResponse.status.lowercased()
            syncStatus = syncStatusValue
            
            // Check diagnostics for provider-specific status
            if let diagnostics = syncResponse.diagnostics,
               let googleDiagnostics = diagnostics.google {
                let providerStatus = googleDiagnostics.status.lowercased()
                print("📅 CalendarViewModel: Google provider status: \(providerStatus)")
                
                if providerStatus == "failed" {
                    syncStatus = "failed"
                    syncError = googleDiagnostics.error ?? "Google Calendar sync failed"
                    showSyncError = true
                    print("❌ CalendarViewModel: Google Calendar sync failed: \(syncError ?? "Unknown error")")
                }
            }
            
            if syncStatusValue == "failed" {
                syncError = syncResponse.message
                showSyncError = true
                print("❌ CalendarViewModel: Sync failed with status: \(syncStatusValue)")
                print("❌ CalendarViewModel: Error message: \(syncResponse.message)")
            }
            
            if syncResponse.eventsSynced == 0 && syncStatusValue != "failed" {
                print("⚠️ CalendarViewModel: ===== SYNC RETURNED 0 EVENTS =====")
                print("⚠️ CalendarViewModel: Backend message: '\(syncResponse.message)'")
                print("⚠️ CalendarViewModel: This could mean:")
                print("   1. Google Calendar is empty (no events in date range)")
                print("   2. Events are outside the sync date range")
                print("   3. Backend sync logic may not be fetching events correctly")
            } else if syncResponse.eventsSynced > 0 {
                print("✅ CalendarViewModel: Backend synced \(syncResponse.eventsSynced) events")
            }
            
            // Step 4: Fetch events with proper date range (NOT getUpcomingEvents)
            print("📅 CalendarViewModel: Step 4: Fetching events from backend...")
            
            // Calculate date range to include selected date with buffer
            let calendar = Calendar.current
            let today = Date()
            let startDate = calendar.date(byAdding: .day, value: -30, to: today)!
            let selectedDatePlusBuffer = calendar.date(byAdding: .day, value: 30, to: selectedDate)!
            let future60Days = calendar.date(byAdding: .day, value: 60, to: today)!
            let endDate = max(selectedDatePlusBuffer, future60Days)
            
            print("📅 CalendarViewModel: Fetching events from \(startDate) to \(endDate)")
            print("📅 CalendarViewModel: Selected date: \(selectedDate)")
            
            // Use fetchEvents with explicit date range (NOT getUpcomingEvents)
            let response = try await apiService.fetchEvents(startDate: startDate, endDate: endDate, period: "custom", autoSync: false)
            
            print("✅ CalendarViewModel: Step 5: API call successful, received \(response.events.count) events")
            print("📅 CalendarViewModel: Total events in response: \(response.totalEvents)")
            
            if let timeRange = response.timeRange {
                print("📅 CalendarViewModel: Time range: \(timeRange.description)")
            }
            
            // Step 5: Save to cache AFTER successful fetch
            print("💾 CalendarViewModel: Step 6: Saving refreshed events to cache...")
            cacheManager.saveEvents(response.events, daysFetched: 30)
            
            // Step 6: Filter events by connected providers
            print("📅 CalendarViewModel: Step 7: Filtering events by connected providers...")
            let filteredEvents = filterEventsByConnectedProviders(response.events)
            print("📅 CalendarViewModel: Filtered \(response.events.count) total events to \(filteredEvents.count) from connected calendars")
            
            // Step 7: Update events array (merge instead of replace to preserve future events)
            print("📅 CalendarViewModel: Step 8: Updating events array...")
            let existingEventIds = Set(events.map { $0.id })
            let newEvents = filteredEvents.filter { !existingEventIds.contains($0.id) }
            
            // Add new events
            events.append(contentsOf: newEvents)
            
            // Update existing events that might have changed
            for newEvent in filteredEvents {
                if let index = events.firstIndex(where: { $0.id == newEvent.id }) {
                    events[index] = newEvent
                }
            }
            
            print("📅 CalendarViewModel: Updated events array: \(events.count) total events (\(newEvents.count) new, \(filteredEvents.count - newEvents.count) updated)")
            
            // Step 8: ALWAYS rebuild event index after updating events
            print("📅 CalendarViewModel: Step 9: Rebuilding event index...")
            rebuildEventIndex()
            print("✅ CalendarViewModel: Event index rebuilt with \(eventsByDate.keys.count) date keys")
            
            // Step 9: Log events for debugging
            if !filteredEvents.isEmpty {
                print("📅 CalendarViewModel: ===== EVENTS AFTER REFRESH =====")
                for (index, event) in filteredEvents.prefix(10).enumerated() {
                    if let startDate = event.startDate, let endDate = event.endDate {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        formatter.timeZone = TimeZone.current
                        print("   Event #\(index + 1): '\(event.title)'")
                        print("      - Start: \(formatter.string(from: startDate)) (local)")
                        print("      - End: \(formatter.string(from: endDate)) (local)")
                    } else {
                        print("   Event #\(index + 1): '\(event.title)' - NO VALID DATES (raw start: \(event.startTime))")
                    }
                }
                if filteredEvents.count > 10 {
                    print("   ... and \(filteredEvents.count - 10) more events")
                }
            }
            
            // Step 10: Check events for selected date
            let matchingEvents = eventsForDate(selectedDate)
            print("📅 CalendarViewModel: Step 10: Found \(matchingEvents.count) events matching selected date: \(selectedDate)")
            
            if matchingEvents.isEmpty && !events.isEmpty {
                print("⚠️ CalendarViewModel: WARNING - Events loaded but none match selected date!")
                print("⚠️ CalendarViewModel: Selected date: \(selectedDate)")
                print("⚠️ CalendarViewModel: First event date: \(events.first?.startDate?.description ?? "nil")")
            }
            
            // Step 11: Set sync status
            if syncStatusValue == "failed" {
                syncError = syncResponse.message
                showSyncError = true
            } else {
                syncStatus = "success"
                syncError = nil
                showSyncError = false
            }
            
            print("✅ CalendarViewModel: ===== REFRESH COMPLETE =====")
            print("✅ CalendarViewModel: Loaded \(events.count) events")
            print("✅ CalendarViewModel: Sync status: \(syncStatus ?? "unknown")")
            
            if events.isEmpty && syncStatusValue != "failed" {
                print("⚠️ CalendarViewModel: WARNING - No events returned from API!")
                errorMessage = "No events found. Your calendar may be empty, or all events may have ended. Try pulling down to refresh again."
            }
            
            isRefreshing = false
            isSyncing = false
        } catch {
            let errorDesc = error.localizedDescription
            syncSuccessMessage = nil
            isRefreshing = false
            isSyncing = false
            syncStatus = "failed"
            showSyncError = true
            
            // UPDATED: Check for transient failure (new error format)
            if let nsError = error as NSError?,
               let errorType = nsError.userInfo["error_type"] as? String,
               errorType == "transient_failure" {
                let retryable = nsError.userInfo["retryable"] as? Bool ?? true
                let provider = nsError.userInfo["provider"] as? String ?? "calendar"
                
                print("⚠️ CalendarViewModel: ===== TRANSIENT FAILURE DETECTED =====")
                print("⚠️ CalendarViewModel: Transient failure - retryable: \(retryable)")
                print("⚠️ CalendarViewModel: Provider: \(provider)")
                
                if retryable {
                    syncError = "\(provider.capitalized) Calendar sync failed temporarily. Tap to retry."
                    errorMessage = syncError
                    // Show retry button (already handled by SyncErrorBanner)
                } else {
                    syncError = errorDesc
                    errorMessage = errorDesc
                }
            }
            // Check if this is a token expiry error (old or new format)
            else if let nsError = error as NSError?,
               nsError.userInfo["requires_reconnection"] as? Bool == true {
                print("❌ CalendarViewModel: ===== TOKEN EXPIRY DETECTED =====")
                print("❌ CalendarViewModel: Calendar token expired - showing reconnect prompt")
                syncError = "Your calendar connection has expired. Please reconnect to continue syncing events."
                errorMessage = syncError
                reconnectAlertMessage = syncError ?? ""
                showReconnectAlert = true
            }
            // Check APIError for token expiry (new format)
            else if let apiError = error as? APIError,
                    apiError.code == "401" || apiError.code == "401_CALENDAR_EXPIRED" {
                print("❌ CalendarViewModel: ===== TOKEN EXPIRY DETECTED (APIError) =====")
                syncError = apiError.message
                errorMessage = syncError
                reconnectAlertMessage = apiError.message
                showReconnectAlert = true
            }
            else {
                syncError = errorDesc
                errorMessage = errorDesc
                print("❌ CalendarViewModel: ===== REFRESH FAILED =====")
                print("❌ CalendarViewModel: Error: \(errorDesc)")
                print("❌ CalendarViewModel: Error type: \(type(of: error))")
                if let nsError = error as NSError? {
                    print("❌ CalendarViewModel: Error domain: \(nsError.domain), code: \(nsError.code)")
                    print("❌ CalendarViewModel: Error userInfo: \(nsError.userInfo)")
                }
            }
        }
    }
    
    func retrySync() async {
        print("📅 CalendarViewModel: User requested retry sync")
        await refreshEvents()
    }
    
    // MARK: - Reconnection
    
    @Published var reconnectProvider: String = "google" // Track which provider to reconnect
    
    func reconnectGoogleCalendar() {
        print("📅 CalendarViewModel: User requested to reconnect Google Calendar")
        reconnectProvider = "google"
        showReconnectAlert = false
        Task {
            await GoogleAuthManager.shared.startGoogleOAuth()
        }
    }
    
    func reconnectMicrosoftCalendar() {
        print("📅 CalendarViewModel: User requested to reconnect Microsoft Calendar")
        reconnectProvider = "microsoft"
        showReconnectAlert = false
        Task {
            await MicrosoftAuthManager.shared.startMicrosoftOAuth()
        }
    }
    
    func reconnectCalendar() {
        // Reconnect based on which provider expired
        if reconnectProvider == "microsoft" {
            reconnectMicrosoftCalendar()
        } else {
            reconnectGoogleCalendar()
        }
    }
    
    // Optimized: Use pre-computed index instead of filtering every time
    func eventsForDate(_ date: Date) -> [Event] {
        // CRITICAL: Normalize to start of day in LOCAL timezone
        // This MUST match how events are indexed in rebuildEventIndex()
        let normalizedDate = calendar.startOfDay(for: date)
        
        #if DEBUG
        // Diagnostic: Log normalization details
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        dateFormatter.timeZone = TimeZone.current
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        localFormatter.timeZone = TimeZone.current
        print("🔍 eventsForDate: Input date: \(dateFormatter.string(from: date))")
        print("🔍 eventsForDate: Normalized date: \(dateFormatter.string(from: normalizedDate))")
        print("🔍 eventsForDate: Normalized date (local): \(localFormatter.string(from: normalizedDate))")
        print("🔍 eventsForDate: Index has \(eventsByDate.keys.count) keys")
        
        // Check if normalized date exists in index
        let indexKeysAsStrings = eventsByDate.keys.map { dateFormatter.string(from: $0) }
        let normalizedDateString = dateFormatter.string(from: normalizedDate)
        if indexKeysAsStrings.contains(normalizedDateString) {
            print("🔍 eventsForDate: ✅ Normalized date found in index")
        } else {
            print("🔍 eventsForDate: ❌ Normalized date NOT in index")
            print("🔍 eventsForDate: Looking for: \(normalizedDateString)")
            print("🔍 eventsForDate: Nearest keys: \(indexKeysAsStrings.filter { $0.contains("2025-12") }.prefix(5).joined(separator: ", "))")
        }
        #endif
        
        // Fast O(1) lookup from pre-computed index
        // Date comparison in Swift uses absolute time, so this should work even if timezone representation differs
        if let cachedEvents = eventsByDate[normalizedDate] {
            #if DEBUG
            print("🔍 eventsForDate: Found \(cachedEvents.count) events in cache for normalized date")
            if cachedEvents.isEmpty {
                print("🔍 eventsForDate: ⚠️ Index entry exists but is empty - no events on this date")
            }
            #endif
            return cachedEvents
        }
        
        #if DEBUG
        // If not in index, check if we should have indexed it
        // This helps debug why a date might be missing from the index
        let hasEventsForNearbyDates = eventsByDate.keys.contains { key in
            abs(key.timeIntervalSince(normalizedDate)) < 86400 * 2 // Within 2 days
        }
        if hasEventsForNearbyDates {
            print("🔍 eventsForDate: ⚠️ Date not in index but nearby dates are - possible indexing issue")
        }
        #endif
        
        // Fallback: filter if index not built yet (shouldn't happen, but safe)
        // Also try direct date comparison in case of timezone representation differences
        let filteredEvents = events.filter { event in
            guard let eventDate = event.startDate else { return false }
            let normalizedEventDate = calendar.startOfDay(for: eventDate)
            // Use calendar.isDate for timezone-aware comparison
            let isSameDay = calendar.isDate(normalizedEventDate, inSameDayAs: normalizedDate)
            
            #if DEBUG
            if isSameDay {
                print("🔍 eventsForDate: Event '\(event.title)' matches - eventDate: \(dateFormatter.string(from: eventDate)), normalized: \(dateFormatter.string(from: normalizedEventDate))")
            }
            #endif
            
            return isSameDay
        }
        
        #if DEBUG
        print("🔍 eventsForDate: Found \(filteredEvents.count) events via fallback filtering")
        #endif
        
        // Cache the result
        eventsByDate[normalizedDate] = filteredEvents
        return filteredEvents
    }
    
    // Rebuild event index when events change (called after loading events)
    // Build index synchronously on main actor to avoid race conditions
    // This ensures the index is ready immediately when events are updated
    private func rebuildEventIndex() {
        print("🔍 CalendarViewModel: ===== REBUILDING EVENT INDEX =====")
        print("🔍 CalendarViewModel: Starting index rebuild at \(Date())")
        print("🔍 CalendarViewModel: Total events to index: \(events.count)")
        
        var index: [Date: [Event]] = [:]
        let cal = Calendar.current
        
        #if DEBUG
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        dateFormatter.timeZone = TimeZone.current
        var indexStats: [String: Int] = [:]
        var skippedCount = 0
        #endif
        
        // Process events synchronously (startDate is a computed property, safe to access)
        for event in events {
            guard let eventDate = event.startDate else { 
                #if DEBUG
                skippedCount += 1
                print("⚠️ rebuildEventIndex: Event '\(event.title)' has no startDate - skipping")
                #endif
                continue 
            }
            // CRITICAL: Normalize to start of day in LOCAL timezone
            // Use calendar.isDate for timezone-aware date comparison
            let normalizedDate = cal.startOfDay(for: eventDate)
            
            if index[normalizedDate] == nil {
                index[normalizedDate] = []
            }
            index[normalizedDate]?.append(event)
            
            #if DEBUG
            let dateKey = dateFormatter.string(from: normalizedDate)
            indexStats[dateKey, default: 0] += 1
            #endif
        }
        
        #if DEBUG
        print("🔍 CalendarViewModel: Indexed \(events.count - skippedCount) events, skipped \(skippedCount)")
        print("🔍 CalendarViewModel: Index contains \(index.keys.count) unique dates")
        #endif
        
        #if DEBUG
        // Log empty index entries (dates with no events) for December 2025
        let dec2025EmptyEntries = index.filter { key, events in
            let components = cal.dateComponents([.year, .month], from: key)
            return components.year == 2025 && components.month == 12 && events.isEmpty
        }
        if !dec2025EmptyEntries.isEmpty {
            print("🔍 rebuildEventIndex: ⚠️ Found \(dec2025EmptyEntries.count) empty index entries for December 2025:")
            for (date, _) in dec2025EmptyEntries.sorted(by: { $0.key < $1.key }) {
                print("🔍 rebuildEventIndex:   \(dateFormatter.string(from: date)): 0 events")
            }
        }
        #endif
        
        // Update index immediately (we're already on main actor)
        eventsByDate = index
        
        print("✅ CalendarViewModel: Event index rebuilt successfully")
        print("✅ CalendarViewModel: Index now contains \(index.keys.count) date keys")
        
        #if DEBUG
        // Log index statistics for December 2025
        let dec2025Events = indexStats.filter { key, _ in
            key.contains("2025-12")
        }
        if !dec2025Events.isEmpty {
            print("🔍 rebuildEventIndex: Events indexed for December 2025:")
            for (dateKey, count) in dec2025Events.sorted(by: { $0.key < $1.key }) {
                print("🔍 rebuildEventIndex:   \(dateKey): \(count) events")
            }
        }
        #endif
        
        #if DEBUG
        // Diagnostic logging for date filtering issues
        let normalizedSelected = cal.startOfDay(for: selectedDate)
        let matchingEvents = index[normalizedSelected] ?? []
        
        if matchingEvents.isEmpty && !events.isEmpty {
            print("🔍 CalendarViewModel: ===== DATE FILTERING DIAGNOSTICS =====")
            
            // Format dates for better readability
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
            dateFormatter.timeZone = TimeZone.current
            let localFormatter = DateFormatter()
            localFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            localFormatter.timeZone = TimeZone.current
            
            print("🔍 CalendarViewModel: Selected date (raw): \(dateFormatter.string(from: selectedDate))")
            print("🔍 CalendarViewModel: Selected date (normalized): \(dateFormatter.string(from: normalizedSelected))")
            print("🔍 CalendarViewModel: Selected date (normalized, local): \(localFormatter.string(from: normalizedSelected))")
            print("🔍 CalendarViewModel: Total events loaded: \(events.count)")
            print("🔍 CalendarViewModel: Events matching selected date: \(matchingEvents.count)")
            print("🔍 CalendarViewModel: Index keys count: \(index.keys.count)")
            
            // Show index keys around the selected date
            let sortedIndexKeys = index.keys.sorted()
            let nearbyKeys = sortedIndexKeys.filter { key in
                abs(key.timeIntervalSince(normalizedSelected)) < 86400 * 7 // Within 7 days
            }
            print("🔍 CalendarViewModel: Index keys within 7 days of selected date:")
            for key in nearbyKeys.prefix(10) {
                let eventCount = index[key]?.count ?? 0
                print("🔍 CalendarViewModel:   \(dateFormatter.string(from: key)): \(eventCount) events")
            }
            
            // Show first few event dates for debugging
            let sortedEvents = events.sorted { event1, event2 in
                guard let date1 = event1.startDate, let date2 = event2.startDate else { return false }
                return date1 < date2
            }
            
            print("🔍 CalendarViewModel: First 5 event dates:")
            for (idx, event) in sortedEvents.prefix(5).enumerated() {
                if let eventDate = event.startDate {
                    let normalizedEventDate = cal.startOfDay(for: eventDate)
                    let isSameDay = cal.isDate(normalizedEventDate, inSameDayAs: normalizedSelected)
                    print("🔍 CalendarViewModel:   Event #\(idx + 1): '\(event.title)' on \(dateFormatter.string(from: normalizedEventDate)) - matches: \(isSameDay)")
                }
            }
            
            // Check if there are events in the same month
            let selectedComponents = cal.dateComponents([.year, .month], from: normalizedSelected)
            let eventsInSameMonth = sortedEvents.filter { event in
                guard let eventDate = event.startDate else { return false }
                let normalizedEventDate = cal.startOfDay(for: eventDate)
                let eventComponents = cal.dateComponents([.year, .month], from: normalizedEventDate)
                return eventComponents.year == selectedComponents.year && eventComponents.month == selectedComponents.month
            }
            
            print("🔍 CalendarViewModel: Events in same month (\(selectedComponents.year ?? 0)-\(selectedComponents.month ?? 0)): \(eventsInSameMonth.count)")
            
            // Show ALL December 2025 events with their exact dates
            if eventsInSameMonth.count > 0 {
                print("🔍 CalendarViewModel: All December 2025 events:")
                for (idx, event) in eventsInSameMonth.enumerated() {
                    if let eventDate = event.startDate {
                        let normalizedEventDate = cal.startOfDay(for: eventDate)
                        let isSameDay = cal.isDate(normalizedEventDate, inSameDayAs: normalizedSelected)
                        let dayComponent = cal.dateComponents([.day], from: normalizedEventDate).day ?? 0
                        print("🔍 CalendarViewModel:   Event #\(idx + 1): '\(event.title)' on Dec \(dayComponent) (normalized: \(dateFormatter.string(from: normalizedEventDate))) - matches Dec 1: \(isSameDay)")
                    }
                }
            }
            
            // Show date range of all events
            if let firstEvent = sortedEvents.first, let lastEvent = sortedEvents.last,
               let firstDate = firstEvent.startDate, let lastDate = lastEvent.startDate {
                print("🔍 CalendarViewModel: Event date range: \(dateFormatter.string(from: firstDate)) to \(dateFormatter.string(from: lastDate))")
            }
            
            // Check timezone info
            let timezone = TimeZone.current
            let secondsFromGMT = timezone.secondsFromGMT(for: normalizedSelected)
            print("🔍 CalendarViewModel: Current timezone: \(timezone.identifier), offset: \(secondsFromGMT) seconds (\(secondsFromGMT / 3600) hours)")
            print("🔍 CalendarViewModel: Selected date components: year=\(selectedComponents.year ?? 0), month=\(selectedComponents.month ?? 0), day=\(selectedComponents.day ?? 0)")
            
            // Check if the normalized selected date exists in the index
            let indexKeysAsStrings = index.keys.map { dateFormatter.string(from: $0) }
            let normalizedSelectedString = dateFormatter.string(from: normalizedSelected)
            print("🔍 CalendarViewModel: Normalized selected date in index: \(indexKeysAsStrings.contains(normalizedSelectedString))")
            if !indexKeysAsStrings.contains(normalizedSelectedString) {
                print("🔍 CalendarViewModel: ⚠️ Normalized selected date NOT found in index keys!")
                print("🔍 CalendarViewModel: Looking for: \(normalizedSelectedString)")
            }
        }
        #endif
    }
    
    func eventsForToday() -> [Event] {
        eventsForDate(Date())
    }
    
    func nextEvent() -> Event? {
        let now = Date()
        return events
            .filter { event in
                guard let startDate = event.startDate else { return false }
                return startDate > now
            }
            .sorted { event1, event2 in
                guard let start1 = event1.startDate, let start2 = event2.startDate else { return false }
                return start1 < start2
            }
            .first
    }
    
    func selectDate(_ date: Date) {
        // CRITICAL: Normalize to start of day in local timezone to ensure consistent matching
        // This ensures the selected date matches the index keys which are also normalized
        let normalized = calendar.startOfDay(for: date)
        selectedDate = normalized
        
        #if DEBUG
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        dateFormatter.timeZone = TimeZone.current
        print("🔍 selectDate: Input: \(dateFormatter.string(from: date)), Normalized: \(dateFormatter.string(from: normalized))")
        #endif
    }
    
    // MARK: - Connected Providers Filtering
    
    private func loadConnectedProviders() async {
        do {
            let calendarResponse = try await apiService.getConnectedCalendars()
            connectedProviders = Set(calendarResponse.calendars.map { $0.provider.lowercased() })
            print("📅 CalendarViewModel: Connected providers loaded: \(connectedProviders)")
            print("📅 CalendarViewModel: Will show events from: \(connectedProviders.joined(separator: ", "))")
            
            // Log which providers are connected for debugging
            if connectedProviders.contains("google") {
                print("✅ CalendarViewModel: Google Calendar is connected")
            }
            if connectedProviders.contains("microsoft") {
                print("✅ CalendarViewModel: Microsoft Calendar is connected")
            }
        } catch {
            print("⚠️ CalendarViewModel: Failed to load connected calendars, showing all events: \(error)")
            // If we can't load connected calendars, don't filter (show all events)
            connectedProviders = []
        }
    }
    
    // Optimized: Filter without logging (logging removed for performance)
    private func filterEventsByConnectedProviders(_ events: [Event]) -> [Event] {
        return Self.filterEventsByConnectedProvidersStatic(events, connectedProviders: connectedProviders)
    }
    
    // Static version for use in detached tasks (nonisolated)
    nonisolated private static func filterEventsByConnectedProvidersStatic(_ events: [Event], connectedProviders: Set<String>) -> [Event] {
        // If no connected providers loaded, show all events
        guard !connectedProviders.isEmpty else {
            return events
        }
        
        // Fast filter without logging
        return events.filter { event in
            let eventSource = event.source.lowercased()
            return connectedProviders.contains(eventSource)
        }
    }
}
