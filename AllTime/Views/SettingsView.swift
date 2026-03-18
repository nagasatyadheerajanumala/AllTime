//
//  SettingsView.swift
//  AllTime
//
//  Redesigned with premium calm card design system
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingProviderLink = false
    @State private var selectedProvider = ""
    @State private var isDeduplicating = false
    @State private var deduplicationResult: String?
    @State private var showDeduplicationAlert = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    private let apiService = APIService()

    // Computed property to get user - prioritize authService, fallback to settingsViewModel
    private var currentUser: User? {
        authService.currentUser ?? settingsViewModel.user
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 20) {

                        // MARK: - Profile Section (index 0)
                        NavigationLink(destination: ProfileDetailView()
                            .environmentObject(authService)
                            .environmentObject(settingsViewModel)) {
                            HStack(spacing: 14) {
                                // Profile Picture
                                ProfilePictureView(
                                    profilePictureUrl: currentUser?.profilePictureUrl,
                                    size: 56
                                )

                                VStack(alignment: .leading, spacing: 6) {
                                    // Name or Email
                                    if let fullName = currentUser?.fullName, !fullName.isEmpty {
                                        Text(fullName)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                    } else if let email = currentUser?.email, !email.isEmpty {
                                        Text(email)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                            .lineLimit(1)
                                    } else if settingsViewModel.isLoading {
                                        HStack(spacing: 6) {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text("Loading...")
                                                .font(.system(size: 17, weight: .regular))
                                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                        }
                                    } else {
                                        Text("Clara User")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                    }

                                    // Email (if name exists)
                                    if currentUser?.fullName != nil,
                                       let email = currentUser?.email,
                                       !email.isEmpty {
                                        Text(email)
                                            .font(.system(size: 15, weight: .regular))
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                            .lineLimit(1)
                                    }

                                    Text("View profile")
                                        .font(DesignSystem.Typography.footnote)
                                        .foregroundColor(DesignSystem.Colors.primary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                            }
                            .padding(.vertical, 6)
                            .calmCard(padding: 14)
                        }
                        .buttonStyle(SmoothButtonStyle())
                        .cardStagger(index: 0)

                        // MARK: - Calendars Section (index 1)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            sectionLabel("Calendars")

                            NavigationLink(destination: ConnectedCalendarsView()) {
                                SettingsRow(
                                    icon: "calendar.badge.clock",
                                    iconColor: DesignSystem.Colors.blue,
                                    title: "My Calendars",
                                    badge: settingsViewModel.connectedProvidersCount
                                )
                                .calmCard(padding: 12)
                            }
                            .buttonStyle(SmoothButtonStyle())
                        }
                        .cardStagger(index: 1)

                        // MARK: - Personalization Section (index 2)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            sectionLabel("Personalization")

                            NavigationLink(destination: InterestsSetupView()) {
                                SettingsRow(
                                    icon: "sparkles",
                                    iconColor: Color(hex: "EC4899"),
                                    title: "My Interests"
                                )
                                .calmCard(padding: 12)
                            }
                            .buttonStyle(SmoothButtonStyle())

                            sectionFooter("Set your interests to get personalized weekend and vacation suggestions")
                        }
                        .cardStagger(index: 2)

                        // MARK: - My Network Section (index 3)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            sectionLabel("My Network")

                            NavigationLink(destination: NetworkView()) {
                                SettingsRow(
                                    icon: "person.2.fill",
                                    iconColor: DesignSystem.Colors.violet,
                                    title: "My Network"
                                )
                                .calmCard(padding: 12)
                            }
                            .buttonStyle(SmoothButtonStyle())

                            sectionFooter("Connect with people you meet with regularly")
                        }
                        .cardStagger(index: 3)

                        // MARK: - App Settings Section (index 4)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            sectionLabel("App Settings")

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
                        .cardStagger(index: 4)

                        // MARK: - Data & Storage Section (index 5)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            sectionLabel("Data & Storage")

                            Button(action: {
                                deduplicateEvents()
                            }) {
                                SettingsRow(
                                    icon: "doc.on.doc.fill",
                                    iconColor: .orange,
                                    title: "Remove Duplicate Events",
                                    subtitle: "Clean up events synced from multiple sources",
                                    showChevron: false,
                                    isLoading: isDeduplicating
                                )
                                .calmCard(padding: 12)
                            }
                            .buttonStyle(SmoothButtonStyle())
                            .disabled(isDeduplicating)

                            sectionFooter("Remove duplicate calendar events that may appear when syncing from multiple sources (Google, Microsoft, Apple)")
                        }
                        .cardStagger(index: 5)

                        // MARK: - Account Section (index 6)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            sectionLabel("Account")

                            VStack(spacing: 0) {
                                Button(action: {
                                    authService.signOut()
                                }) {
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

                                Button(action: {
                                    showDeleteAccountConfirmation = true
                                }) {
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
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 14)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(isDeletingAccount)
                            }
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

                            sectionFooter("Deleting your account will permanently remove all your data, including calendar events, health data, and preferences.")
                        }
                        .cardStagger(index: 6)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenMargin)
                    .padding(.top, DesignSystem.Spacing.md)
                }
                .safeAreaPadding(.bottom, 110)
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
                .refreshable {
                    await settingsViewModel.refreshProviders()
                    // Also refresh from authService
                    if let user = authService.currentUser {
                        settingsViewModel.user = user
                    }
                }
                .onAppear {
                    // Sync user data from authService to settingsViewModel
                    if let user = authService.currentUser {
                        settingsViewModel.user = user
                    } else if settingsViewModel.user == nil {
                        // Only load if we don't have user data
                        Task {
                            await settingsViewModel.loadUserProfile()
                        }
                    }
                }
                .alert("Deduplication Complete", isPresented: $showDeduplicationAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(deduplicationResult ?? "")
                }
                .alert("Delete Account?", isPresented: $showDeleteAccountConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        deleteAccount()
                    }
                } message: {
                    Text("This will permanently delete your account and all associated data. This action cannot be undone.")
                }
                .alert("Error", isPresented: $showDeleteError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(deleteErrorMessage)
                }
            }
        }
    }

    // MARK: - Section Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.footnote)
            .foregroundColor(DesignSystem.Colors.tertiaryText)
            .padding(.leading, DesignSystem.Spacing.xs)
    }

    private func sectionFooter(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.footnote)
            .foregroundColor(DesignSystem.Colors.tertiaryText)
            .padding(.leading, DesignSystem.Spacing.xs)
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
                let apiService = APIService()
                let response = try await apiService.deduplicateEvents()

                await MainActor.run {
                    isDeduplicating = false
                    if response.duplicatesRemoved > 0 {
                        deduplicationResult = "Removed \(response.duplicatesRemoved) duplicate events from your calendar."
                    } else {
                        deduplicationResult = "No duplicate events found. Your calendar is clean!"
                    }
                    showDeduplicationAlert = true

                    // Post notification to refresh calendar
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

// MARK: - Reusable Components

struct ProfilePictureView: View {
    let profilePictureUrl: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let profilePictureUrl = profilePictureUrl,
               !profilePictureUrl.isEmpty,
               let url = URL(string: profilePictureUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                            )
                    case .failure:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: size))
                            .foregroundColor(DesignSystem.Colors.primary)
                    @unknown default:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: size))
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(DesignSystem.Colors.primary)
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var badge: Int? = nil
    var subtitle: String? = nil
    var showChevron: Bool = true
    var isLoading: Bool = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon with background
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Components.iconLarge, weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.footnote)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }

            // Badge if provided
            if let badge = badge, badge > 0 {
                Text("\(badge)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(iconColor)
                    .clipShape(Capsule())
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Theme Toggle View
struct ThemeToggleView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon with background
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(DesignSystem.Colors.primary.opacity(0.12))
                    .frame(width: 34, height: 34)

                Image(systemName: "paintbrush.fill")
                    .font(.system(size: DesignSystem.Components.iconLarge, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary)
            }

            Text("Appearance")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.primaryText)

            Spacer()

            // Theme Picker
            Picker("Theme", selection: $themeManager.selectedTheme) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    HStack {
                        Image(systemName: theme.icon)
                        Text(theme.displayName)
                    }
                    .tag(theme)
                }
            }
            .pickerStyle(.menu)
            .tint(DesignSystem.Colors.primary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsViewModel())
        .environmentObject(AuthenticationService())
}
