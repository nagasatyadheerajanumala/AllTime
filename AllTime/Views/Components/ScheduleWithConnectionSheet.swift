//
//  ScheduleWithConnectionSheet.swift
//  AllTime
//
//  Sheet for viewing shared-interest events with a connection.
//  Uses backend interest-based events endpoint for relevance.
//  Tap event for details, then share/invite.
//

import SwiftUI
import CoreLocation

struct ScheduleWithConnectionSheet: View {
    let connection: NetworkConnection
    let mutualFreeSlots: [FreeSlot]

    @State private var interestEvents: [InterestBasedEvent] = []
    @State private var isLoadingEvents = false
    @State private var distanceKm: Double?
    @State private var distanceLabel: String?
    @State private var selectedSlot: FreeSlot?
    @State private var showAddEvent = false
    @State private var isSendingInvite = false
    @State private var invitingEventId: Int64?
    @State private var selectedEventId: Int64?
    @State private var shareEventId: Int64?
    @State private var showResultAlert = false
    @State private var resultAlertMessage = ""
    @State private var resultAlertIsSuccess = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        eventsSection
                        if !mutualFreeSlots.isEmpty {
                            freeTimesSection
                        }
                        quickActionsSection
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenMargin)
                    .padding(.top, DesignSystem.Spacing.md)
                }
                .safeAreaPadding(.bottom, 40)
            }
            .navigationTitle("Share Events")
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
            .sheet(isPresented: $showAddEvent) {
                AddEventView(initialDate: dateFromSelectedSlot() ?? Date())
            }
            .sheet(isPresented: Binding(
                get: { selectedEventId != nil },
                set: { if !$0 { selectedEventId = nil } }
            )) {
                if let eventId = selectedEventId {
                    EventDetailView(eventId: eventId)
                }
            }
            .sheet(isPresented: Binding(
                get: { shareEventId != nil },
                set: { if !$0 { shareEventId = nil } }
            )) {
                if let eventId = shareEventId {
                    ShareEventByIdSheet(eventId: eventId)
                }
            }
            .alert(resultAlertMessage, isPresented: $showResultAlert) {
                Button("OK") {
                    if resultAlertIsSuccess {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            ProfilePictureView(
                profilePictureUrl: connection.profilePictureUrl,
                size: 52
            )

            Text(connection.displayName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            if let interests = connection.sharedInterests, !interests.isEmpty {
                Text("\(interests.count) shared interest\(interests.count == 1 ? "" : "s")")
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            // Distance
            if let label = distanceLabel {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10))
                    Text(label)
                        .font(.system(size: 12))
                }
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            } else if let km = distanceKm {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10))
                    Text(km < 1 ? "Less than 1 km apart" : "~\(Int(km)) km apart")
                        .font(.system(size: 12))
                }
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Events Section

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your Upcoming Events")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                    .textCase(.uppercase)
                Spacer()
                if !interestEvents.isEmpty {
                    Text("\(interestEvents.count) event\(interestEvents.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            .padding(.leading, DesignSystem.Spacing.xs)

            if isLoadingEvents {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .padding(.vertical, 30)
            } else if interestEvents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    Text("No upcoming events this week")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text("Create an event to share")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .calmCard(padding: 14)
            } else {
                VStack(spacing: 12) {
                    ForEach(interestEvents) { event in
                        eventCard(event)
                    }
                }
            }
        }
    }

    /// Rich event card — tappable for details, with share + invite actions
    private func eventCard(_ event: InterestBasedEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Tappable event content
            Button {
                selectedEventId = event.eventId
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Time
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(formatEventTime(event.startTime, endTime: event.endTime))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                    // Location or Online
                    if event.isOnlineEvent {
                        HStack(spacing: 6) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 11))
                            Text(meetingLabel(event.meetingLink))
                                .font(.system(size: 13))
                        }
                        .foregroundColor(DesignSystem.Colors.blue)
                    } else if let location = event.location, !location.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 11))
                            Text(location)
                                .font(.system(size: 13))
                                .lineLimit(1)
                        }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    // Description
                    if let desc = event.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    // Matching interests + free badge
                    HStack(spacing: 6) {
                        ForEach(event.matchingInterests.prefix(3), id: \.self) { interest in
                            Text(interest)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.violet)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(DesignSystem.Colors.violet.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        if event.connectionIsFree {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(DesignSystem.Colors.emerald)
                                    .frame(width: 5, height: 5)
                                Text("\(connection.displayName.components(separatedBy: " ").first ?? "They")'re free")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.emerald)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Action buttons
            HStack(spacing: 10) {
                // View details
                Button {
                    selectedEventId = event.eventId
                } label: {
                    Text("Details")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(DesignSystem.Colors.secondaryText.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                // Send invitation
                Button {
                    guard let userId = connection.userId else { return }
                    invitingEventId = event.eventId
                    Task {
                        await inviteConnectionToEvent(eventId: event.eventId, connectionUserId: userId)
                        invitingEventId = nil
                    }
                } label: {
                    if invitingEventId == event.eventId {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 120, height: 30)
                    } else {
                        HStack(spacing: 5) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 11))
                            Text("Send Invitation")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(DesignSystem.Colors.violet)
                        .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
                .disabled(invitingEventId != nil)
            }
        }
        .calmCard(padding: 14)
    }

    // MARK: - Free Times

    private var freeTimesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mutual Free Time")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .textCase(.uppercase)
                .padding(.leading, DesignSystem.Spacing.xs)

            VStack(spacing: 0) {
                ForEach(mutualFreeSlots) { slot in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSlot = selectedSlot?.id == slot.id ? nil : slot
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedSlot?.id == slot.id ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedSlot?.id == slot.id ? DesignSystem.Colors.emerald : DesignSystem.Colors.tertiaryText)
                                .font(.system(size: 16))

                            Text("\(slot.startTime) – \(slot.endTime)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.primaryText)

                            Spacer()

                            Text("\(slot.durationMinutes) min")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if slot.id != mutualFreeSlots.last?.id {
                        Divider()
                    }
                }
            }
            .calmCard(padding: 12)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(spacing: 10) {
            if selectedSlot != nil {
                Button {
                    Task { await handleCreateFromSlot() }
                } label: {
                    HStack {
                        if isSendingInvite {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        }
                        Image(systemName: "calendar.badge.plus")
                        Text("Create Event & Invite")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(DesignSystem.Colors.violet)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSendingInvite)
            }

            Button {
                showAddEvent = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create New Event")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(DesignSystem.Colors.violet)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DesignSystem.Colors.violet.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Actions

    private func handleCreateFromSlot() async {
        guard let slot = selectedSlot,
              let connectionUserId = connection.userId else { return }
        isSendingInvite = true
        defer { isSendingInvite = false }
        await createEventAndInvite(slot: slot, connectionUserId: connectionUserId)
    }

    private func inviteConnectionToEvent(eventId: Int64, connectionUserId: Int64) async {
        do {
            let response = try await APIService.shared.inviteConnectionsToEvent(
                eventId: eventId, connectionUserIds: [connectionUserId])
            showResult(success: response.success, message: response.message)
        } catch {
            showResult(success: false, message: "Failed to send invite: \(error.localizedDescription)")
        }
    }

    private func createEventAndInvite(slot: FreeSlot, connectionUserId: Int64) async {
        guard let startDate = dateFromSlotTime(slot.startTime),
              let endDate = dateFromSlotTime(slot.endTime) else {
            showResult(success: false, message: "Could not parse slot time")
            return
        }
        do {
            let title = "Meetup with \(connection.displayName)"
            let response = try await APIService.shared.createEvent(
                title: title, description: nil, location: nil,
                startDate: startDate, endDate: endDate, isAllDay: false)
            NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)
            await inviteConnectionToEvent(eventId: response.id, connectionUserId: connectionUserId)
        } catch {
            showResult(success: false, message: "Failed to create event: \(error.localizedDescription)")
        }
    }

    private func showResult(success: Bool, message: String) {
        resultAlertIsSuccess = success
        resultAlertMessage = message
        showResultAlert = true
    }

    // MARK: - Data Loading

    private func loadData() async {
        // Post fresh location
        if let loc = LocationManager.shared.location {
            let locationAPI = LocationAPI()
            try? await locationAPI.updateLocation(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                address: nil as String?, city: nil as String?, country: nil as String?)
        }
        computeDistance()
        await loadInterestEvents()
    }

    private func computeDistance() {
        if let userLocation = LocationManager.shared.location,
           let connLat = connection.latitude,
           let connLng = connection.longitude {
            let connLocation = CLLocation(latitude: connLat, longitude: connLng)
            distanceKm = userLocation.distance(from: connLocation) / 1000.0
            return
        }
        let userCity = LocationManager.shared.locationString
        let connCity = connection.city ?? connection.location
        if let userCity = userCity, let connCity = connCity,
           !userCity.isEmpty, !connCity.isEmpty {
            let userLower = userCity.lowercased()
            let connLower = connCity.lowercased()
            if userLower.contains(connLower) || connLower.contains(userLower) {
                distanceKm = 0
                distanceLabel = "Same city"
            }
        }
    }

    private func loadInterestEvents() async {
        guard let userId = connection.userId else { return }
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        do {
            interestEvents = try await APIService.shared.getInterestBasedEvents(
                connectionUserId: userId)
        } catch {
            print("Failed to load interest-based events: \(error)")
        }
    }

    // MARK: - Helpers

    private func formatEventTime(_ startTime: String, endTime: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"

        guard let startDate = fmt.date(from: startTime) else {
            if let tIdx = startTime.firstIndex(of: "T") {
                return String(startTime[startTime.index(after: tIdx)...].prefix(5))
            }
            return startTime
        }

        let cal = Calendar.current
        var dayLabel: String
        if cal.isDateInToday(startDate) {
            dayLabel = "Today"
        } else if cal.isDateInTomorrow(startDate) {
            dayLabel = "Tomorrow"
        } else {
            let dayFmt = DateFormatter()
            dayFmt.dateFormat = "EEE, MMM d"
            dayLabel = dayFmt.string(from: startDate)
        }

        var result = "\(dayLabel) \(timeFmt.string(from: startDate))"
        if let endDate = fmt.date(from: endTime) {
            result += " – \(timeFmt.string(from: endDate))"
            let minutes = Int(endDate.timeIntervalSince(startDate) / 60)
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

    private func meetingLabel(_ link: String?) -> String {
        guard let link = link?.lowercased() else { return "Online" }
        if link.contains("zoom") { return "Zoom" }
        if link.contains("teams") { return "Teams" }
        if link.contains("meet.google") { return "Google Meet" }
        return "Online"
    }

    private func dateFromSlotTime(_ timeString: String) -> Date? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }

    private func dateFromSelectedSlot() -> Date? {
        guard let slot = selectedSlot else { return nil }
        return dateFromSlotTime(slot.startTime)
    }
}
