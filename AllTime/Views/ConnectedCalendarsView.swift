import SwiftUI

struct ConnectedCalendarsView: View {
    @StateObject private var viewModel = ConnectedCalendarsViewModel()
    @StateObject private var googleAuthManager = GoogleAuthManager.shared
    @State private var showingAddCalendar = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading calendars...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.providers.isEmpty {
                    // Empty State
                    VStack(spacing: 30) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 80))
                            .foregroundColor(.blue.opacity(0.5))
                        
                        VStack(spacing: 12) {
                            Text("No Calendars Connected")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Connect your Google, Microsoft, or Apple calendars to sync all your events in one place")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        Button(action: {
                            showingAddCalendar = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Calendar")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: 280)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                } else {
                    // Calendar List
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header Stats
                            HStack(spacing: 16) {
                                StatCard(
                                    title: "Connected",
                                    value: "\(viewModel.providers.count)",
                                    icon: "link.circle.fill",
                                    color: .blue
                                )
                                
                                StatCard(
                                    title: "Total Events",
                                    value: "\(viewModel.totalEventCount)",
                                    icon: "calendar.badge.clock",
                                    color: .green
                                )
                                
                                StatCard(
                                    title: "Last Sync",
                                    value: viewModel.lastSyncText,
                                    icon: "arrow.clockwise.circle.fill",
                                    color: .orange
                                )
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                            
                            // Connected Calendars
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Connected Calendars")
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        showingAddCalendar = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 14))
                                            Text("Add")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal)
                                
                                ForEach(viewModel.providers) { provider in
                                    ConnectedCalendarCard(
                                        provider: provider,
                                        viewModel: viewModel,
                                        onSync: {
                                            Task {
                                                await viewModel.syncProvider(provider.id)
                                            }
                                        },
                                        onDisconnect: {
                                            Task {
                                                // Use connection ID for multi-account support
                                                await viewModel.disconnectConnection(provider.id)
                                            }
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.top, 20)

                            // Discovered Calendars Section (Multi-Calendar Support)
                            if viewModel.hasMicrosoftConnection || !viewModel.discoveredCalendars.isEmpty {
                                DiscoveredCalendarsSection(viewModel: viewModel)
                                    .padding(.top, 20)
                            }

                            // Sync Settings Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Sync Settings")
                                    .font(.headline)
                                    .padding(.horizontal)

                                VStack(spacing: 0) {
                                    // Holiday Sync Toggle
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Sync Holidays")
                                                .font(.system(size: 17, weight: .regular))

                                            Text("Show public holidays from your calendar")
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        if viewModel.isLoadingHolidayPreference {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Toggle("", isOn: Binding(
                                                get: { viewModel.syncHolidays },
                                                set: { newValue in
                                                    Task {
                                                        await viewModel.updateHolidaySyncPreference(newValue)
                                                    }
                                                }
                                            ))
                                            .labelsHidden()
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            .padding(.top, 20)

                            // Extra padding at bottom to prevent content from being obscured by tab bar
                            Spacer()
                                .frame(height: 120) // Increased padding for tab bar + safe area
                        }
                    }
                    .refreshable {
                        await viewModel.loadProviders()
                    }
                }
            }
            .navigationTitle("My Calendars")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.loadProviders()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .sheet(isPresented: $showingAddCalendar) {
                AddConnectionView()
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .alert("Success", isPresented: Binding(
                get: { viewModel.successMessage != nil },
                set: { if !$0 { viewModel.successMessage = nil } }
            )) {
                Button("OK") {
                    viewModel.successMessage = nil
                }
            } message: {
                if let successMessage = viewModel.successMessage {
                    Text(successMessage)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadProviders()
                await viewModel.loadHolidaySyncPreference()
                await viewModel.loadDiscoveredCalendars()
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
}

struct ConnectedCalendarCard: View {
    let provider: Provider
    let viewModel: ConnectedCalendarsViewModel
    let onSync: () -> Void
    let onDisconnect: () -> Void
    
    @State private var showingDisconnectAlert = false
    @State private var isSyncing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                // Provider Icon
                ZStack {
                    Circle()
                        .fill(providerColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: providerIcon)
                        .font(.system(size: 24))
                        .foregroundColor(providerColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayEmail)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                    
                    Text(provider.provider.capitalized + " Calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(provider.isActive ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(provider.isActive ? "Active" : "Inactive")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(provider.isActive ? .green : .red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(provider.isActive ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .cornerRadius(12)
                
                // Context Menu Button (Safe Disconnect Action)
                Menu {
                    Button(role: .destructive, action: {
                        showingDisconnectAlert = true
                    }) {
                        Label("Disconnect Calendar", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            Divider()
            
            // Stats
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text("\(viewModel.eventCountForToday(provider: provider.provider))")
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Divider()
                    .frame(height: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Synced")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.lastSyncText)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Spacer()
            }
            
            // Primary Action - Sync Now (Safe, Non-Destructive)
            Button(action: {
                isSyncing = true
                onSync()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    isSyncing = false
                }
            }) {
                HStack(spacing: 8) {
                    if isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text("Sync Now")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(isSyncing)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .alert("Disconnect Calendar", isPresented: $showingDisconnectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) {
                onDisconnect()
            }
        } message: {
            Text("Are you sure you want to disconnect this calendar? You won't receive new events from this account, but existing events will remain visible.")
        }
    }
    
    private var providerIcon: String {
        switch provider.provider.lowercased() {
        case "google":
            return "g.circle.fill"
        case "microsoft", "outlook":
            return "m.circle.fill"
        case "apple":
            return "applelogo"
        default:
            return "calendar"
        }
    }
    
    private var providerColor: Color {
        switch provider.provider.lowercased() {
        case "google":
            return .red
        case "microsoft", "outlook":
            return .blue
        case "apple":
            return .gray
        default:
            return .secondary
        }
    }
    
}

// MARK: - Discovered Calendars Section

struct DiscoveredCalendarsSection: View {
    @ObservedObject var viewModel: ConnectedCalendarsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Calendars")
                    .font(.headline)

                Spacer()

                // Discover button for Microsoft
                if viewModel.hasMicrosoftConnection {
                    Button(action: {
                        Task {
                            await viewModel.discoverMicrosoftCalendars()
                        }
                    }) {
                        HStack(spacing: 4) {
                            if viewModel.isDiscovering {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 12))
                            }
                            Text("Discover")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.blue)
                    }
                    .disabled(viewModel.isDiscovering)
                }
            }
            .padding(.horizontal)

            if viewModel.discoveredCalendars.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("No calendars discovered yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if viewModel.hasMicrosoftConnection {
                        Text("Tap \"Discover\" to find all your Microsoft calendars including shared and delegated ones.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                // Group by provider
                ForEach(Array(viewModel.discoveredCalendarsByProvider.keys.sorted()), id: \.self) { provider in
                    if let calendars = viewModel.discoveredCalendarsByProvider[provider] {
                        VStack(alignment: .leading, spacing: 8) {
                            // Provider header
                            HStack(spacing: 8) {
                                Image(systemName: provider.lowercased() == "microsoft" ? "m.circle.fill" : "g.circle.fill")
                                    .foregroundColor(provider.lowercased() == "microsoft" ? .blue : .red)
                                    .font(.system(size: 16))

                                Text("\(provider.capitalized) Calendars")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(calendars.filter { $0.enabled }.count)/\(calendars.count) enabled")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)

                            // Calendar rows
                            VStack(spacing: 0) {
                                ForEach(calendars) { calendar in
                                    DiscoveredCalendarRow(
                                        calendar: calendar,
                                        isToggling: viewModel.isTogglingCalendar == calendar.id,
                                        onToggle: { enabled in
                                            Task {
                                                await viewModel.toggleCalendarEnabled(calendar.id, enabled: enabled)
                                            }
                                        }
                                    )

                                    if calendar.id != calendars.last?.id {
                                        Divider()
                                            .padding(.leading, 52)
                                    }
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }

                // Multi-calendar sync button
                if viewModel.hasMicrosoftConnection && !viewModel.discoveredCalendars.isEmpty {
                    Button(action: {
                        Task {
                            await viewModel.syncMicrosoftMultiCalendar()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isSyncing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            Text("Sync All Enabled Calendars")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.isSyncing)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
    }
}

struct DiscoveredCalendarRow: View {
    let calendar: DiscoveredCalendar
    let isToggling: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Calendar color indicator
            Circle()
                .fill(calendar.colorValue)
                .frame(width: 12, height: 12)
                .padding(.leading, 4)

            // Calendar type icon
            Image(systemName: calendarTypeIcon)
                .font(.system(size: 18))
                .foregroundColor(calendar.isActive ? .primary : .secondary)
                .frame(width: 24)

            // Calendar info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(calendar.name)
                        .font(.system(size: 15, weight: .medium))
                        .lineLimit(1)

                    if calendar.isPrimary {
                        Text("Primary")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }

                    if calendar.isShared {
                        Text("Shared")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                if let ownerEmail = calendar.ownerEmail, calendar.isShared {
                    Text("from \(ownerEmail)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if !calendar.isActive {
                    HStack(spacing: 4) {
                        Image(systemName: calendar.statusIcon)
                            .font(.system(size: 10))
                        Text(statusText)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(calendar.statusColor)
                }
            }

            Spacer()

            // Toggle or loading indicator
            if isToggling {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Toggle("", isOn: Binding(
                    get: { calendar.enabled },
                    set: { onToggle($0) }
                ))
                .labelsHidden()
                .disabled(!calendar.canEdit && !calendar.enabled)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .opacity(calendar.isActive ? 1.0 : 0.7)
    }

    private var calendarTypeIcon: String {
        switch calendar.calendarType {
        case "primary":
            return "calendar"
        case "shared":
            return "person.2"
        case "delegated":
            return "person.badge.key"
        default:
            return "calendar"
        }
    }

    private var statusText: String {
        switch calendar.status {
        case "permission_denied":
            return "Permission denied"
        case "error":
            return "Sync error"
        case "not_found":
            return "Not found"
        default:
            return calendar.status.capitalized
        }
    }
}

#Preview {
    ConnectedCalendarsView()
}

