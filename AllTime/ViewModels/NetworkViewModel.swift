//
//  NetworkViewModel.swift
//  AllTime
//
//  ViewModel for My Network feature
//

import Foundation
import Combine

@MainActor
class NetworkViewModel: ObservableObject {
    @Published var connections: [NetworkConnection] = []
    @Published var pendingRequests: [NetworkConnection] = []
    @Published var sentRequests: [NetworkConnection] = []
    @Published var suggestions: [NetworkSuggestion] = []
    @Published var stats: NetworkStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Smart social cards
    @Published var smartCards: [SmartSocialCard] = []
    @Published var isLoadingSmartCards = false

    // Event invites
    @Published var eventInvites: [EventInvite] = []

    // Connection detail
    @Published var freeTime: ConnectionFreeTime?
    @Published var isLoadingFreeTime = false

    // Connection-specific smart cards
    @Published var connectionSmartCards: [SmartSocialCard] = []

    // Interest-based events for sharing with a connection
    @Published var interestBasedEvents: [InterestBasedEvent] = []
    @Published var isLoadingInterestEvents = false

    private let apiService = APIService()

    func loadAll() async {
        isLoading = true
        errorMessage = nil

        async let connectionsTask: () = loadConnections()
        async let pendingTask: () = loadPendingRequests()
        async let sentTask: () = loadSentRequests()
        async let suggestionsTask: () = loadSuggestions()
        async let statsTask: () = loadStats()
        async let invitesTask: () = loadEventInvites()
        async let smartCardsTask: () = loadSmartCards()

        _ = await (connectionsTask, pendingTask, sentTask, suggestionsTask, statsTask, invitesTask, smartCardsTask)
        isLoading = false
    }

    func loadConnections() async {
        do {
            connections = try await apiService.getNetworkConnections()
        } catch {
            print("Failed to load connections: \(error)")
        }
    }

    func loadPendingRequests() async {
        do {
            pendingRequests = try await apiService.getNetworkPendingRequests()
        } catch {
            print("Failed to load pending requests: \(error)")
        }
    }

    func loadSentRequests() async {
        do {
            sentRequests = try await apiService.getNetworkSentRequests()
        } catch {
            print("Failed to load sent requests: \(error)")
        }
    }

    func loadSuggestions() async {
        do {
            suggestions = try await apiService.getNetworkSuggestions()
        } catch {
            print("Failed to load suggestions: \(error)")
        }
    }

    func loadStats() async {
        do {
            stats = try await apiService.getNetworkStats()
        } catch {
            print("Failed to load stats: \(error)")
        }
    }

    func sendRequest(email: String) async {
        errorMessage = nil
        successMessage = nil
        do {
            let response = try await apiService.sendNetworkRequest(email: email)
            successMessage = response.message
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func acceptRequest(connectionId: Int64) async {
        do {
            _ = try await apiService.acceptNetworkRequest(connectionId: connectionId)
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineRequest(connectionId: Int64) async {
        do {
            _ = try await apiService.declineNetworkRequest(connectionId: connectionId)
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeConnection(connectionId: Int64) async {
        do {
            _ = try await apiService.removeNetworkConnection(connectionId: connectionId)
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadFreeTime(connectionUserId: Int64, date: Date) async {
        isLoadingFreeTime = true
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)

        do {
            freeTime = try await apiService.getConnectionFreeTime(
                connectionUserId: connectionUserId, date: dateStr)
            isLoadingFreeTime = false
        } catch {
            print("Failed to load free time: \(error)")
            isLoadingFreeTime = false
        }
    }

    func acceptSuggestion(id: Int64) async {
        do {
            _ = try await apiService.acceptNetworkSuggestion(id: id)
            await loadSuggestions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissSuggestion(id: Int64) async {
        do {
            _ = try await apiService.dismissNetworkSuggestion(id: id)
            await loadSuggestions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Smart Social Cards

    func loadSmartCards() async {
        isLoadingSmartCards = true
        do {
            smartCards = try await apiService.getSmartSocialCards()
        } catch {
            print("Failed to load smart social cards: \(error)")
        }
        isLoadingSmartCards = false
    }

    func loadSmartCardsForConnection(connectionUserId: Int64) async {
        do {
            connectionSmartCards = try await apiService.getSmartCardsForConnection(
                connectionUserId: connectionUserId)
        } catch {
            print("Failed to load connection smart cards: \(error)")
        }
    }

    /// One-tap action: invite to event or create + invite
    func executeSmartCardAction(_ card: SmartSocialCard) async -> (success: Bool, message: String) {
        if card.actionType == "invite_to_event", let eventId = card.eventId {
            do {
                let response = try await apiService.inviteConnectionsToEvent(
                    eventId: eventId, connectionUserIds: [card.connectionUserId])
                await loadSmartCards()
                return (response.success, response.message)
            } catch {
                return (false, error.localizedDescription)
            }
        } else if card.actionType == "create_and_invite" || card.actionType == "view_events",
                  let slotStart = card.mutualSlotStart,
                  let slotEnd = card.mutualSlotEnd {
            // Create an event at the mutual slot, then invite
            let dateStr = card.mutualSlotDate ?? ""
            guard let startDate = parseSlotDateTime(dateStr: dateStr, timeStr: slotStart),
                  let endDate = parseSlotDateTime(dateStr: dateStr, timeStr: slotEnd) else {
                return (false, "Could not parse time slot")
            }

            do {
                let title = card.suggestedActivity ?? "Meetup with \(card.displayName)"
                let eventResponse = try await apiService.createEvent(
                    title: title, description: nil, location: nil,
                    startDate: startDate, endDate: endDate, isAllDay: false)

                NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)

                let inviteResponse = try await apiService.inviteConnectionsToEvent(
                    eventId: eventResponse.id, connectionUserIds: [card.connectionUserId])
                await loadSmartCards()
                return (inviteResponse.success, "Event created and \(inviteResponse.message.lowercased())")
            } catch {
                return (false, error.localizedDescription)
            }
        }

        return (false, "Unknown action type")
    }

    private func parseSlotDateTime(dateStr: String, timeStr: String) -> Date? {
        let parts = timeStr.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }

        let calendar = Calendar.current

        if !dateStr.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let baseDate = dateFormatter.date(from: dateStr) {
                return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate)
            }
        }

        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }

    // MARK: - Interest-Based Events for Sharing

    func loadInterestBasedEvents(connectionUserId: Int64) async {
        isLoadingInterestEvents = true
        do {
            interestBasedEvents = try await apiService.getInterestBasedEvents(
                connectionUserId: connectionUserId)
        } catch {
            print("Failed to load interest-based events: \(error)")
        }
        isLoadingInterestEvents = false
    }

    func inviteToEvent(eventId: Int64, connectionUserId: Int64) async -> (success: Bool, message: String) {
        do {
            let response = try await apiService.inviteConnectionsToEvent(
                eventId: eventId, connectionUserIds: [connectionUserId])
            return (response.success, response.message)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - Event Invites

    func loadEventInvites() async {
        do {
            eventInvites = try await apiService.getReceivedEventInvites()
        } catch {
            print("Failed to load event invites: \(error)")
        }
    }

    /// Accept invite and return the event ID for navigation
    func acceptEventInvite(inviteId: Int64) async -> Int64? {
        do {
            let response = try await apiService.acceptEventInvite(inviteId: inviteId)
            await loadEventInvites()

            // Notify the app that a new event was added to the calendar
            NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)
            return response.eventId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func declineEventInvite(inviteId: Int64) async {
        do {
            _ = try await apiService.declineEventInvite(inviteId: inviteId)
            await loadEventInvites()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
