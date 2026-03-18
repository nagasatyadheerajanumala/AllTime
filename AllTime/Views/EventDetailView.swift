import SwiftUI

struct EventDetailView: View {
    let eventId: Int64
    @State private var eventDetails: EventDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var copiedLink = false
    @State private var showingEditEvent = false
    @State private var showingDeleteConfirmation = false
    @State private var showingShareSheet = false
    @State private var isDeleting = false
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
                DesignSystem.Colors.background
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
                // Hero Header
                eventHeroHeader(event)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .cardStagger(index: 0)

                // Main Content Cards
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Join Meeting button
                    if event.hasMeetingLink, let meetingLink = event.meetingLink {
                        joinMeetingSection(event, meetingLink: meetingLink)
                            .cardStagger(index: 1)
                    }

                    // When & Where
                    whenWhereSection(event)
                        .cardStagger(index: 2)

                    if let description = event.description, !description.isEmpty {
                        descriptionSection(description)
                            .cardStagger(index: 3)
                    }

                    if let attendees = event.attendees, !attendees.isEmpty {
                        attendeesSection(attendees, organizerEmail: event.organizerEmail)
                            .cardStagger(index: 4)
                    } else if let organizerEmail = event.organizerEmail, !organizerEmail.isEmpty {
                        // Standalone organizer card when no attendees
                        organizerStandaloneSection(organizerEmail)
                            .cardStagger(index: 4)
                    }

                    // Reminders Section
                    if let startDate = event.startDate {
                        EventRemindersSection(
                            eventId: event.id,
                            eventStartDate: startDate
                        )
                        .cardStagger(index: 5)
                    }

                    // Open in Calendar Link
                    if let htmlLink = event.htmlLink, !htmlLink.isEmpty {
                        openInCalendarSection(htmlLink, source: event.source)
                            .cardStagger(index: 6)
                    }

