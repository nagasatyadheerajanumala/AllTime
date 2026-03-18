//
//  NetworkView.swift
//  AllTime
//
//  My Network — manage connections, view suggestions, add by email
//

import SwiftUI

struct NetworkView: View {
    @StateObject private var viewModel = NetworkViewModel()
    @State private var showAddSheet = false
    @State private var smartCardActionMessage: String?
    @State private var showSmartCardAlert = false

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 20) {

                    // MARK: - Stats Header
                    if let stats = viewModel.stats {
                        HStack(spacing: 16) {
                            statBadge(
                                count: stats.connectionCount,
                                label: "Connections",
                                color: DesignSystem.Colors.violet
                            )
                            statBadge(
                                count: stats.pendingRequestCount,
                                label: "Pending",
                                color: DesignSystem.Colors.amber
                            )
                        }
                        .padding(.horizontal, 4)
                    }

                    // MARK: - Pending Requests
                    if !viewModel.pendingRequests.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            sectionLabel("Pending Requests")

                            ForEach(viewModel.pendingRequests) { request in
                                pendingRequestCard(request)
                            }
                        }
                    }

                    // MARK: - Event Invites
                    if !viewModel.eventInvites.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            sectionLabel("Event Invites")

                            ForEach(viewModel.eventInvites) { invite in
                                eventInviteCard(invite)
                            }
                        }
                    }

                    // MARK: - Smart Social Cards
                    if !viewModel.smartCards.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                sectionLabel("Opportunities")
                                Spacer()
                                if viewModel.isLoadingSmartCards {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                }
                            }

                            ForEach(viewModel.smartCards) { card in
                                SmartSocialCardView(
                                    card: card,
                                    onAction: {
                                        Task {
                                            let result = await viewModel.executeSmartCardAction(card)
                                            smartCardActionMessage = result.message
                                            showSmartCardAlert = true
                                        }
                                    },
                                    onDismiss: {
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            viewModel.smartCards.removeAll { $0.id == card.id }
                                        }
                                    }
                                )
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                        }
                    } else if viewModel.isLoadingSmartCards {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text("Finding opportunities...")
                                .font(DesignSystem.Typography.footnote)
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }

                    // MARK: - Suggestions (legacy)
                    if !viewModel.suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            sectionLabel("Suggested Meetups")

                            ForEach(viewModel.suggestions) { suggestion in
                                suggestionCard(suggestion)
                            }
                        }
                    }

                    // MARK: - Connections
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        sectionLabel("Connections")

                        if viewModel.connections.isEmpty && !viewModel.isLoading {
                            VStack(spacing: 12) {
                                Image(systemName: "person.2.slash")
                                    .font(.system(size: 32))
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                                Text("No connections yet")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                Text("Add people by email to see their availability and get meetup suggestions")
                                    .font(DesignSystem.Typography.footnote)
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .calmCard(padding: 16)
                        } else {
                            ForEach(viewModel.connections) { connection in
                                NavigationLink(destination: ConnectionDetailView(connection: connection)) {
                                    connectionRow(connection)
                                        .calmCard(padding: 12)
                                }
                                .buttonStyle(SmoothButtonStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenMargin)
                .padding(.top, DesignSystem.Spacing.md)
            }
            .safeAreaPadding(.bottom, 40)
        }
        .navigationTitle("My Network")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddConnectionSheet(viewModel: viewModel, isPresented: $showAddSheet)
        }
        .refreshable {
            await viewModel.loadAll()
        }
        .task {
            await viewModel.loadAll()
        }
        .alert("", isPresented: $showSmartCardAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(smartCardActionMessage ?? "")
        }
    }

    // MARK: - Subviews

    private func statBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(DesignSystem.Typography.footnote)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .calmCard(padding: 0)
    }

    private func pendingRequestCard(_ request: NetworkConnection) -> some View {
        HStack(spacing: 12) {
            ProfilePictureView(
                profilePictureUrl: request.profilePictureUrl,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                if let interests = request.sharedInterests, !interests.isEmpty {
                    Text(interests.joined(separator: ", "))
                        .font(DesignSystem.Typography.footnote)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    Task { await viewModel.acceptRequest(connectionId: request.connectionId) }
                }) {
                    Text("Accept")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DesignSystem.Colors.violet)
                        .clipShape(Capsule())
                }

                Button(action: {
                    Task { await viewModel.declineRequest(connectionId: request.connectionId) }
                }) {
                    Text("Decline")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DesignSystem.Colors.cardBackground)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5))
                }
            }
        }
        .calmCard(padding: 12)
    }

    private func eventInviteCard(_ invite: EventInvite) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Inviter row
            HStack(spacing: 10) {
                ProfilePictureView(
                    profilePictureUrl: invite.inviterProfilePicture,
                    size: 44
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(invite.displayInviterName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text("invited you to an event")
                        .font(DesignSystem.Typography.footnote)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()
            }

            // Event details card
            VStack(alignment: .leading, spacing: 8) {
                // Event title
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.violet)
                    Text(invite.eventTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Date & time
                if let startTime = invite.eventStartTime {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        Text(formatInviteDateTime(startTime, endTime: invite.eventEndTime))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                }

                // Location
                if let location = invite.eventLocation, !location.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 13))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineLimit(2)
                    }
                }

                // Description
                if let description = invite.eventDescription, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(3)
                        .padding(.top, 2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignSystem.Colors.violet.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(DesignSystem.Colors.violet.opacity(0.12), lineWidth: 0.5)
            )

            // Shared interests
            if let interests = invite.sharedInterests, !interests.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.violet)
                    Text("You both enjoy")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)

                    ForEach(interests.prefix(3), id: \.self) { interest in
                        Text(interest)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.violet)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DesignSystem.Colors.violet.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }

            // Accept / Decline buttons
            HStack(spacing: 10) {
                Button(action: {
                    Task {
                        if let _ = await viewModel.acceptEventInvite(inviteId: invite.id) {
                            if let startTime = invite.eventStartTime,
                               let date = parseInviteDate(startTime) {
                                NavigationManager.shared.navigateToCalendarDate = date
                            } else {
                                // Fallback: navigate to today in calendar
                                NavigationManager.shared.navigateToCalendarDate = Date()
                            }
                        }
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("Accept")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DesignSystem.Colors.violet)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: {
                    Task { await viewModel.declineEventInvite(inviteId: invite.id) }
                }) {
                    Text("Decline")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DesignSystem.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                        )
                }
            }
        }
        .calmCard(padding: 14)
    }

    private func parseInviteDate(_ dateString: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: dateString) { return date }

        // LocalDateTime with fractional seconds (e.g. 2026-03-09T23:32:24.934)
        let fractional = DateFormatter()
        fractional.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let date = fractional.date(from: dateString) { return date }

        let withSeconds = DateFormatter()
        withSeconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = withSeconds.date(from: dateString) { return date }

        let noSeconds = DateFormatter()
        noSeconds.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let date = noSeconds.date(from: dateString) { return date }

        return nil
    }

    private func formatInviteDateTime(_ startTime: String, endTime: String?) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, MMM d 'at' h:mm a"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        // Try parsing ISO format first, then LocalDateTime format
        if let startDate = isoFormatter.date(from: startTime) {
            var result = dateFormatter.string(from: startDate)
            if let end = endTime, let endDate = isoFormatter.date(from: end) {
                result += " – " + timeFormatter.string(from: endDate)
            }
            return result
        }

        // Parse LocalDateTime with fractional seconds (e.g. 2026-03-09T23:32:24.934)
        let fractionalFormatter = DateFormatter()
        fractionalFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let startDate = fractionalFormatter.date(from: startTime) {
            var result = dateFormatter.string(from: startDate)
            if let end = endTime, let endDate = fractionalFormatter.date(from: end) {
                result += " – " + timeFormatter.string(from: endDate)
            }
            return result
        }

        // Parse LocalDateTime format (yyyy-MM-ddTHH:mm:ss)
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let startDate = localFormatter.date(from: startTime) {
            var result = dateFormatter.string(from: startDate)
            if let end = endTime, let endDate = localFormatter.date(from: end) {
                result += " – " + timeFormatter.string(from: endDate)
            }
            return result
        }

        // Parse LocalDateTime without seconds (yyyy-MM-ddTHH:mm)
        let noSecondsFormatter = DateFormatter()
        noSecondsFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let startDate = noSecondsFormatter.date(from: startTime) {
            var result = dateFormatter.string(from: startDate)
            if let end = endTime, let endDate = noSecondsFormatter.date(from: end) {
                result += " – " + timeFormatter.string(from: endDate)
            }
            return result
        }

        return startTime
    }

    private func suggestionCard(_ suggestion: NetworkSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: suggestion.isEventShare ? "person.badge.plus" : "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(suggestion.isEventShare ? DesignSystem.Colors.emerald : DesignSystem.Colors.violet)
                Text(suggestion.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            if let body = suggestion.body {
                Text(body)
                    .font(DesignSystem.Typography.footnote)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            if let interests = suggestion.sharedInterests, !interests.isEmpty {
                HStack(spacing: 6) {
                    ForEach(interests, id: \.self) { interest in
                        Text(interest)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.violet)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DesignSystem.Colors.violet.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }

            HStack(spacing: 8) {
                Button(action: {
                    Task { await viewModel.acceptSuggestion(id: suggestion.id) }
                }) {
                    Text(suggestion.isEventShare ? "Send Invite" : "Schedule")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(suggestion.isEventShare ? DesignSystem.Colors.emerald : DesignSystem.Colors.violet)
                        .clipShape(Capsule())
                }

                Button(action: {
                    Task { await viewModel.dismissSuggestion(id: suggestion.id) }
                }) {
                    Text("Dismiss")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()
            }
        }
        .calmCard(padding: 14)
    }

    private func connectionRow(_ connection: NetworkConnection) -> some View {
        HStack(spacing: 12) {
            ProfilePictureView(
                profilePictureUrl: connection.profilePictureUrl,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(connection.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                if let interests = connection.sharedInterests, !interests.isEmpty {
                    Text(interests.prefix(3).joined(separator: ", "))
                        .font(DesignSystem.Typography.footnote)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .padding(.vertical, 4)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.footnote)
            .foregroundColor(DesignSystem.Colors.tertiaryText)
            .padding(.leading, DesignSystem.Spacing.xs)
    }
}

// MARK: - Add Connection Sheet

struct AddConnectionSheet: View {
    @ObservedObject var viewModel: NetworkViewModel
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var isSending = false

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(DesignSystem.Colors.violet)

                        Text("Add by Email")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text("Enter their email to connect. If they're on AllTime, they'll get a request. If not, they'll see it when they join.")
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 12) {
                        TextField("Email address", text: $email)
                            .textFieldStyle(.plain)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(14)
                            .background(DesignSystem.Colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                            )

                        Button(action: {
                            isSending = true
                            Task {
                                await viewModel.sendRequest(email: email.trimmingCharacters(in: .whitespaces))
                                isSending = false
                                if viewModel.errorMessage == nil {
                                    isPresented = false
                                }
                            }
                        }) {
                            HStack {
                                if isSending {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                }
                                Text("Send Request")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(email.isEmpty ? DesignSystem.Colors.violet.opacity(0.4) : DesignSystem.Colors.violet)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(email.isEmpty || isSending)
                    }
                    .padding(.horizontal, 20)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(DesignSystem.Colors.errorRed)
                            .padding(.horizontal, 20)
                    }

                    if let success = viewModel.successMessage {
                        Text(success)
                            .font(DesignSystem.Typography.footnote)
                            .foregroundColor(DesignSystem.Colors.emerald)
                            .padding(.horizontal, 20)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Add Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}
