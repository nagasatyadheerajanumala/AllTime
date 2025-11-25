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
    
    // Computed property to get user - prioritize authService, fallback to settingsViewModel
    private var currentUser: User? {
        authService.currentUser ?? settingsViewModel.user
    }
    
    var body: some View {
        NavigationView {
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
                                    Text("AllTime User")
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
                            iconColor: .blue,
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
                
                // App Settings Section
                Section {
                    // Theme Toggle
                    ThemeToggleView()
                    
                    NavigationLink(destination: NotificationSettingsView()) {
                        SettingsRow(
                            icon: "bell.fill",
                            iconColor: .blue,
                            title: "Notifications"
                        )
                    }
                    
                    NavigationLink(destination: PrivacySettingsView()) {
                        SettingsRow(
                            icon: "lock.fill",
                            iconColor: .blue,
                            title: "Privacy & Security"
                        )
                    }
                    
                    NavigationLink(destination: AboutView()) {
                        SettingsRow(
                            icon: "info.circle.fill",
                            iconColor: .blue,
                            title: "About"
                        )
                    }
                } header: {
                    Text("SETTINGS")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                
                // Sign Out Section
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
                }
            }
            .safeAreaPadding(.bottom, 110) // Reserve space for tab bar
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