                    // Calendar Source footnote
                    calendarSourceFootnote(event)
                        .cardStagger(index: 7)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenMargin)
                .padding(.top, DesignSystem.Spacing.md)

                Spacer(minLength: 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("Share Event", systemImage: "paperplane")
                    }

                    Button {
                        showingEditEvent = true
                    } label: {
                        Label("Edit Event", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Event", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
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
        .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("Are you sure you want to delete this event? This action cannot be undone.")
        }
        .sheet(isPresented: $showingEditEvent) {
            if let event = eventDetails {
                AddEventView(eventDetailsToEdit: event)
                    .onDisappear {
                        loadEventDetails()
                    }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let event = eventDetails {
                ShareEventSheet(eventDetails: event)
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
                .frame(height: 3)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Title
                Text(event.title ?? "Untitled Event")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                // Badges Row — only allDay + cancelled as tinted pills
                if event.allDay || event.isCancelled {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if event.allDay {
                            allDayBadge
                        }

                        if event.isCancelled {
                            cancelledBadge
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenMargin)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.cardBackground)
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
                .padding(DesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.green, DesignSystem.Colors.success],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(DesignSystem.CornerRadius.lg)
                .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(SmoothButtonStyle())

            // Meeting Link Card with Copy Button
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(width: 32, height: 32)
                    .background(DesignSystem.Colors.primary.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.sm)

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

                Button(action: {
                    UIPasteboard.general.string = meetingLink
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        copiedLink = true
                    }
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
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
            .calmCard()
        }
    }

    // MARK: - When & Where Section
    @ViewBuilder
    private func whenWhereSection(_ event: EventDetails) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date & Time
            if let startDate = event.startDate {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .frame(width: 20, alignment: .center)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(relativeDateText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.secondaryText)

                        Text(Self.dateFormatter.string(from: startDate))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .padding(.top, 2)

                        HStack(spacing: 6) {
                            Text(timeRangeText)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(DesignSystem.Colors.secondaryText)

                            if !event.allDay, !event.duration.isEmpty {
                                Text("·")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)

                                Text(event.duration)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                            }
                        }
                    }

                    Spacer()
                }
            }

            // Divider + Location
            if let location = event.location, !location.isEmpty {
                Divider()
                    .padding(.vertical, 12)

                locationContent(location)
            }
        }
        .calmCard()
    }

    // MARK: - Location Content
    @ViewBuilder
    private func locationContent(_ location: String) -> some View {
        let isVideoLink = isVideoMeetingLink(location)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                Image(systemName: isVideoLink ? "video.fill" : "mappin")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .frame(width: 20, alignment: .center)

                VStack(alignment: .leading, spacing: 6) {
                    Text(isVideoLink ? "Video Meeting" : "Location")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)

                    if isVideoLink {
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
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                if isVideoLink {
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
                            .cornerRadius(DesignSystem.CornerRadius.sm)
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
                .padding(.leading, 28)
            }
        }
    }

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
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Notes")
                .font(DesignSystem.Typography.footnote)
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            LinkableText(text: description)
                .font(.system(size: 15, weight: .regular))
        }
        .calmCard()
    }

    // MARK: - Attendees Section
    @ViewBuilder
    private func attendeesSection(_ attendees: [Attendee], organizerEmail: String?) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section Header
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text("Attendees")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)

                Spacer()

                Text("\(attendees.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(DesignSystem.CornerRadius.sm)
            }

            // Attendees List
            VStack(spacing: 0) {
                ForEach(Array(attendees.enumerated()), id: \.element.id) { index, attendee in
                    AttendeeRow(attendee: attendee)

                    if index < attendees.count - 1 {
                        Divider()
                            .padding(.leading, 40) // indent past avatar
                    }
                }
            }

            // Organizer footer row (merged into attendees card)
            if let email = organizerEmail, !email.isEmpty {
                Divider()

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .frame(width: 20, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Organized by")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Text(email)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: {
                        if let url = URL(string: "mailto:\(email)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
                .padding(.top, DesignSystem.Spacing.xs)
            }
        }
        .calmCard()
    }

    // MARK: - Standalone Organizer Section (when no attendees)
    @ViewBuilder
    private func organizerStandaloneSection(_ organizerEmail: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "crown.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text("Organizer")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)

                Text(organizerEmail)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            Spacer()

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
        .calmCard()
    }

    // MARK: - Calendar Source Footnote
    @ViewBuilder
    private func calendarSourceFootnote(_ event: EventDetails) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: sourceIcon(event.source))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            Text("From \(sourceDisplayName(event.source))")
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    // MARK: - Open in Calendar Section
    @ViewBuilder
    private func openInCalendarSection(_ htmlLink: String, source: String) -> some View {
        Button(action: {
            if let url = URL(string: htmlLink) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(width: 20, alignment: .center)

                Text("Open in \(sourceDisplayName(source))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .calmCard()
        }
        .buttonStyle(SmoothButtonStyle())
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

    // MARK: - Badges (tinted pills)
    private var allDayBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("All Day")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(DesignSystem.Colors.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(DesignSystem.Colors.primary.opacity(0.12))
        .cornerRadius(6)
    }

    private var cancelledBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("Cancelled")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(DesignSystem.Colors.errorRed)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(DesignSystem.Colors.errorRed.opacity(0.12))
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
                .foregroundColor(DesignSystem.Colors.primaryText)

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
        if let url = URL(string: "https://maps.apple.com/?q=\(encodedLocation)") {
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

    private func deleteEvent() {
        isDeleting = true

        Task {
            do {
                try await apiService.deleteEvent(eventId: eventId)
                await MainActor.run {
                    isDeleting = false
                    NotificationCenter.default.post(name: NSNotification.Name("EventDeleted"), object: nil)
                    dismiss()
                }
            } catch let error as NSError {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = "Failed to delete event: \(error.localizedDescription)"
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = "Failed to delete event: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Attendee Row Component
struct AttendeeRow: View {
    let attendee: Attendee

    private var avatarColor: Color {
        let name = attendee.displayName ?? attendee.email ?? ""
        let hash = abs(name.hashValue)
        return DesignSystem.Colors.eventColors[hash % DesignSystem.Colors.eventColors.count]
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "accepted":
            return DesignSystem.Colors.success
        case "declined":
            return Color(hex: "FF3B30")
        case "tentative":
            return DesignSystem.Colors.warning
        case "needsaction":
            return Color(hex: "8E8E93")
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
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Avatar — 32x32, flat color from name hash
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.12))
                    .frame(width: DesignSystem.Components.avatarMedium, height: DesignSystem.Components.avatarMedium)

                if let name = attendee.displayName, !name.isEmpty {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(avatarColor)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(avatarColor)
                }
            }

            // Name and Email
            VStack(alignment: .leading, spacing: 2) {
                if let name = attendee.displayName, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
                if let email = attendee.email {
                    Text(email)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Status Badge — tinted pill
            if let status = attendee.responseStatus, !status.isEmpty {
                Text(statusText(status))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(statusColor(status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(status).opacity(0.12))
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Linkable Text Component
struct LinkableText: View {
    let text: String
    var font: Font = .system(size: 15, weight: .regular)

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
            if match.range.location > lastEnd {
                let beforeRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
                let beforeText = nsString.substring(with: beforeRange)
                components.append((text: beforeText, url: nil))
            }

            let urlString = nsString.substring(with: match.range)
            let url = URL(string: urlString)
            components.append((text: urlString, url: url))

            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < nsString.length {
            let remainingText = nsString.substring(from: lastEnd)
            components.append((text: remainingText, url: nil))
        }

        if components.isEmpty {
            components.append((text: text, url: nil))
        }

        return components
    }

    var body: some View {
        textWithLinks
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(4)
    }

    @ViewBuilder
    private var textWithLinks: some View {
        let components = textComponents

        if components.count == 1 && components[0].url == nil {
            Text(text)
                .font(font)
                .foregroundColor(DesignSystem.Colors.primaryText)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                buildAttributedText(components)
            }
        }
    }

    @ViewBuilder
    private func buildAttributedText(_ components: [(text: String, url: URL?)]) -> some View {
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

    func font(_ font: Font) -> LinkableText {
        var copy = self
        copy.font = font
        return copy
    }
}

#Preview {
    EventDetailView(eventId: 1)
}
