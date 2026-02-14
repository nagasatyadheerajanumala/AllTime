//
//  SettingsView.swift
//  AllTime
//
//  Redesigned with Apple's design principles
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
                
                List {
                // Profile Section - Apple-style header
                Section {
                    NavigationLink(destination: ProfileDetailView()
                        .environmentObject(authService)
                        .environmentObject(settingsViewModel)) {
                        HStack(spacing: 16) {
                            // Profile Picture - Larger, more prominent
                            ProfilePictureView(
                                profilePictureUrl: currentUser?.profilePictureUrl,
                                size: 60
                            )
                            
                            VStack(alignment: .leading, spacing: 6) {
                                // Name or Email
                                if let fullName = currentUser?.fullName, !fullName.isEmpty {
                                    Text(fullName)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.primary)
                                } else if let email = currentUser?.email, !email.isEmpty {
                                    Text(email)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.primary)
                                } else if settingsViewModel.isLoading {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Loading...")
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("Clara User")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(.secondary)
                                }
                                
                                // Email (if name exists)
                                if currentUser?.fullName != nil,
                                   let email = currentUser?.email,
                                   !email.isEmpty {
                                    Text(email)
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            // Note: NavigationLink automatically adds chevron
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                } header: {
                    Text("PROFILE")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                
                // Connected Providers Section
                Section {
                    NavigationLink(destination: ConnectedCalendarsView()) {
                        SettingsRow(
                            icon: "calendar.badge.clock",
                            iconColor: DesignSystem.Colors.blue, // Blue
                            title: "My Calendars",
                            badge: settingsViewModel.connectedProvidersCount
                        )
                    }
                } header: {
                    Text("CONNECTED PROVIDERS")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                } footer: {
                    Text("Manage your connected calendar accounts and sync settings")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                // Personalization Section
                Section {
                    NavigationLink(destination: InterestsSetupView()) {
                        SettingsRow(
                            icon: "sparkles",
                            iconColor: Color(hex: "EC4899"), // Pink
                            title: "My Interests"
                        )
                    }

                } header: {
                    Text("PERSONALIZATION")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                } footer: {
                    Text("Set your interests to get personalized weekend and vacation suggestions")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                // App Settings Section
                Section {
                    // Theme Toggle
                    ThemeToggleView()

                    NavigationLink(destination: NotificationSettingsView()) {
                        SettingsRow(
                            icon: "bell.badge.fill",
                            iconColor: DesignSystem.Colors.amber, // Amber
                            title: "Notifications"
                        )
                    }

                    NavigationLink(destination: PrivacySettingsView()) {
                        SettingsRow(
                            icon: "lock.shield.fill",
                            iconColor: DesignSystem.Colors.emerald, // Green
                            title: "Privacy & Security"
                        )
                    }

                    NavigationLink(destination: AboutView()) {
                        SettingsRow(
                            icon: "info.circle.fill",
                            iconColor: DesignSystem.Colors.violet, // Purple
                            title: "About Clara"
                        )
                    }
                } header: {
                    Text("SETTINGS")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }

                // Data & Storage Section
                Section {
                    Button(action: {
                        deduplicateEvents()
                    }) {
                        HStack(spacing: 12) {
                            // Icon with background
                            ZStack {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color.orange.opacity(0.1))
                                    .frame(width: 30, height: 30)

                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.orange)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Remove Duplicate Events")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.primary)

                                Text("Clean up events synced from multiple sources")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if isDeduplicating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(isDeduplicating)
                } header: {
                    Text("DATA & STORAGE")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                } footer: {
                    Text("Remove duplicate calendar events that may appear when syncing from multiple sources (Google, Microsoft, Apple)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                // Account Section
                Section {
                    Button(action: {
                        authService.signOut()
                    }) {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }

                    Button(role: .destructive, action: {
                        showDeleteAccountConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            if isDeletingAccount {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 8)
                            }
                            Text("Delete Account")
                                .font(.system(size: 17, weight: .regular))
                            Spacer()
                        }
                    }
                    .disabled(isDeletingAccount)
                } footer: {
                    Text("Deleting your account will permanently remove all your data, including calendar events, health data, and preferences.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                }
                .safeAreaPadding(.bottom, 110) // Reserve space for tab bar
                .contentMargins(.top, 0, for: .scrollContent)
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
                                    .stroke(Color(.systemGray5), lineWidth: 0.5)
                            )
                    case .failure:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: size))
                            .foregroundColor(.blue)
                    @unknown default:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: size))
                            .foregroundColor(.blue)
                    }
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(.blue)
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var badge: Int? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with background
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 30, height: 30)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.primary)
            
            Spacer()
            
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
            
            // Note: NavigationLink automatically adds chevron, so we don't add one here
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Theme Toggle View
struct ThemeToggleView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with background
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 30, height: 30)
                
                Image(systemName: "paintbrush.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            Text("Appearance")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.primary)
            
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
            .tint(.blue)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsViewModel())
        .environmentObject(AuthenticationService())
}
