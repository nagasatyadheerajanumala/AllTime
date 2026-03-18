//
//  ShareEventSheet.swift
//  AllTime
//
//  Universal share sheet — tap on any event, pick a connection, send.
//  Shows which connections share interests related to the event.
//

import SwiftUI

struct ShareEventSheet: View {
    let eventId: Int64
    let eventTitle: String
    let eventStartTime: String?
    let eventEndTime: String?
    let eventLocation: String?
    let eventMeetingLink: String?
    let eventDescription: String?
    let eventAttendees: [String]?
    let eventColor: Color

    @State private var connections: [NetworkConnection] = []
    @State private var matchingConnections: [EventInterestMatch] = []
    @State private var isLoading = true
    @State private var sendingToUserId: Int64?
    @State private var sentToUserIds: Set<Int64> = []
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        eventPreview
                        connectionsList
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenMargin)
                    .padding(.top, DesignSystem.Spacing.md)
                }
            }
            .navigationTitle("Share Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .font(.system(size: 22))
                    }
                }
            }
            .task { await loadData() }
        }
    }

    // MARK: - Event Preview

    // Convenience init from CalendarEvent
    init(event: CalendarEvent) {
        self.eventId = event.id
        self.eventTitle = event.title
        self.eventStartTime = event.startTime
        self.eventEndTime = event.endTime
        self.eventLocation = event.location?.name
        self.eventMeetingLink = event.meetingLink
        self.eventDescription = event.description
        self.eventAttendees = event.attendees?.compactMap { $0.name ?? $0.email }
        if let hex = event.eventColor ?? event.sourceColor {
            self.eventColor = Color(hex: hex) ?? DesignSystem.Colors.violet
        } else {
            self.eventColor = DesignSystem.Colors.violet
        }
    }

    // Convenience init from EventDetails
    init(eventDetails: EventDetails) {
        self.eventId = eventDetails.id
        self.eventTitle = eventDetails.title ?? "Event"
        self.eventStartTime = eventDetails.startTime
        self.eventEndTime = eventDetails.endTime
        self.eventLocation = eventDetails.location
        self.eventMeetingLink = eventDetails.meetingLink
        self.eventDescription = eventDetails.description
        self.eventAttendees = eventDetails.attendees?.compactMap { $0.displayName ?? $0.email }
        self.eventColor = DesignSystem.Colors.violet
    }

    private var eventPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(eventColor)
                    .frame(width: 4)
                    .frame(minHeight: 44)

                VStack(alignment: .leading, spacing: 5) {
                    Text(eventTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(2)

                    // Time range + duration
                    if let startTime = eventStartTime, let startDate = parseDate(startTime) {
                        HStack(spacing: 5) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(formatTimeRange(start: startDate, endTimeStr: eventEndTime))
                                .font(.system(size: 13))
                        }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    // Location
                    if let loc = eventLocation, !loc.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10))
                            Text(loc)
                                .font(.system(size: 13))
                                .lineLimit(1)
                        }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    } else if let link = eventMeetingLink, !link.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 10))
                            Text(meetingLabel(link))
                                .font(.system(size: 13))
                        }
                        .foregroundColor(DesignSystem.Colors.blue)
                    }

                    // Description
                    if let desc = eventDescription, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .lineLimit(2)
                    }

                    // Attendees
                    if let attendees = eventAttendees, !attendees.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "person.2")
                                .font(.system(size: 10))
                            Text(attendees.prefix(3).joined(separator: ", ") + (attendees.count > 3 ? " +\(attendees.count - 3)" : ""))
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }

                Spacer()
            }
        }
        .calmCard(padding: 14)
    }

    // MARK: - Connections List

    private var connectionsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Send to")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .textCase(.uppercase)
                .padding(.leading, DesignSystem.Spacing.xs)

            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .padding(.vertical, 40)
            } else if connections.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 28))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    Text("No connections yet")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 0) {
                    // Show matching connections first, then others
                    let sorted = sortedConnections()
                    ForEach(sorted, id: \.connectionId) { conn in
                        connectionRow(conn)

                        if conn.connectionId != sorted.last?.connectionId {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .calmCard(padding: 8)
            }
        }
    }

    private func connectionRow(_ conn: NetworkConnection) -> some View {
        let match = matchingConnections.first(where: { $0.userId == conn.userId })
        let isSending = sendingToUserId == conn.userId
        let isSent = sentToUserIds.contains(conn.userId ?? -1)

        return HStack(spacing: 12) {
            ProfilePictureView(
                profilePictureUrl: conn.profilePictureUrl,
                size: 40
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(conn.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                if let match = match, !match.matchingInterests.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundColor(DesignSystem.Colors.violet)
                        Text(match.matchingInterests.prefix(3).joined(separator: ", "))
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.violet)
                    }
                } else if let shared = conn.sharedInterests, !shared.isEmpty {
                    Text("\(shared.count) shared interest\(shared.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }

            Spacer()

            if isSent {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(DesignSystem.Colors.emerald)
            } else {
                Button {
                    guard let userId = conn.userId else { return }
                    Task { await shareToConnection(userId: userId) }
                } label: {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 60, height: 30)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 11))
                            Text("Send")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(DesignSystem.Colors.violet)
                        .clipShape(Capsule())
                    }
                }
                .disabled(isSending || sendingToUserId != nil)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func shareToConnection(userId: Int64) async {
        sendingToUserId = userId
        defer { sendingToUserId = nil }

        do {
            let response = try await APIService.shared.inviteConnectionsToEvent(
                eventId: eventId, connectionUserIds: [userId])
            if response.success {
                sentToUserIds.insert(userId)
            } else {
                errorMessage = response.message
            }
        } catch {
            errorMessage = "Failed to share: \(error.localizedDescription)"
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        async let connectionsTask = APIService.shared.getNetworkConnections()
        async let matchesTask = loadMatches()

        do {
            connections = try await connectionsTask
        } catch {
            print("Failed to load connections: \(error)")
        }

        await matchesTask
    }

    private func loadMatches() async {
        do {
            matchingConnections = try await APIService.shared.getMatchingConnectionsForEvent(eventId: eventId)
        } catch {
            print("Failed to load matching connections: \(error)")
        }
    }

    // MARK: - Helpers

    private func sortedConnections() -> [NetworkConnection] {
        let matchUserIds = Set(matchingConnections.map { $0.userId })
        return connections.sorted { a, b in
            let aMatches = matchUserIds.contains(a.userId ?? -1)
            let bMatches = matchUserIds.contains(b.userId ?? -1)
            if aMatches != bMatches { return aMatches }
            return (a.fullName ?? "") < (b.fullName ?? "")
        }
    }

    private func parseDate(_ str: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: str) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: str) { return d }
        let local = DateFormatter()
        local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = local.date(from: str) { return d }
        local.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return local.date(from: str)
    }

    private func formatTimeRange(start: Date, endTimeStr: String?) -> String {
        let timeOnly = DateFormatter()
        timeOnly.dateFormat = "h:mm a"

        var result = formatTime(start)

        if let endStr = endTimeStr, let endDate = parseDate(endStr) {
            result += " - \(timeOnly.string(from: endDate))"
            let minutes = Int(endDate.timeIntervalSince(start) / 60)
            if minutes > 0 {
                if minutes >= 60 {
                    let h = minutes / 60
                    let m = minutes % 60
                    result += m == 0 ? " · \(h)h" : " · \(h)h \(m)m"
                } else {
                    result += " · \(minutes)m"
                }
            }
        }

        return result
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today' h:mm a"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "'Tomorrow' h:mm a"
        } else {
            formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        }
        return formatter.string(from: date)
    }

    private func meetingLabel(_ link: String) -> String {
        let l = link.lowercased()
        if l.contains("zoom") { return "Zoom" }
        if l.contains("teams") { return "Teams" }
        if l.contains("meet.google") { return "Meet" }
        return "Online"
    }
}
