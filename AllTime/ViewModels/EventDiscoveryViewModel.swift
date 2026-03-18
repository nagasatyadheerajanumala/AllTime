import Foundation
import SwiftUI
import Combine

@MainActor
class EventDiscoveryViewModel: ObservableObject {
    @Published var discoveredEvents: [DiscoveredEvent] = []
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var errorMessage: String?

    private let apiService = APIService()
    private let cacheKey = "discovered_events"
    private var hasAttemptedGeneration = false

    func loadEvents(startDate: Date? = nil, endDate: Date? = nil) async {
        isLoading = true
        errorMessage = nil

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        let start = startDate.map { fmt.string(from: $0) }
        let end = endDate.map { fmt.string(from: $0) }

        do {
            let response = try await apiService.fetchDiscoveredEvents(startDate: start, endDate: end)
            discoveredEvents = response.events.sorted {
                ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture)
            }
            // Cache the response
            await CacheService.shared.saveJSON(response, filename: cacheKey)

            // Auto-generate if no pending suggestions exist (once per session)
            // Backend safely returns empty if user has no interests configured
            if discoveredEvents.isEmpty && !hasAttemptedGeneration {
                hasAttemptedGeneration = true
                isLoading = false
                await generateEvents()
                return
            }
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
            discoveredEvents = response.events.sorted {
                ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture)
            }
            await CacheService.shared.saveJSON(response, filename: cacheKey)
        } catch {
            print("Failed to generate discovered events: \(error)")
            errorMessage = "Failed to generate suggestions"
        }

        isGenerating = false
    }

    /// Accept a discovered event. Returns the created calendar event ID if available.
    @discardableResult
    func acceptEvent(_ event: DiscoveredEvent) async -> Int64? {
        // Remove from local list immediately for responsive UI
        discoveredEvents.removeAll { $0.id == event.id }
        do {
            let createdEventId = try await apiService.acceptDiscoveredEvent(id: event.id)
            // Notify calendar to refresh so the new event appears immediately
            NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)
            return createdEventId
        } catch {
            print("Failed to accept event: \(error)")
            return nil
        }
    }

    func dismissEvent(_ event: DiscoveredEvent) async {
        // Remove from local list immediately for responsive UI
        discoveredEvents.removeAll { $0.id == event.id }
        do {
            try await apiService.dismissDiscoveredEvent(id: event.id)
        } catch {
            print("Failed to dismiss event: \(error)")
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
