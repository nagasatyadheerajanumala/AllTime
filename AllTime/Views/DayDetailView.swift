import SwiftUI

/// Apple Calendar-style day detail view showing time-grouped events
struct DayDetailView: View {
    let date: Date
    let events: [CalendarEvent]
    @Environment(\.dismiss) var dismiss
    @State private var selectedEventId: Int64?
    
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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Date header
                    Text(dateFormatter.string(from: date))
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    if events.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "calendar")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            
                            Text("No events")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else {
                        // All-day events first
                        let allDayEvents = events.filter { $0.allDay }
                        let timedEvents = events.filter { !$0.allDay }
                            .sorted { 
                                guard let start1 = $0.startDate, let start2 = $1.startDate else { return false }
                                return start1 < start2
                            }
                        
                        if !allDayEvents.isEmpty {
                            SectionHeader(title: "All Day")
                            
                            ForEach(allDayEvents) { event in
                                EventCard(event: event, onTap: {
                                    selectedEventId = Int64(event.id)
                                })
                            }
                        }
                        
                        // Timed events grouped by hour
                        if !timedEvents.isEmpty {
                            SectionHeader(title: "Scheduled")
                            
                            ForEach(groupedEvents(timedEvents), id: \.key) { group in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(formatHour(group.key))
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .padding(.leading)
                                    
                                    ForEach(group.value) { event in
                                        EventCard(event: event, onTap: {
                                            selectedEventId = Int64(event.id)
                                        })
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
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

// MARK: - Event Card
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
        event.sourceColorAsColor
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Color indicator
                Rectangle()
                    .fill(eventColor)
                    .frame(width: 4)
                
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
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    DayDetailView(
        date: Date(),
        events: [
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

