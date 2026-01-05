import SwiftUI

struct EventDetailView: View {
    let eventId: Int64
    @State private var eventDetails: EventDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    private let apiService = APIService()
    
    // Cache DateFormatters for performance
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()
    
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()
    
    private var eventColor: Color {
        // Determine color based on source
        if let source = eventDetails?.source {
            switch source.lowercased() {
            case "google":
                return Color(hex: "4285F4")
            case "microsoft":
                return Color(hex: "FF6B35")
            case "eventkit", "apple":
                return Color(hex: "AF52DE")
            default:
                break
            }
        }
        
        // Fallback to title-based color
        if let title = eventDetails?.title {
            let hash = abs(title.hashValue)
            return DesignSystem.Colors.eventColors[hash % DesignSystem.Colors.eventColors.count]
        }
        
        return DesignSystem.Colors.primary
    }
    
    private var relativeDateText: String {
        guard let startDate = eventDetails?.startDate else { return "" }
        let calendar = Calendar.current
        
        if calendar.isDateInToday(startDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(startDate) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(startDate) {
            return "Yesterday"
        } else {
            return Self.dayFormatter.string(from: startDate)
        }
    }
    
    private var timeRangeText: String {
        guard let event = eventDetails, let startDate = event.startDate else { return "" }
        
        if event.allDay {
            return "All day"
        }
        
        if let endDate = event.endDate {
            let startTime = Self.timeFormatter.string(from: startDate)
            let endTime = Self.timeFormatter.string(from: endDate)
            
            let calendar = Calendar.current
            if calendar.isDate(startDate, inSameDayAs: endDate) {
                return "\(startTime) - \(endTime)"
            } else {
                let endDateFormatter = DateFormatter()
                endDateFormatter.dateFormat = "MMM d, h:mm a"
                endDateFormatter.timeZone = TimeZone.current
                endDateFormatter.locale = Locale.current
                return "\(startTime) - \(endDateFormatter.string(from: endDate))"
            }
        } else {
            return Self.timeFormatter.string(from: startDate)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Clean background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let event = eventDetails {
                    eventContent(event)
                }
            }
            .onAppear {
                loadEventDetails()
            }
        }
    }
    
    @ViewBuilder
    private func eventContent(_ event: EventDetails) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero Header with Color Accent
                eventHeroHeader(event)
                    .padding(.top, 8)
                
