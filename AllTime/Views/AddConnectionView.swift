import SwiftUI
import EventKit

struct AddConnectionView: View {
    @EnvironmentObject var oauthManager: OAuthManager
    @StateObject private var googleAuthManager = GoogleAuthManager.shared
    @StateObject private var microsoftAuthManager = MicrosoftAuthManager.shared
    @StateObject private var calendarManager = CalendarManager()
    @Environment(\.dismiss) private var dismiss
    @State private var showingManualOAuth = false
    @State private var selectedProvider = ""
    @State private var isEventKitSyncing = false
    @State private var eventKitSyncMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Connect Your Calendars")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Connect your calendar providers to sync events and get AI-powered insights")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                    
                    // Provider Cards
                    VStack(spacing: 20) {
                        // iPhone Calendar - EventKit (Best for work accounts)
                        ProviderCard(
                            title: "iPhone Calendar",
                            description: calendarManager.hasPermission ? "✅ Access Granted" : "Sync calendars from your iPhone (Outlook, iCloud, etc.)",
                            icon: "iphone",
                            color: .purple
                        ) {
                            if !calendarManager.hasPermission {
                                calendarManager.requestCalendarAccess()
                            } else {
                                syncEventKitCalendars()
                            }
                        }

                        // Info about iPhone Calendar
                        if !calendarManager.hasPermission {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Best for work Outlook calendars that block direct OAuth")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }

                        Divider()
                            .padding(.vertical, 8)

                        Text("Or connect directly:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Google Calendar - Native OAuth
                        ProviderCard(
                            title: "Google Calendar",
                            description: googleAuthManager.isConnected ? "✅ Connected" : "Sync your Google Calendar events",
                            icon: "g.circle.fill",
                            color: .red
                        ) {
                            if !googleAuthManager.isConnected {
                                googleAuthManager.startGoogleOAuth()
                            }
                        }

                        // Microsoft Outlook - Native OAuth
                        ProviderCard(
                            title: "Microsoft Outlook",
                            description: microsoftAuthManager.isConnected ? "✅ Connected" : "Sync your Outlook calendar events",
                            icon: "m.circle.fill",
                            color: .blue
                        ) {
                            if !microsoftAuthManager.isConnected {
                                microsoftAuthManager.startMicrosoftOAuth()
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Status Messages
                    VStack(spacing: 16) {
                        // EventKit Sync Status
                        if let message = eventKitSyncMessage {
                            HStack(spacing: 12) {
                                Image(systemName: message.contains("successfully") || message.contains("✅") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(message.contains("successfully") || message.contains("✅") ? .green : .orange)

                                Text(message)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(message.contains("successfully") || message.contains("✅") ? .green : .orange)
                                    .multilineTextAlignment(.leading)

                                Spacer()
                            }
                            .padding(16)
                            .background((message.contains("successfully") || message.contains("✅") ? Color.green : Color.orange).opacity(0.08))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .transition(.scale.combined(with: .opacity))
                        }

                        // Google Auth Status
                        if let errorMessage = googleAuthManager.errorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: errorMessage.contains("successfully") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(errorMessage.contains("successfully") ? .green : .red)
                                
                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(errorMessage.contains("successfully") ? .green : .red)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                            .padding(16)
                            .background((errorMessage.contains("successfully") ? Color.green : Color.red).opacity(0.08))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Microsoft Auth Status
                        if let errorMessage = microsoftAuthManager.errorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: errorMessage.contains("successfully") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(errorMessage.contains("successfully") ? .green : .red)
                                
                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(errorMessage.contains("successfully") ? .green : .red)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                            .padding(16)
                            .background((errorMessage.contains("successfully") ? Color.green : Color.red).opacity(0.08))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // OAuth Manager Status
                        if let errorMessage = oauthManager.errorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.red)
                                
                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    // Loading Indicators
                    if googleAuthManager.isAuthenticating || microsoftAuthManager.isAuthenticating || oauthManager.isAuthenticating || isEventKitSyncing {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(1.2)
                            Text(isEventKitSyncing ? "Syncing iPhone calendars..." :
                                 googleAuthManager.isAuthenticating ? "Opening Google OAuth..." :
                                 microsoftAuthManager.isAuthenticating ? "Opening Microsoft OAuth..." :
                                 "Opening browser for authentication...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Spacer()
                        .frame(height: 40)
                }
            }
            .navigationTitle("Add Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingManualOAuth) {
                ManualOAuthView(provider: selectedProvider)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: googleAuthManager.isAuthenticating)
        .animation(.easeInOut(duration: 0.3), value: googleAuthManager.errorMessage)
        .animation(.easeInOut(duration: 0.3), value: microsoftAuthManager.isAuthenticating)
        .animation(.easeInOut(duration: 0.3), value: microsoftAuthManager.errorMessage)
        .animation(.easeInOut(duration: 0.3), value: oauthManager.isAuthenticating)
        .animation(.easeInOut(duration: 0.3), value: oauthManager.errorMessage)
        .animation(.easeInOut(duration: 0.3), value: isEventKitSyncing)
        .animation(.easeInOut(duration: 0.3), value: eventKitSyncMessage)
        .onChange(of: calendarManager.hasPermission) { _, hasPermission in
            if hasPermission {
                syncEventKitCalendars()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MicrosoftCalendarConnected"))) { _ in
            // Refresh calendar list when Microsoft calendar is connected
            Task {
                // Small delay to ensure backend has processed the connection
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                dismiss() // Close the add calendar view
            }
        }
    }

    // MARK: - EventKit Sync
    private func syncEventKitCalendars() {
        isEventKitSyncing = true
        eventKitSyncMessage = nil

        // Get calendar names for display
        let calendarNames = calendarManager.calendars.map { $0.title }.joined(separator: ", ")

        Task {
            do {
                // Load events from last month to next month
                let startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
                let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
                calendarManager.loadEvents(from: startDate, to: endDate)

                // Sync to backend
                try await APIService.shared.syncEvents(events: calendarManager.events)

                await MainActor.run {
                    isEventKitSyncing = false
                    let eventCount = calendarManager.events.count
                    let calendarCount = calendarManager.calendars.count
                    eventKitSyncMessage = "✅ Synced \(eventCount) events from \(calendarCount) calendars successfully!"

                    // Clear message after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        eventKitSyncMessage = nil
                    }
                }
            } catch {
                await MainActor.run {
                    isEventKitSyncing = false
                    eventKitSyncMessage = "Failed to sync: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct ProviderCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                    .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AddConnectionView()
        .environmentObject(OAuthManager())
}
