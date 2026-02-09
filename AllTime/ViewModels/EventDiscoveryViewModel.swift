import Foundation
import SwiftUI

@MainActor
class EventDiscoveryViewModel: ObservableObject {
    @Published var discoveredEvents: [DiscoveredEvent] = []
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var errorMessage: String?

    private let apiService = APIService()
    private let cacheKey = "discovered_events"

    func loadEvents(startDate: Date? = nil, endDate: Date? = nil) async {
        isLoading = true
        errorMessage = nil

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        let start = startDate.map { fmt.string(from: $0) }
        let end = endDate.map { fmt.string(from: $0) }

        do {
            let response = try await apiService.fetchDiscoveredEvents(startDate: start, endDate: end)
            discoveredEvents = response.events
            // Cache the response
            await CacheService.shared.saveJSON(response, filename: cacheKey)
        } catch {
            print("Failed to load discovered events: \(error)")
            errorMessage = "Failed to load suggestions"
            // Try cache fallback
            if let cached: DiscoveredEventsResponse = await CacheService.shared.loadJSON(DiscoveredEventsResponse.self, filename: cacheKey) {
                discoveredEvents = cached.events
            }
        }

        isLoading = false
    }

    func generateEvents() async {
        isGenerating = true
        errorMessage = nil

        do {
            let response = try await apiService.generateDiscoveredEvents()
            discoveredEvents = response.events
            await CacheService.shared.saveJSON(response, filename: cacheKey)
        } catch {
            print("Failed to generate discovered events: \(error)")
            errorMessage = "Failed to generate suggestions"
        }

        isGenerating = false
    }

    func acceptEvent(_ event: DiscoveredEvent) async {
        do {
            try await apiService.acceptDiscoveredEvent(id: event.id)
            // Remove from local list
            discoveredEvents.removeAll { $0.id == event.id }
        } catch {
            print("Failed to accept event: \(error)")
            errorMessage = "Failed to accept event"
        }
    }

    func dismissEvent(_ event: DiscoveredEvent) async {
        do {
            try await apiService.dismissDiscoveredEvent(id: event.id)
            discoveredEvents.removeAll { $0.id == event.id }
        } catch {
            print("Failed to dismiss event: \(error)")
            errorMessage = "Failed to dismiss event"
        }
    }

    func eventsForDate(_ date: Date) -> [DiscoveredEvent] {
        let calendar = Calendar.current
        return discoveredEvents.filter { event in
            guard let eventDate = event.startDate else { return false }
            return calendar.isDate(eventDate, inSameDayAs: date)
        }
    }

    var hasEvents: Bool {
        !discoveredEvents.isEmpty
    }
}
