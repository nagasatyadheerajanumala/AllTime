//
//  ProfileView.swift
//  AllTime
//
//  LinkedIn-style professional profile tab
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var navigationManager = NavigationManager.shared
    @Environment(\.colorScheme) var colorScheme

    // Dedup state
    @State private var isDeduplicating = false
    @State private var deduplicationResult: String?
    @State private var showDeduplicationAlert = false

    // Delete account state
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    // Quick stats
    @State private var networkConnectionCount: Int = 0
    @State private var interestsCount: Int = 0

    private let apiService = APIService()

    private var currentUser: User? {
        authService.currentUser ?? settingsViewModel.user
    }

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // MARK: - Profile Hero (Banner + Photo + Info)
                        profileHeroSection

                        // MARK: - Content below hero
                        LazyVStack(spacing: 16) {

                            // Quick Stats
                            quickStatsRow
                                .padding(.top, 16)

                            // Sections
                            profileSectionsGroup

                            // Settings
                            settingsGroup

                            // Account
                            accountGroup

                            // Footer
                            footerSection
                        }
                        .padding(.horizontal, DesignSystem.Spacing.screenMargin)
                    }
                }
                .safeAreaPadding(.bottom, 110)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Profile")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                }
                .refreshable {
                    await settingsViewModel.refreshProviders()
                    if let user = authService.currentUser {
                        settingsViewModel.user = user
                    }
                    await loadQuickStats()
                }
                .onAppear {
                    if let user = authService.currentUser {
                        settingsViewModel.user = user
                    } else if settingsViewModel.user == nil {
                        Task { await settingsViewModel.loadUserProfile() }
                    }
                }
                .task {
                    await loadQuickStats()
                }
                .alert("Deduplication Complete", isPresented: $showDeduplicationAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(deduplicationResult ?? "")
                }
                .alert("Delete Account?", isPresented: $showDeleteAccountConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) { deleteAccount() }
                } message: {
                    Text("This will permanently delete your account and all associated data. This action cannot be undone.")
                }
                .alert("Error", isPresented: $showDeleteError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(deleteErrorMessage)
                }
                // Hidden NavigationLink for deep-link to Network
                .background(
                    NavigationLink(
                        destination: NetworkView(),
                        isActive: $navigationManager.showNetwork
                    ) { EmptyView() }
                )
            }
        }
    }

    // MARK: - Profile Hero Section

    private var profileHeroSection: some View {
        ZStack(alignment: .bottom) {
            // Banner gradient
            VStack(spacing: 0) {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(hex: "1E1B4B"), Color(hex: "312E81"), Color(hex: "1E1B4B")]
                        : [Color(hex: "6366F1"), Color(hex: "8B5CF6"), Color(hex: "A78BFA")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 130)
                .overlay(
                    // Subtle pattern overlay
                    LinearGradient(
                        colors: [.white.opacity(0.1), .clear, .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                // Space for the card that overlaps the banner
                Color.clear.frame(height: 0)
            }

            // Profile card overlapping the banner
            VStack(spacing: 0) {
                // Profile photo — overlaps the banner
                profilePhotoView
                    .offset(y: -50)
                    .padding(.bottom, -50)

                // Name, email, location, bio
                VStack(spacing: 8) {
                    // Name
                    if let fullName = currentUser?.fullName, !fullName.isEmpty {
                        Text(fullName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    } else if settingsViewModel.isLoading {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.8)
                            Text("Loading...")
                                .font(.system(size: 17))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    } else {
                        Text("AllTime User")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    // Bio
                    if let bio = currentUser?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 15))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 20)
                    }

                    // Email + Location row
                    HStack(spacing: 16) {
                        if let email = currentUser?.email, !email.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 11))
                                Text(email)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                            }
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }

                        if let location = currentUser?.location, !location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 11))
                                Text(location)
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                    }

                    // Edit Profile button
                    NavigationLink(destination: ProfileDetailView()
                        .environmentObject(authService)
                        .environmentObject(settingsViewModel)) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Edit Profile")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(DesignSystem.Colors.violet)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.violet.opacity(0.1))
                        )
                        .overlay(
                            Capsule()
                                .stroke(DesignSystem.Colors.violet.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(SmoothButtonStyle())
                    .padding(.top, 4)
                }
                .padding(.top, 14)
                .padding(.bottom, 20)
                .padding(.horizontal, DesignSystem.Spacing.screenMargin)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DesignSystem.Colors.cardBackground)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 12, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
            )
            .padding(.horizontal, DesignSystem.Spacing.screenMargin)
            .offset(y: 30)
        }
        .padding(.bottom, 30)
    }

    // MARK: - Profile Photo

    private var profilePhotoView: some View {
        ZStack {
            // White ring behind photo
            Circle()
                .fill(DesignSystem.Colors.cardBackground)
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)

            ProfilePictureView(
                profilePictureUrl: currentUser?.profilePictureUrl,
                size: 104
            )
        }
    }

    // MARK: - Quick Stats Row

    private var quickStatsRow: some View {
        HStack(spacing: 0) {
            NavigationLink(destination: NetworkView()) {
                statCell(count: networkConnectionCount, label: "Connections", color: DesignSystem.Colors.violet)
            }
            .buttonStyle(PlainButtonStyle())

            statDivider

            NavigationLink(destination: ConnectedCalendarsView()) {
                statCell(count: settingsViewModel.connectedProvidersCount ?? 0, label: "Calendars", color: DesignSystem.Colors.blue)
            }
            .buttonStyle(PlainButtonStyle())

            statDivider

            NavigationLink(destination: InterestsSetupView()) {
                statCell(count: interestsCount, label: "Interests", color: Color(hex: "EC4899"))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
        )
    }

    private func statCell(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(DesignSystem.Colors.calmBorder)
            .frame(width: 0.5, height: 32)
    }

    // MARK: - Profile Sections (Network, Calendars, Interests)

    private var profileSectionsGroup: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionHeader("My Workspace", icon: "square.grid.2x2.fill")

            VStack(spacing: 0) {
                NavigationLink(destination: NetworkView()) {
                    SettingsRow(
                        icon: "person.2.fill",
                        iconColor: DesignSystem.Colors.violet,
                        title: "My Network",
                        subtitle: networkConnectionCount > 0 ? "\(networkConnectionCount) connections" : nil
                    )
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(PlainButtonStyle())

                Divider().padding(.leading, 50)

                NavigationLink(destination: ConnectedCalendarsView()) {
                    SettingsRow(
                        icon: "calendar.badge.clock",
                        iconColor: DesignSystem.Colors.blue,
                        title: "My Calendars",
                        badge: settingsViewModel.connectedProvidersCount
                    )
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(PlainButtonStyle())

                Divider().padding(.leading, 50)

                NavigationLink(destination: InterestsSetupView()) {
                    SettingsRow(
                        icon: "sparkles",
                        iconColor: Color(hex: "EC4899"),
                        title: "My Interests",
                        subtitle: interestsCount > 0 ? "\(interestsCount) selected" : "Set up your interests"
                    )
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .groupedCard()
        }
    }

    // MARK: - Settings Group

    private var settingsGroup: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionHeader("Settings", icon: "gearshape.fill")

            VStack(spacing: 0) {
                ThemeToggleView()
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)

                Divider().padding(.leading, 50)

                NavigationLink(destination: NotificationSettingsView()) {
                    SettingsRow(
                        icon: "bell.badge.fill",
                        iconColor: DesignSystem.Colors.amber,
                        title: "Notifications"
                    )
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(PlainButtonStyle())

                Divider().padding(.leading, 50)

                NavigationLink(destination: PrivacySettingsView()) {
                    SettingsRow(
                        icon: "lock.shield.fill",
                        iconColor: DesignSystem.Colors.emerald,
                        title: "Privacy & Security"
                    )
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(PlainButtonStyle())

                Divider().padding(.leading, 50)

                Button(action: { deduplicateEvents() }) {
                    SettingsRow(
                        icon: "doc.on.doc.fill",
                        iconColor: .orange,
                        title: "Remove Duplicate Events",
                        showChevron: false,
                        isLoading: isDeduplicating
                    )
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isDeduplicating)

                Divider().padding(.leading, 50)

                NavigationLink(destination: AboutView()) {
                    SettingsRow(
                        icon: "info.circle.fill",
                        iconColor: DesignSystem.Colors.violet,
                        title: "About Clara"
                    )
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .groupedCard()
        }
    }

    // MARK: - Account Group

    private var accountGroup: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            sectionHeader("Account", icon: "person.badge.key.fill")

            VStack(spacing: 0) {
                Button(action: { authService.signOut() }) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                .fill(DesignSystem.Colors.errorRed.opacity(0.12))
                                .frame(width: 34, height: 34)
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: DesignSystem.Components.iconLarge, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.errorRed)
                        }
                        Text("Sign Out")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.errorRed)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(PlainButtonStyle())

                Divider().padding(.leading, 50)

                Button(action: { showDeleteAccountConfirmation = true }) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                .fill(DesignSystem.Colors.errorRed.opacity(0.12))
                                .frame(width: 34, height: 34)
                            Image(systemName: "trash.fill")
                                .font(.system(size: DesignSystem.Components.iconLarge, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.errorRed)
                        }
                        Text("Delete Account")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.errorRed)
                        Spacer()
                        if isDeletingAccount {
                            ProgressView().scaleEffect(0.8)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isDeletingAccount)
            }
            .groupedCard()
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 4) {
            if let createdAt = currentUser?.createdAt {
                Text("Member since \(formattedMemberDate(createdAt))")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            Text("Version \(appVersion)")
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Section Header Helper

    private func sectionHeader(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            Text(text.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .tracking(0.8)
        }
        .padding(.leading, DesignSystem.Spacing.xs)
    }

    // MARK: - Load Quick Stats

    private func loadQuickStats() async {
        do {
            let stats = try await apiService.getNetworkStats()
            await MainActor.run {
                networkConnectionCount = stats.connectionCount
            }
        } catch {
            print("📊 ProfileView: Failed to load network stats: \(error)")
        }

        // Load interests using plain decoder (UserInterests has explicit CodingKeys,
        // so convertFromSnakeCase in APIService.getUserInterests() causes double-conversion)
        do {
            guard let token = KeychainManager.shared.getAccessToken(),
                  let url = URL(string: "\(Constants.API.baseURL)/api/v1/interests") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: request)
            let interests = try JSONDecoder().decode(UserInterests.self, from: data)
            let total = interests.activityInterests.count
                + interests.lifestyleInterests.count
                + interests.socialInterests.count
            await MainActor.run {
                interestsCount = total
            }
        } catch {
            print("📊 ProfileView: Failed to load interests: \(error)")
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func formattedMemberDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.dateFormat = "MMMM yyyy"
            return display.string(from: date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let display = DateFormatter()
            display.dateFormat = "MMMM yyyy"
            return display.string(from: date)
        }
        return dateString
    }

    // MARK: - Account Deletion

    private func deleteAccount() {
        isDeletingAccount = true
        Task {
            do {
                try await apiService.deleteAccount()
                await MainActor.run {
                    authService.signOut(reason: "Account deleted")
                }
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    deleteErrorMessage = "Failed to delete account. Please try again."
                    showDeleteError = true
                }
            }
        }
    }

    // MARK: - Deduplication

    private func deduplicateEvents() {
        isDeduplicating = true
        deduplicationResult = nil

        Task {
            do {
                let response = try await apiService.deduplicateEvents()
                await MainActor.run {
                    isDeduplicating = false
                    if response.duplicatesRemoved > 0 {
                        deduplicationResult = "Removed \(response.duplicatesRemoved) duplicate events from your calendar."
                    } else {
                        deduplicationResult = "No duplicate events found. Your calendar is clean!"
                    }
                    showDeduplicationAlert = true
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshCalendarEvents"), object: nil)
                }
            } catch {
                await MainActor.run {
                    isDeduplicating = false
                    deduplicationResult = "Failed to remove duplicates: \(error.localizedDescription)"
                    showDeduplicationAlert = true
                }
            }
        }
    }
}

// MARK: - Grouped Card Modifier

private extension View {
    func groupedCard() -> some View {
        self
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
            )
    }
}

#Preview {
    ProfileView()
        .environmentObject(SettingsViewModel())
        .environmentObject(AuthenticationService())
        .environmentObject(ThemeManager())
}
