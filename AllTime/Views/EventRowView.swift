import SwiftUI

struct EventRowView: View {
    let event: Event
    
    // Cache DateFormatters as static to avoid repeated allocation
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()
    
    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                if let startTime = event.startDate {
                    Text(Self.timeFormatter.string(from: startTime))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                if let duration = event.duration,
                   let durationString = Self.durationFormatter.string(from: duration) {
                    Text(durationString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 60, alignment: .leading)
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let location = event.location {
                    if let locationName = location.name, !locationName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(locationName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    } else if let locationAddress = location.address, !locationAddress.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(locationAddress)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    // Provider badge
                    ProviderBadge(provider: event.source)
                    
                    // Reminder badge
                    ReminderBadgeView(eventId: event.id)
                    
                    Spacer()
                    
                    // All-day indicator
                    if event.allDay {
                        Text("All Day")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ProviderBadge: View {
    let provider: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: providerIcon)
                .font(.caption2)
            
            Text(provider.capitalized)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(providerColor.opacity(0.1))
        .foregroundColor(providerColor)
        .cornerRadius(4)
    }
    
    private var providerIcon: String {
        switch provider.lowercased() {
        case "google":
            return "g.circle.fill"
        case "microsoft", "outlook":
            return "m.circle.fill"
        case "apple":
            return "applelogo"
        default:
            return "calendar"
        }
    }
    
    private var providerColor: Color {
        switch provider.lowercased() {
        case "google":
            return .red
        case "microsoft", "outlook":
            return .blue
        case "apple":
            return .gray
        default:
            return .secondary
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        EventRowView(event: CalendarEvent(
            id: 1,
            title: "Team Meeting",
            description: "Weekly team sync",
            startTime: "2024-01-15T10:00:00Z",
            endTime: "2024-01-15T11:00:00Z",
            allDay: false,
            source: "google",
            sourceColor: "#4285F4",
            location: EventLocation(name: "Conference Room A", address: nil, coordinates: nil),
            attendees: nil,
            recurrence: nil,
            metadata: nil
        ))
        
        EventRowView(event: CalendarEvent(
            id: 2,
            title: "Doctor Appointment",
            description: nil,
            startTime: "2024-01-15T14:00:00Z",
            endTime: "2024-01-15T15:00:00Z",
            allDay: false,
            source: "apple",
            sourceColor: "#AF52DE",
            location: nil,
            attendees: nil,
            recurrence: nil,
            metadata: nil
        ))
    }
    .padding()
}
