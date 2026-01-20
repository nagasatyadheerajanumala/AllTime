import SwiftUI

struct EventDetailView: View {
    let eventId: Int64
    @State private var eventDetails: EventDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var copiedLink = false
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

                    // Organizer Section
                    if let organizerEmail = event.organizerEmail, !organizerEmail.isEmpty {
                        organizerSection(organizerEmail)
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

                    // Open in Calendar Link
                    if let htmlLink = event.htmlLink, !htmlLink.isEmpty {
                        openInCalendarSection(htmlLink, source: event.source)
                    }
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
        VStack(spacing: 12) {
            // Join Meeting Button
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
                            .frame(width: 50, height: 50)

                        Image(systemName: event.meetingIcon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    // Text content
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Join \(event.meetingTypeLabel)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Text("Tap to join now")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.green, DesignSystem.Colors.success],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())

            // Meeting Link Card with Copy Button
            HStack(spacing: 12) {
                // Link icon
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(width: 32, height: 32)
                    .background(DesignSystem.Colors.primary.opacity(0.1))
                    .cornerRadius(8)

                // Link URL (truncated)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meeting Link")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    Text(meetingLink)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                // Copy Button
                Button(action: {
                    UIPasteboard.general.string = meetingLink
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    // Show copied feedback
                    withAnimation(.easeInOut(duration: 0.2)) {
                        copiedLink = true
                    }
                    // Reset after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            copiedLink = false
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: copiedLink ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                        Text(copiedLink ? "Copied!" : "Copy")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(copiedLink ? .white : DesignSystem.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(copiedLink ? Color.green : DesignSystem.Colors.primary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(14)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
            )
        }
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
        let isVideoLink = isVideoMeetingLink(location)

        DetailCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    IconCircle(
                        icon: isVideoLink ? "video.fill" : "mappin.circle.fill",
                        color: isVideoLink ? .blue : .red
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(isVideoLink ? "Video Meeting".uppercased() : "Location".uppercased())
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .tracking(0.5)

                        if isVideoLink {
                            // Make the link tappable
                            Button(action: {
                                if let url = URL(string: location) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text(location)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.primary)
                                    .underline()
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                        } else {
                            Text(location)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer()

                    if isVideoLink {
                        // Join button for video links
                        Button(action: {
                            if let url = URL(string: location) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Join")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                    } else {
                        Button(action: {
                            openInMaps(location: location)
                        }) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }
                }

                // Copy button for video links
                if isVideoLink {
                    Button(action: {
                        UIPasteboard.general.string = location
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Copy Link")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .padding(.leading, 52) // Align with text
                }
            }
        }
    }

    /// Check if a string is a video meeting link
    private func isVideoMeetingLink(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains("meet.google.com") ||
               lowercased.contains("teams.microsoft.com") ||
               lowercased.contains("teams.live.com") ||
               lowercased.contains("zoom.us") ||
               lowercased.contains("webex.com") ||
               lowercased.contains("gotomeeting.com") ||
               lowercased.contains("bluejeans.com")
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

                // Use LinkableText to make URLs clickable
                LinkableText(text: description)
                    .font(.system(size: 15, weight: .regular))
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
    
    // MARK: - Organizer Section
    @ViewBuilder
    private func organizerSection(_ organizerEmail: String) -> some View {
        DetailCard {
            HStack(spacing: 16) {
                IconCircle(
                    icon: "person.circle.fill",
                    color: .orange
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Organizer".uppercased())
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .tracking(0.5)

                    Text(organizerEmail)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.primary)
                }

                Spacer()

                // Email button
                Button(action: {
                    if let url = URL(string: "mailto:\(organizerEmail)") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
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

    // MARK: - Open in Calendar Section
    @ViewBuilder
    private func openInCalendarSection(_ htmlLink: String, source: String) -> some View {
        Button(action: {
            if let url = URL(string: htmlLink) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 16) {
                IconCircle(
                    icon: "arrow.up.right.square",
                    color: DesignSystem.Colors.primary
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Open in \(sourceDisplayName(source))")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("View and edit in your calendar app")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func sourceDisplayName(_ source: String) -> String {
        switch source.lowercased() {
        case "google":
            return "Google Calendar"
        case "microsoft":
            return "Outlook"
        case "eventkit", "apple":
            return "Apple Calendar"
        default:
            return "Calendar"
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
            return DesignSystem.Colors.success // iOS Green
        case "declined":
            return Color(hex: "FF3B30") // iOS Red
        case "tentative":
            return DesignSystem.Colors.warning // iOS Orange
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

// MARK: - Linkable Text Component
/// A text view that automatically detects and makes URLs clickable
struct LinkableText: View {
    let text: String
    var font: Font = .system(size: 15, weight: .regular)

    // Regex pattern to match URLs
    private static let urlPattern = try! NSRegularExpression(
        pattern: #"(https?://[^\s<>\"\)]+)"#,
        options: [.caseInsensitive]
    )

    private var textComponents: [(text: String, url: URL?)] {
        var components: [(text: String, url: URL?)] = []
        let nsString = text as NSString
        let range = NSRange(location: 0, length: nsString.length)

        var lastEnd = 0
        let matches = Self.urlPattern.matches(in: text, options: [], range: range)

        for match in matches {
            // Add text before the URL
            if match.range.location > lastEnd {
                let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                let beforeText = nsString.substring(with: beforeRange)
                components.append((text: beforeText, url: nil))
            }

            // Add the URL
            let urlString = nsString.substring(with: match.range)
            let url = URL(string: urlString)
            components.append((text: urlString, url: url))

            lastEnd = match.range.location + match.range.length
        }

        // Add remaining text after the last URL
        if lastEnd < nsString.length {
            let remainingText = nsString.substring(from: lastEnd)
            components.append((text: remainingText, url: nil))
        }

        // If no URLs found, return the whole text
        if components.isEmpty {
            components.append((text: text, url: nil))
        }

        return components
    }

    var body: some View {
        // Build the text with tappable links
        textWithLinks
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(4)
    }

    @ViewBuilder
    private var textWithLinks: some View {
        let components = textComponents

        if components.count == 1 && components[0].url == nil {
            // No URLs - just plain text
            Text(text)
                .font(font)
                .foregroundColor(.primary)
        } else {
            // Has URLs - build composite text
            VStack(alignment: .leading, spacing: 4) {
                // Use Text concatenation for inline links
                buildAttributedText(components)
            }
        }
    }

    @ViewBuilder
    private func buildAttributedText(_ components: [(text: String, url: URL?)]) -> some View {
        // Build Text with links using AttributedString (iOS 15+)
        let attributedString = buildAttributedString(components)
        Text(attributedString)
            .font(font)
            .tint(DesignSystem.Colors.primary)
    }

    private func buildAttributedString(_ components: [(text: String, url: URL?)]) -> AttributedString {
        var result = AttributedString()

        for component in components {
            var part = AttributedString(component.text)

            if let url = component.url {
                // Make this part a clickable link
                part.link = url
                part.foregroundColor = DesignSystem.Colors.primary
                part.underlineStyle = .single
            } else {
                part.foregroundColor = .primary
            }

            result.append(part)
        }

        return result
    }

    // Custom font modifier
    func font(_ font: Font) -> LinkableText {
        var copy = self
        copy.font = font
        return copy
    }
}

#Preview {
    EventDetailView(eventId: 1)
}
