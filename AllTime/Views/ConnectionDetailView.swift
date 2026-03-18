//
//  ConnectionDetailView.swift
//  AllTime
//
//  Detail view for a network connection — shows profile, shared interests, availability
//

import SwiftUI

struct ConnectionDetailView: View {
    let connection: NetworkConnection
    @StateObject private var viewModel = NetworkViewModel()
    @State private var selectedDate = Date()
    @State private var showRemoveConfirmation = false
    @State private var showScheduleSheet = false
    @State private var smartCardMessage: String?
    @State private var showSmartCardAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    // MARK: - Profile Header
                    profileHeader

                    // MARK: - Shared Interests
                    sharedInterestsSection

                    // MARK: - Opportunities (Smart Cards) — max 1 per connection now
                    if !viewModel.connectionSmartCards.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("Opportunities")

                            ForEach(viewModel.connectionSmartCards.prefix(1)) { card in
                                SmartSocialCardView(
                                    card: card,
                                    onAction: {
                                        if card.actionType == "view_events" {
                                            // Open Share Events sheet to let user pick an event
                                            showScheduleSheet = true
                                        } else {
                                            Task {
                                                let result = await viewModel.executeSmartCardAction(card)
                                                smartCardMessage = result.message
                                                showSmartCardAlert = true
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }

                    // MARK: - Availability
                    availabilitySection

                    // MARK: - Share Events Button
                    if connection.userId != nil {
                        Button { showScheduleSheet = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane.fill")
                                Text("Share Events with \(connection.displayName)")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DesignSystem.Colors.violet)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .sheet(isPresented: $showScheduleSheet) {
                            ScheduleWithConnectionSheet(
                                connection: connection,
                                mutualFreeSlots: filterPastSlots(viewModel.freeTime?.mutualFreeSlots ?? [])
                            )
                        }
                    }

                    // MARK: - Remove Connection
                    Button(action: { showRemoveConfirmation = true }) {
                        HStack {
                            Image(systemName: "person.badge.minus")
                            Text("Remove Connection")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenMargin)
                .padding(.top, DesignSystem.Spacing.md)
            }
            .safeAreaPadding(.bottom, 40)
        }
        .navigationTitle(connection.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedDate) { newDate in
            if let userId = connection.userId {
                Task { await viewModel.loadFreeTime(connectionUserId: userId, date: newDate) }
            }
        }
        .task {
            if let userId = connection.userId {
                async let freeTimeTask: () = viewModel.loadFreeTime(connectionUserId: userId, date: selectedDate)
                async let smartCardsTask: () = viewModel.loadSmartCardsForConnection(connectionUserId: userId)
                _ = await (freeTimeTask, smartCardsTask)
            }
        }
        .alert("", isPresented: $showSmartCardAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(smartCardMessage ?? "")
        }
        .alert("Remove Connection?", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task {
                    await viewModel.removeConnection(connectionId: connection.connectionId)
                    dismiss()
                }
            }
        } message: {
            Text("You will no longer see each other's availability or get meetup suggestions.")
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 10) {
            ProfilePictureView(
                profilePictureUrl: connection.profilePictureUrl,
                size: 64
            )

            Text(connection.displayName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            if let email = connection.email {
                Text(email)
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            if let since = connection.connectedSince {
                Text("Connected since \(formatDate(since))")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .calmCard(padding: 14)
    }

    // MARK: - Shared Interests

    private var sharedInterestsSection: some View {
        Group {
            if let interests = connection.sharedInterests, !interests.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("\(interests.count) Shared Interests")

                    FlowLayout(spacing: 6) {
                        ForEach(interests, id: \.self) { interest in
                            Text(interest)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.violet)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(DesignSystem.Colors.violet.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }


    // MARK: - Availability

    private var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("Availability")
                Spacer()
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }

            if viewModel.isLoadingFreeTime {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .padding(.vertical, 20)
                    .calmCard(padding: 12)
            } else if let freeTime = viewModel.freeTime {
                let filteredMutual = filterPastSlots(freeTime.mutualFreeSlots)
                let filteredFree = filterPastSlots(freeTime.freeSlots)
                let filteredBusy = filterPastBusyBlocks(freeTime.busyBlocks ?? [])

                if filteredMutual.isEmpty && filteredFree.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 20))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Text("No shared free time on this day")
                            .font(.system(size: 13))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .calmCard(padding: 12)
                } else {
                    VStack(spacing: 0) {
                        if !filteredMutual.isEmpty {
                            slotSectionHeader("Mutual Free Time")
                            ForEach(filteredMutual) { slot in
                                freeSlotRow(slot, isMutual: true)
                            }
                        }

                        if !filteredBusy.isEmpty {
                            slotSectionHeader("Busy")
                            ForEach(filteredBusy) { block in
                                busyBlockRow(block)
                            }
                        }

                        if !filteredFree.isEmpty {
                            slotSectionHeader("\(connection.displayName)'s Free Time")
                            ForEach(filteredFree.prefix(5)) { slot in
                                freeSlotRow(slot, isMutual: false)
                            }
                        }
                    }
                    .calmCard(padding: 12)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    Text("Select a date to see availability")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .calmCard(padding: 12)
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(DesignSystem.Colors.tertiaryText)
            .textCase(.uppercase)
            .padding(.leading, DesignSystem.Spacing.xs)
    }

    private func slotSectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(DesignSystem.Colors.tertiaryText)
            .textCase(.uppercase)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func busyBlockRow(_ block: BusyBlock) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(DesignSystem.Colors.errorRed.opacity(0.6))
                .frame(width: 6, height: 6)
            Text("\(block.startTime) - \(block.endTime)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Spacer()
            Text("\(block.durationMinutes) min")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .padding(.vertical, 4)
    }

    private func freeSlotRow(_ slot: FreeSlot, isMutual: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isMutual ? DesignSystem.Colors.emerald : DesignSystem.Colors.blue.opacity(0.6))
                .frame(width: 6, height: 6)
            Text("\(slot.startTime) - \(slot.endTime)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
            Spacer()
            Text("\(slot.durationMinutes) min")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .padding(.vertical, 4)
    }

    private func filterPastSlots(_ slots: [FreeSlot]) -> [FreeSlot] {
        guard Calendar.current.isDateInToday(selectedDate) else { return slots }
        let now = Date()
        let calendar = Calendar.current
        let currentTotalMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        return slots.filter { slot in
            let parts = slot.endTime.split(separator: ":")
            guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return true }
            return h * 60 + m > currentTotalMinutes
        }
    }

    private func filterPastBusyBlocks(_ blocks: [BusyBlock]) -> [BusyBlock] {
        guard Calendar.current.isDateInToday(selectedDate) else { return blocks }
        let now = Date()
        let calendar = Calendar.current
        let currentTotalMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        return blocks.filter { block in
            let parts = block.endTime.split(separator: ":")
            guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return true }
            return h * 60 + m > currentTotalMinutes
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            return display.string(from: date)
        }
        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = simple.date(from: dateString) {
            let display = DateFormatter()
            display.dateStyle = .medium
            return display.string(from: date)
        }
        return dateString.prefix(10).description
    }
}

// FlowLayout is defined in InterestsSetupView.swift and shared across the app