                // Main Content Cards
                VStack(spacing: 12) {
                    // Join Meeting button (prominent if meeting link exists)
                    if event.hasMeetingLink, let meetingLink = event.meetingLink {
                        joinMeetingSection(event, meetingLink: meetingLink)
                    }

                    if let startDate = event.startDate {
                        dateTimeSection(event, startDate: startDate)
                    }

                    if let location = event.location, !location.isEmpty {
                        locationSection(location)
                    }
                    
                    if let description = event.description, !description.isEmpty {
                        descriptionSection(description)
                    }
                    
                    if let attendees = event.attendees, !attendees.isEmpty {
                        attendeesSection(attendees)
                    }
                    
                    // Reminders Section
                    if let startDate = event.startDate {
                        EventRemindersSection(
                            eventId: event.id,
                            eventStartDate: startDate
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    calendarSourceSection(event)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                Spacer(minLength: 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
    }
    
    // MARK: - Hero Header
    @ViewBuilder
    private func eventHeroHeader(_ event: EventDetails) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Color accent bar
            Rectangle()
                .fill(eventColor)
                .frame(height: 4)
            
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(event.title ?? "Untitled Event")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Badges Row
                HStack(spacing: 8) {
                    ProviderBadge(provider: event.source)
                    
                    if event.allDay {
                        allDayBadge
                    }
                    
                    if event.isCancelled {
                        cancelledBadge
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(Color(UIColor.systemBackground))
        }
    }
    
    // MARK: - Join Meeting Section
    @ViewBuilder
    private func joinMeetingSection(_ event: EventDetails, meetingLink: String) -> some View {
        Button(action: {
            openMeetingLink(meetingLink)
        }) {
            HStack(spacing: 16) {
                // Meeting icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: event.meetingIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Join \(event.meetingTypeLabel)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("Tap to join the video call")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.green)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Date & Time Section
    @ViewBuilder
    private func dateTimeSection(_ event: EventDetails, startDate: Date) -> some View {
        DetailCard {
            HStack(alignment: .top, spacing: 16) {
                // Icon
                IconCircle(
                    icon: "calendar",
                    color: DesignSystem.Colors.primary
                )
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Relative date (Today/Tomorrow/etc)
                    Text(relativeDateText.uppercased())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .tracking(0.5)
                    
                    // Full date
                    Text(Self.dateFormatter.string(from: startDate))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    // Time range
                    Text(timeRangeText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    
                    // Duration
                    if !event.allDay, !event.duration.isEmpty {
                        Text("Duration: \(event.duration)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Location Section
    @ViewBuilder
    private func locationSection(_ location: String) -> some View {
        DetailCard {
            HStack(alignment: .top, spacing: 16) {
                IconCircle(
                    icon: "mappin.circle.fill",
                    color: .red
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Location".uppercased())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .tracking(0.5)
                    
                    Text(location)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Button(action: {
                    openInMaps(location: location)
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
    }
    
    // MARK: - Description Section
    @ViewBuilder
    private func descriptionSection(_ description: String) -> some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    IconCircle(
                        icon: "text.alignleft",
                        color: .purple
                    )
                    
                    Text("Description".uppercased())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .tracking(0.5)
                    
                    Spacer()
                }
                
                Text(description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
                    .padding(.leading, 60) // Align with icon
            }
        }
    }
    
    // MARK: - Attendees Section
    @ViewBuilder
    private func attendeesSection(_ attendees: [Attendee]) -> some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 16) {
                // Section Header
                HStack(spacing: 16) {
                    IconCircle(
                        icon: "person.2.fill",
                        color: .blue
                    )
                    
                    Text("Attendees".uppercased())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .tracking(0.5)
                    
                    Spacer()
                    
                    Text("\(attendees.count)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                
                // Attendees List
                VStack(spacing: 12) {
                    ForEach(attendees) { attendee in
                        AttendeeRow(attendee: attendee)
                    }
                }
            }
        }
    }
    
    // MARK: - Calendar Source Section
    @ViewBuilder
    private func calendarSourceSection(_ event: EventDetails) -> some View {
        DetailCard {
            HStack(spacing: 16) {
                IconCircle(
                    icon: sourceIcon(event.source),
                    color: .gray
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Calendar".uppercased())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .tracking(0.5)
                    
                    HStack(spacing: 8) {
                        ProviderBadge(provider: event.source)
                        Text("calendar")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Badges
    private var allDayBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("All Day")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(6)
    }
    
    private var cancelledBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("Cancelled")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.red)
        .cornerRadius(6)
    }
    
    // MARK: - Loading & Error Views
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(DesignSystem.Colors.primary)
            
            Text("Loading event details...")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
    }
    
    @ViewBuilder
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            Text(error)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Retry") {
                loadEventDetails()
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.primary)
        }
        .padding(32)
    }
    
    // MARK: - Helper Functions
    private func loadEventDetails() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let details = try await apiService.getEventDetails(eventId: eventId)
                await MainActor.run {
                    self.eventDetails = details
                    self.isLoading = false
                }
            } catch let error as NSError {
                await MainActor.run {
                    var errorMsg = "Failed to load event details"
                    
                    switch error.code {
                    case 401:
                        errorMsg = "Session expired. Please sign in again."
                    case 404:
                        errorMsg = "Event not found"
                    case 403:
                        errorMsg = "You don't have access to this event"
                    default:
                        errorMsg = error.localizedDescription
                    }
                    
                    self.errorMessage = errorMsg
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func openInMaps(location: String) {
        let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?q=\(encodedLocation)") {
            UIApplication.shared.open(url)
        }
    }

    private func openMeetingLink(_ link: String) {
        guard let url = URL(string: link) else { return }
        UIApplication.shared.open(url)
    }
    
    private func sourceIcon(_ source: String) -> String {
        switch source.lowercased() {
        case "google":
            return "calendar"
        case "microsoft":
            return "envelope"
        case "eventkit":
            return "apple.logo"
        default:
            return "calendar"
        }
    }
}

// MARK: - Detail Card Component
struct DetailCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
            )
    }
}

// MARK: - Icon Circle Component
struct IconCircle: View {
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 36, height: 36)
            
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Attendee Row Component
struct AttendeeRow: View {
    let attendee: Attendee
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "accepted":
            return Color(hex: "34C759") // iOS Green
        case "declined":
            return Color(hex: "FF3B30") // iOS Red
        case "tentative":
            return Color(hex: "FF9500") // iOS Orange
        case "needsaction":
            return Color(hex: "8E8E93") // iOS Gray
        default:
            return Color(hex: "8E8E93")
        }
    }
    
    private func statusText(_ status: String) -> String {
        switch status.lowercased() {
        case "accepted":
            return "Accepted"
        case "declined":
            return "Declined"
        case "tentative":
            return "Maybe"
        case "needsaction":
            return "Pending"
        default:
            return status.capitalized
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.2),
                                Color.blue.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                if let name = attendee.displayName, !name.isEmpty {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
            }
            
            // Name and Email
            VStack(alignment: .leading, spacing: 3) {
                if let name = attendee.displayName, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                if let email = attendee.email {
                    Text(email)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Status Badge
            if let status = attendee.responseStatus, !status.isEmpty {
                Text(statusText(status))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor(status))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    EventDetailView(eventId: 1)
}
