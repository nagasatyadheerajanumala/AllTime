import Foundation
import EventKit
import Combine

@MainActor
class CalendarManager: ObservableObject {
    @Published var calendars: [EKCalendar] = []
    @Published var events: [EKEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasPermission = false
    
    private let eventStore = EKEventStore()
    private let apiService = APIService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkCalendarPermission()
    }
    
    // MARK: - Calendar Permission
    
    func checkCalendarPermission() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess:
            hasPermission = true
            loadCalendars()
        case .denied, .restricted:
            hasPermission = false
        case .notDetermined:
            hasPermission = false
        case .writeOnly:
            hasPermission = false
        @unknown default:
            hasPermission = false
        }
    }
    
    func requestCalendarAccess() {
        print("📅 CalendarManager: Requesting calendar access...")
        
        eventStore.requestFullAccessToEvents { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    self?.hasPermission = true
                    self?.loadCalendars()
                    print("📅 CalendarManager: Calendar access granted")
                } else {
                    self?.hasPermission = false
                    self?.errorMessage = "Calendar access denied. Please enable it in Settings."
                    print("📅 CalendarManager: Calendar access denied")
                }
            }
        }
    }
    
    // MARK: - Calendar Management
    
    func loadCalendars() {
        guard hasPermission else { return }
        
        calendars = eventStore.calendars(for: .event)
        print("📅 CalendarManager: Loaded \(calendars.count) calendars")
    }
    
    func loadEvents(for date: Date) {
        guard hasPermission else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        events = eventStore.events(matching: predicate)
        
        print("📅 CalendarManager: Loaded \(events.count) events for \(date)")
    }
    
    func loadEvents(from startDate: Date, to endDate: Date) {
        guard hasPermission else { return }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        events = eventStore.events(matching: predicate)
        
        print("📅 CalendarManager: Loaded \(events.count) events from \(startDate) to \(endDate)")
    }
    
    // MARK: - Backend Sync
    
    func syncEventsToBackend() {
        print("📅 CalendarManager: Syncing events to backend...")
        isLoading = true
        errorMessage = nil
        
        guard hasPermission else {
            errorMessage = "Calendar access required to sync events"
            isLoading = false
            return
        }
        
        let startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let eventsToSync = eventStore.events(matching: predicate)
        
        Task {
            do {
                try await apiService.syncEvents(events: eventsToSync)
                isLoading = false
                print("📅 CalendarManager: Events synced successfully")
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                print("📅 CalendarManager: Failed to sync events: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchEventsFromBackend() {
        print("📅 CalendarManager: Fetching events from backend...")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let eventsResponse = try await apiService.fetchEvents(startDate: nil, endDate: nil)
                // Convert backend events to EKEvent format if needed
                // For now, we'll just log the response
                print("📅 CalendarManager: Fetched \(eventsResponse.events.count) events from backend")
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                print("📅 CalendarManager: Failed to fetch events from backend: \(error.localizedDescription)")
            }
        }
    }
}
