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
            // Fetch past 30 days + future 30 days to show complete calendar
            #if DEBUG
            print("📅 CalendarViewModel: Step 4: Fetching latest events from API (past 30 + future 30 days)...")
            #endif
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            let endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
            // Use the new structured GET /events endpoint
            let response = try await apiService.fetchEvents(startDate: startDate, endDate: endDate, period: "custom", autoSync: false)
            print("📅 CalendarViewModel: Step 5: API call successful, received \(response.events.count) events")
            
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
        // OPTIMIZED: Instant feedback, background loading (iOS navigation bar style)
        // Step 1: Show cached data IMMEDIATELY (no loading state, instant UI)
        if let cachedEvents = cacheManager.loadEvents(), cacheManager.hasCache() {
            let filteredCached = filterEventsByConnectedProviders(cachedEvents)
            
            // Merge with existing events
            let existingEventIds = Set(events.map { $0.id })
            let newCachedEvents = filteredCached.filter { !existingEventIds.contains($0.id) }
            events.append(contentsOf: newCachedEvents)
            
            // Rebuild index immediately for instant lookup
            rebuildEventIndex()
            
            // UI is now updated - user sees data instantly
        }
        
        // Step 2: Load fresh data in background (non-blocking)
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = await self else { return }
            
            do {
                // Load connected providers (lightweight)
                await self.loadConnectedProviders()
                
                // Fetch from API (background, doesn't block UI)
                let response = try await self.apiService.getUpcomingEvents(days: 30)
                
                // Save to cache
                self.cacheManager.saveEvents(response.events, daysFetched: 30)
                
                // Filter and merge events
                let filteredEvents = await self.filterEventsByConnectedProviders(response.events)
                
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
                    
                    // Rebuild index
                    self.rebuildEventIndex()
                }
            } catch {
                // Silently fail - cached data is already shown
                print("⚠️ CalendarViewModel: Background refresh failed: \(error.localizedDescription)")
            }
        }
    }
    
    func refreshEvents() async {
        isRefreshing = true
        errorMessage = nil
        
        do {
            print("📅 CalendarViewModel: ===== REFRESHING EVENTS =====")
            print("📅 CalendarViewModel: Step 1: Syncing Google Calendar...")
            print("📅 CalendarViewModel: This will re-fetch events from Google Calendar and update UTC times")
            print("📅 CalendarViewModel: This fixes events that were stored with incorrect UTC times before the timezone fix")
            
            // Clear cache to force fresh data
            cacheManager.clearCache()
            print("💾 CalendarViewModel: Cleared cache for fresh sync")
            
            // First sync to get latest events with corrected timezones, then fetch upcoming events
            let syncResponse = try await apiService.syncGoogleCalendar()
            print("✅ CalendarViewModel: ===== SYNC COMPLETE =====")
            print("✅ CalendarViewModel: Sync status: \(syncResponse.status)")
            print("✅ CalendarViewModel: Sync message: \(syncResponse.message)")
            print("✅ CalendarViewModel: Events synced: \(syncResponse.eventsSynced)")
            print("✅ CalendarViewModel: User ID: \(syncResponse.userId)")
            
            if syncResponse.eventsSynced == 0 {
                print("⚠️ CalendarViewModel: ===== SYNC RETURNED 0 EVENTS =====")
                print("⚠️ CalendarViewModel: Backend message: '\(syncResponse.message)'")
                print("⚠️ CalendarViewModel: This is a BACKEND ISSUE - backend sync returned 0 events")
                print("⚠️ CalendarViewModel: Possible backend causes:")
                print("   1. Google OAuth tokens expired/invalid (backend needs to refresh tokens)")
                print("   2. Backend not calling Google Calendar API correctly")
                print("   3. Backend sync logic not fetching events from all calendars")
                print("   4. Google Calendar API permissions issue on backend")
                print("   5. Google Calendar actually has no events (unlikely)")
                print("⚠️ CalendarViewModel: Check backend logs for Google Calendar API responses")
                print("⚠️ CalendarViewModel: Check backend OAuth token refresh logic")
                print("⚠️ CalendarViewModel: Continuing to fetch existing events from database...")
            } else {
                print("✅ CalendarViewModel: Backend has updated \(syncResponse.eventsSynced) events with correct UTC times")
                print("✅ CalendarViewModel: Events should now display with correct times")
                print("✅ CalendarViewModel: This fixes events that were stored with incorrect UTC times before the timezone fix")
            }
            
            // Then fetch the updated events
            print("📅 CalendarViewModel: Step 2: Fetching events from backend...")
            print("📅 CalendarViewModel: This will show events that:")
            print("   - Have not ended yet (end_time > current time)")
            print("   - Are within the next 30 days")
            print("   - Were synced from Google Calendar")
            
            // Ensure connected providers are loaded
            await loadConnectedProviders()
            
            let response = try await apiService.getUpcomingEvents(days: 30)
            #if DEBUG
            print("📅 CalendarViewModel: Backend returned \(response.totalEvents) events")
            if let timeRange = response.timeRange {
                print("📅 CalendarViewModel: Time range: \(timeRange.description)")
            }
            #endif
            
            // Save to cache
            print("💾 CalendarViewModel: Saving refreshed events to cache...")
            cacheManager.saveEvents(response.events, daysFetched: 30)
            
            // Filter events to only show those from connected calendars
            let filteredEvents = filterEventsByConnectedProviders(response.events)
            events = filteredEvents
            print("📅 CalendarViewModel: Filtered \(response.events.count) total events to \(filteredEvents.count) from connected calendars")
            
            // Log all events for debugging
            if !filteredEvents.isEmpty {
                print("📅 CalendarViewModel: ===== EVENTS AFTER REFRESH =====")
                for (index, event) in filteredEvents.enumerated() {
                    if let startDate = event.startDate, let endDate = event.endDate {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        formatter.timeZone = TimeZone.current
                        let now = Date()
                        let hasEnded = endDate < now
                        print("   Event #\(index + 1): '\(event.title)'")
                        print("      - Start: \(formatter.string(from: startDate)) (local)")
                        print("      - End: \(formatter.string(from: endDate)) (local)")
                        print("      - Status: \(hasEnded ? "❌ ENDED" : "✅ UPCOMING")")
                    } else {
                        print("   Event #\(index + 1): '\(event.title)' - NO VALID DATES (raw start: \(event.startTime))")
                    }
                }
            }
            
            // Rebuild the event index after updating events
            rebuildEventIndex()
            
            print("✅ CalendarViewModel: ===== REFRESH COMPLETE =====")
            print("✅ CalendarViewModel: Loaded \(events.count) events")
            
            // Don't show success message - only show errors
            syncSuccessMessage = nil
            
            if events.isEmpty {
                print("⚠️ CalendarViewModel: WARNING - No events returned from API!")
                print("⚠️ CalendarViewModel: Diagnostic information:")
                print("   - Sync status: \(syncResponse.status)")
                print("   - Events synced: \(syncResponse.eventsSynced)")
                print("   - Backend events count: \(response.totalEvents)")
                print("⚠️ CalendarViewModel: Possible reasons:")
                print("   1. Google Calendar is empty (no events scheduled)")
                print("   2. All events have already ended (past events don't show)")
                print("   3. Events are outside the 30-day range")
                print("   4. Events exist but haven't been synced yet")
                print("⚠️ CalendarViewModel: Try creating a new event or check your Google Calendar")
                errorMessage = "No events found. Your calendar may be empty, or all events may have ended. Try pulling down to refresh again."
            } else {
                // Log each event for debugging
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
                
                // Rebuild the event index after updating events
                rebuildEventIndex()
                
                // After refresh, check how many match the selected date
                let matchingEvents = eventsForDate(selectedDate)
                print("📅 CalendarViewModel: After refresh, found \(matchingEvents.count) events matching selected date: \(selectedDate)")
                
                if matchingEvents.isEmpty && !events.isEmpty {
                    print("⚠️ CalendarViewModel: WARNING - Events loaded but none match selected date!")
                    print("⚠️ CalendarViewModel: Selected date: \(selectedDate)")
                    print("⚠️ CalendarViewModel: First event date: \(events.first?.startDate?.description ?? "nil")")
                }
            }
            
            isRefreshing = false
        } catch {
            let errorDesc = error.localizedDescription
            errorMessage = errorDesc
            syncSuccessMessage = nil // Clear success message on error
            isRefreshing = false
            print("❌ CalendarViewModel: ===== REFRESH FAILED =====")
            print("❌ CalendarViewModel: Error: \(errorDesc)")
            print("❌ CalendarViewModel: Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("❌ CalendarViewModel: Error domain: \(nsError.domain), code: \(nsError.code)")
                print("❌ CalendarViewModel: Error userInfo: \(nsError.userInfo)")
            }
        }
    }
    
    // Optimized: Use pre-computed index instead of filtering every time
    func eventsForDate(_ date: Date) -> [Event] {
        let normalizedDate = calendar.startOfDay(for: date)
        
        // Fast O(1) lookup from pre-computed index
        if let cachedEvents = eventsByDate[normalizedDate] {
            return cachedEvents
        }
        
        // Fallback: filter if index not built yet (shouldn't happen, but safe)
        let filteredEvents = events.filter { event in
            guard let eventDate = event.startDate else { return false }
            let normalizedEventDate = calendar.startOfDay(for: eventDate)
            return calendar.isDate(normalizedEventDate, inSameDayAs: normalizedDate)
        }
        
        // Cache the result
        eventsByDate[normalizedDate] = filteredEvents
        return filteredEvents
    }
    
    // Rebuild event index when events change (called after loading events)
    // Build index synchronously on main actor to avoid race conditions
    // This ensures the index is ready immediately when events are updated
    private func rebuildEventIndex() {
        var index: [Date: [Event]] = [:]
        let cal = Calendar.current
        
        // Process events synchronously (startDate is a computed property, safe to access)
        for event in events {
            guard let eventDate = event.startDate else { continue }
            let normalizedDate = cal.startOfDay(for: eventDate)
            
            if index[normalizedDate] == nil {
                index[normalizedDate] = []
            }
            index[normalizedDate]?.append(event)
        }
        
        // Update index immediately (we're already on main actor)
        eventsByDate = index
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
        selectedDate = date
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
