import SwiftUI

struct InviteConnectionsSheet: View {
    let eventId: Int64
    let eventTitle: String
    @Environment(\.dismiss) private var dismiss
    @State private var suggestedMatches: [EventInterestMatch] = []
    @State private var allConnections: [NetworkConnection] = []
    @State private var selectedUserIds: Set<Int64> = []
    @State private var isLoading = true
    @State private var isSending = false
    @State private var resultMessage: String?
    @State private var showResult = false

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {

                            // MARK: - Suggested Matches
                            if !suggestedMatches.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Suggested")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                                        .textCase(.uppercase)
                                        .padding(.leading, DesignSystem.Spacing.xs)

                                    ForEach(suggestedMatches) { match in
                                        matchRow(match)
                                    }
                                }
                            }

                            // MARK: - All Connections
                            let remainingConnections = allConnections.filter { conn in
                                guard let uid = conn.userId else { return true }
                                return !suggestedMatches.contains(where: { $0.userId == uid })
                            }

                            if !remainingConnections.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("All Connections")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                                        .textCase(.uppercase)
                                        .padding(.leading, DesignSystem.Spacing.xs)

                                    ForEach(remainingConnections) { conn in
                                        connectionRow(conn)
                                    }
                                }
                            }

                            if suggestedMatches.isEmpty && allConnections.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "person.2.slash")
                                        .font(.system(size: 32))
                                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    Text("No connections to invite")
                                        .font(DesignSystem.Typography.footnote)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.screenMargin)
                        .padding(.top, DesignSystem.Spacing.md)
                    }
                    .safeAreaInset(edge: .bottom) {
                        if !selectedUserIds.isEmpty {
                            Button(action: { Task { await sendInvites() } }) {
                                HStack {
                                    if isSending {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                        Text("Send Invites (\(selectedUserIds.count))")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(DesignSystem.Colors.violet)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(isSending)
                            .padding(.horizontal, DesignSystem.Spacing.screenMargin)
                            .padding(.bottom, 8)
                            .background(DesignSystem.Colors.background)
                        }
                    }
                }
            }
            .navigationTitle("Invite Connections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            .alert("Invite Sent", isPresented: $showResult) {
                Button("Done") { dismiss() }
            } message: {
                Text(resultMessage ?? "Invitations sent successfully")
            }
            .task { await loadData() }
        }
    }

    // MARK: - Row Views

    private func matchRow(_ match: EventInterestMatch) -> some View {
        Button(action: { toggleSelection(userId: match.userId) }) {
            HStack(spacing: 12) {
                ProfilePictureView(
                    profilePictureUrl: match.profilePictureUrl,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(match.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    HStack(spacing: 6) {
                        if !match.matchingInterests.isEmpty {
                            Text(match.matchingInterests.prefix(2).joined(separator: ", "))
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.violet)
                        }

                        if match.isFreeAtEventTime {
                            Text("Free")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.emerald)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.emerald.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                Image(systemName: selectedUserIds.contains(match.userId) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selectedUserIds.contains(match.userId) ?
                                    DesignSystem.Colors.violet : DesignSystem.Colors.tertiaryText)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .calmCard(padding: 0)
    }

    private func connectionRow(_ connection: NetworkConnection) -> some View {
        guard let userId = connection.userId else { return AnyView(EmptyView()) }

        return AnyView(
            Button(action: { toggleSelection(userId: userId) }) {
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
                            Text(interests.prefix(2).joined(separator: ", "))
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }

                    Spacer()

                    Image(systemName: selectedUserIds.contains(userId) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(selectedUserIds.contains(userId) ?
                                        DesignSystem.Colors.violet : DesignSystem.Colors.tertiaryText)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
            .calmCard(padding: 0)
        )
    }

    // MARK: - Actions

    private func toggleSelection(userId: Int64) {
        if selectedUserIds.contains(userId) {
            selectedUserIds.remove(userId)
        } else {
            selectedUserIds.insert(userId)
        }
    }

    private func loadData() async {
        do {
            async let matchesTask = APIService.shared.getMatchingConnectionsForEvent(eventId: eventId)
            async let connectionsTask = APIService.shared.getNetworkConnections()

            let (matches, connections) = try await (matchesTask, connectionsTask)
            suggestedMatches = matches
            allConnections = connections.filter { $0.status == "accepted" }
        } catch {
            print("Failed to load invite data: \(error)")
        }
        isLoading = false
    }

    private func sendInvites() async {
        isSending = true
        do {
            let response = try await APIService.shared.inviteConnectionsToEvent(
                eventId: eventId,
                connectionUserIds: Array(selectedUserIds)
            )
            resultMessage = response.message
            showResult = true
        } catch {
            resultMessage = "Failed to send invites: \(error.localizedDescription)"
            showResult = true
        }
        isSending = false
    }
}
