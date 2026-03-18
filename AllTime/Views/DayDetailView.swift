import SwiftUI

/// Apple Calendar-style day detail view showing time-grouped events
struct DayDetailView: View {
    let date: Date
    let initialEvents: [CalendarEvent]
    var discoveryViewModel: EventDiscoveryViewModel? = nil
    @Environment(\.dismiss) var dismiss
    @State private var selectedEventId: Int64?

    // Local copy of events that can be modified after deletion
    @State private var localEvents: [CalendarEvent] = []

    // Edit/Delete state
    @State private var eventToEdit: Int64?
    @State private var eventDetailsToEdit: EventDetails?
    @State private var isLoadingEventDetails = false
    @State private var showingEditEvent = false
    @State private var eventToDelete: CalendarEvent?
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var eventToShare: CalendarEvent?

    private let apiService = APIService()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    var body: some View {
        NavigationView {
            List {
                // Date header section
                Section {
                    Text(dateFormatter.string(from: date))
                        .font(.title2)
                        .fontWeight(.bold)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                }

                if localEvents.isEmpty {
                    // Empty state - actionable framing
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(DesignSystem.Colors.primary.opacity(0.7))

                            Text("Unscheduled day")
                                .font(.headline)
                                .foregroundColor(DesignSystem.Colors.primaryText)

                            Text("Protect this time intentionally")
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    // All-day events first
                    let allDayEvents = localEvents.filter { $0.allDay }
                    let timedEvents = localEvents.filter { !$0.allDay }
                        .sorted {
                            guard let start1 = $0.startDate, let start2 = $1.startDate else { return false }
                            return start1 < start2
                        }

                    if !allDayEvents.isEmpty {
                        Section(header: Text("All Day").font(.subheadline).foregroundColor(.gray)) {
                            ForEach(allDayEvents) { event in
                                SwipeableEventRow(
                                    event: event,
                                    onTap: {
                                        selectedEventId = Int64(event.id)
                                    },
                                    onEdit: {
                                        loadEventDetailsForEdit(eventId: Int64(event.id))
                                    },
                                    onDelete: {
                                        eventToDelete = event
                                        showingDeleteConfirmation = true
                                    },
                                    onShare: {
                                        eventToShare = event
                                    }
                                )
                            }
                        }
                    }

                    // Timed events grouped by hour
                    if !timedEvents.isEmpty {
                        ForEach(groupedEvents(timedEvents), id: \.key) { group in
                            Section(header: Text(formatHour(group.key)).font(.caption).foregroundColor(.gray)) {
                                ForEach(group.value) { event in
                                    SwipeableEventRow(
                                        event: event,
                                        onTap: {
                                            selectedEventId = Int64(event.id)
                                        },
                                        onEdit: {
                                            loadEventDetailsForEdit(eventId: Int64(event.id))
                                        },
                                        onDelete: {
                                            eventToDelete = event
                                            showingDeleteConfirmation = true
                                        },
                                        onShare: {
                                            eventToShare = event
                                        }
                                    )
                                }
                            }
                        }
                    }
                }

                // Discovered Event Suggestions
                if let vm = discoveryViewModel {
                    let suggestions = vm.eventsForDate(date)
                    if !suggestions.isEmpty {
                        Section(header: HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .foregroundColor(Color(hex: "5EEAD4"))
                            Text("Suggestions")
                        }) {
                            ForEach(suggestions) { event in
                                DiscoveredEventCard(
                                    event: event,
                                    onAccept: { Task { await vm.acceptEvent(event) } },
                                    onDismiss: { Task { await vm.dismissEvent(event) } }
                                )
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                }

                // Mood Check-In at the bottom
                Section {
                    MoodCheckInCardView()
                        .listRowInsets(EdgeInsets(top: 20, leading: 16, bottom: 40, trailing: 16))
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        HapticManager.shared.lightTap()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { selectedEventId != nil },
                set: { if !$0 { selectedEventId = nil } }
            )) {
                if let eventId = selectedEventId {
                    EventDetailView(eventId: eventId)
                }
            }
            .sheet(isPresented: $showingEditEvent) {
                if let eventDetails = eventDetailsToEdit {
                    AddEventView(eventDetailsToEdit: eventDetails)
                        .onDisappear {
                            eventDetailsToEdit = nil
                            // Refresh calendar after edit
                            NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)
                        }
                }
            }
            .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    eventToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let event = eventToDelete {
                        deleteEvent(event)
                    }
                }
            } message: {
                if let event = eventToDelete {
                    Text("Are you sure you want to delete \"\(event.title)\"? This action cannot be undone.")
                }
            }
            .alert("Error", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = deleteError {
                    Text(error)
                }
            }
            .sheet(isPresented: Binding(
                get: { eventToShare != nil },
                set: { if !$0 { eventToShare = nil } }
            )) {
                if let event = eventToShare {
                    ShareEventSheet(event: event)
                }
            }
            .overlay {
                if isLoadingEventDetails {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Loading...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                }
            }
            .onAppear {
                localEvents = initialEvents
            }
        }
    }

    // MARK: - Actions

    private func loadEventDetailsForEdit(eventId: Int64) {
        isLoadingEventDetails = true

        Task {
            do {
                let details = try await apiService.getEventDetails(eventId: eventId)
                await MainActor.run {
                    self.eventDetailsToEdit = details
                    self.isLoadingEventDetails = false
                    self.showingEditEvent = true
                }
            } catch {
                await MainActor.run {
                    self.isLoadingEventDetails = false
                    self.deleteError = "Failed to load event for editing: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteEvent(_ event: CalendarEvent) {
        isDeleting = true

        Task {
            do {
                try await apiService.deleteEvent(eventId: Int64(event.id))
                await MainActor.run {
                    isDeleting = false
                    eventToDelete = nil
                    // Remove the deleted event from local list (keeps popup open)
                    localEvents.removeAll { $0.id == event.id }
                    // Post notification to refresh calendar views
                    NotificationCenter.default.post(name: NSNotification.Name("EventDeleted"), object: nil)
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    eventToDelete = nil
                    deleteError = "Failed to delete event: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func groupedEvents(_ events: [CalendarEvent]) -> [(key: Int, value: [CalendarEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            guard let startDate = event.startDate else { return 0 }
            return calendar.component(.hour, from: startDate)
        }
        return grouped.sorted { $0.key < $1.key }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        if let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}

// MARK: - Swipeable Event Row (for List with swipe actions)
struct SwipeableEventRow: View {
    let event: CalendarEvent
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onShare: (() -> Void)? = nil

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private var eventColor: Color {
        event.displayColor
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.lightTap()
            onTap()
        }) {
            HStack(alignment: .center, spacing: 12) {
                // Color indicator
                Rectangle()
                    .fill(eventColor)
                    .frame(width: 4, height: 50)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // Time
                    if !event.allDay, let startDate = event.startDate, let endDate = event.endDate {
                        Text("\(timeFormatter.string(from: startDate)) - \(timeFormatter.string(from: endDate))")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    } else if event.allDay {
                        Text("All day")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }

                    // Location
                    if let location = event.location {
                        if let locationName = location.name, !locationName.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 11))
                                Text(locationName)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.gray)
                        } else if let locationAddress = location.address, !locationAddress.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 11))
                                Text(locationAddress)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                            }
                            .foregroundColor(.gray)
                        }
                    }
                }

                Spacer()

                // Chevron to indicate tappable
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                HapticManager.shared.warning()
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                HapticManager.shared.lightTap()
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)

            if let onShare = onShare {
                Button {
                    HapticManager.shared.lightTap()
                    onShare()
                } label: {
                    Label("Share", systemImage: "paperplane")
                }
                .tint(DesignSystem.Colors.violet)
            }
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.gray)
            .padding(.horizontal)
            .padding(.top, 8)
    }
}

// MARK: - Event Card (for non-swipeable contexts)
struct EventCard: View {
    let event: CalendarEvent
    let onTap: () -> Void

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private var eventColor: Color {
        event.displayColor
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.lightTap()
            onTap()
        }) {
            HStack(alignment: .top, spacing: 12) {
                // Color indicator (uses displayColor which respects user-set eventColor)
                Rectangle()
                    .fill(eventColor)
                    .frame(width: 4)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    // Time
                    if !event.allDay, let startDate = event.startDate, let endDate = event.endDate {
                        Text("\(timeFormatter.string(from: startDate)) - \(timeFormatter.string(from: endDate))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                            // Location
                            if let location = event.location {
                                if let locationName = location.name, !locationName.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 12))
                                        Text(locationName)
                                            .font(.subheadline)
                                    }
                                    .foregroundColor(.gray)
                                } else if let locationAddress = location.address, !locationAddress.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 12))
                                        Text(locationAddress)
                                            .font(.subheadline)
                                    }
                                    .foregroundColor(.gray)
                                }
                            }
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .buttonStyle(SmoothButtonStyle(haptic: .light))
    }
}

// MARK: - Preview
#Preview {
    DayDetailView(
        date: Date(),
        initialEvents: [
            CalendarEvent(
                id: 1,
                title: "Team Meeting",
                description: nil,
                startTime: "2025-11-13T09:00:00Z",
                endTime: "2025-11-13T10:00:00Z",
                allDay: false,
                source: "google",
                sourceColor: "#4285F4",
                location: EventLocation(name: "Conference Room A", address: nil, coordinates: nil),
                attendees: nil,
                recurrence: nil,
                metadata: nil
            ),
            CalendarEvent(
                id: 2,
                title: "Client Call",
                description: nil,
                startTime: "2025-11-13T14:00:00Z",
                endTime: "2025-11-13T15:00:00Z",
                allDay: false,
                source: "microsoft",
                sourceColor: "#FF6B35",
                location: nil,
                attendees: nil,
                recurrence: nil,
                metadata: nil
            )
        ]
    )
}

