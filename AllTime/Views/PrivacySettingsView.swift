import SwiftUI

struct PrivacySettingsView: View {
    @State private var dataSharingEnabled = false
    @State private var analyticsEnabled = true
    @State private var crashReportingEnabled = true
    @State private var isResyncingHealth = false
    @State private var showResyncAlert = false
    @State private var useSleepDataForInsights = true
    @State private var isLoadingSleepPref = true
    @ObservedObject private var healthSyncService = HealthSyncService.shared
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared

    var body: some View {
        List {
            Section {
                Toggle("Data Sharing", isOn: $dataSharingEnabled)
            } header: {
                Text("Data Usage")
            } footer: {
                Text("Allow sharing of anonymized usage data to improve the app experience")
            }
            
            Section {
                Toggle("Analytics", isOn: $analyticsEnabled)
            } header: {
                Text("Analytics")
            } footer: {
                Text("Help us understand how you use Clara to improve features")
            }
            
            Section {
                Toggle("Crash Reporting", isOn: $crashReportingEnabled)
            } header: {
                Text("Error Reporting")
            } footer: {
                Text("Automatically send crash reports to help fix issues")
            }
            
            Section {
                Button("Export My Data") {
                    exportUserData()
                }

                Button("Delete My Account", role: .destructive) {
                    // This would require backend implementation
                }
            } header: {
                Text("Data Management")
            } footer: {
                Text("Export or delete your personal data")
            }

            Section {
                // HealthKit Status
                HStack {
                    Label("HealthKit Status", systemImage: "heart.fill")
                        .foregroundColor(.pink)
                    Spacer()
                    Text(healthMetricsService.isAuthorized ? "Connected" : "Not Connected")
                        .foregroundColor(healthMetricsService.isAuthorized ? .green : .secondary)
                }

                // Last Sync Date
                if let lastSync = healthSyncService.lastSyncDate {
                    HStack {
                        Label("Last Synced", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text(lastSync, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }

                // Force Resync Button
                Button(action: {
                    showResyncAlert = true
                }) {
                    HStack {
                        Label("Resync Health Data", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if isResyncingHealth {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(isResyncingHealth || !healthMetricsService.isAuthorized)
            } header: {
                Text("Health Data")
            } footer: {
                Text("If your health data appears incorrect, try resyncing. This will fetch the last 30 days of data from HealthKit.")
            }

            // Clara Sleep Insights Section
            Section {
                if isLoadingSleepPref {
                    HStack {
                        Label("Sleep Insights", systemImage: "bed.double.fill")
                            .foregroundColor(.indigo)
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                } else {
                    Toggle(isOn: $useSleepDataForInsights) {
                        Label("Sleep Insights", systemImage: "bed.double.fill")
                            .foregroundColor(.indigo)
                    }
                    .onChange(of: useSleepDataForInsights) { _, newValue in
                        Task {
                            await updateSleepInsightsPreference(newValue)
                        }
                    }
                }
            } header: {
                Text("Clara AI Settings")
            } footer: {
                Text(useSleepDataForInsights
                    ? "Clara uses your sleep data to provide personalized insights and recommendations."
                    : "Sleep data is disabled. Clara will not mention sleep or make sleep-related recommendations.")
            }
            .alert("Resync Health Data?", isPresented: $showResyncAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Resync") {
                    Task {
                        isResyncingHealth = true
                        await healthSyncService.forceFullResync()
                        isResyncingHealth = false
                    }
                }
            } message: {
                Text("This will clear cached health data and resync the last 30 days from HealthKit. This may take a moment.")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Policy")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("We take your privacy seriously. Your calendar data is encrypted and never shared with third parties.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Privacy Information")
            }
        }
        .navigationTitle("Privacy & Security")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await loadSleepInsightsPreference()
            }
        }
    }
    
    private func exportUserData() {
        // This would implement data export functionality
        print("Exporting user data...")
    }

    /// Load the sleep insights preference from the server
    private func loadSleepInsightsPreference() async {
        guard let token = KeychainManager.shared.getAccessToken(), !token.isEmpty else {
            isLoadingSleepPref = false
            return
        }

        guard let url = URL(string: "\(Constants.API.baseURL)/api/user/preferences/sleep-insights") else {
            isLoadingSleepPref = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                isLoadingSleepPref = false
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let value = json["useSleepDataForInsights"] as? Bool {
                await MainActor.run {
                    self.useSleepDataForInsights = value
                    self.isLoadingSleepPref = false
                }
            } else {
                await MainActor.run {
                    self.isLoadingSleepPref = false
                }
            }
        } catch {
            print("Failed to load sleep insights preference: \(error)")
            await MainActor.run {
                self.isLoadingSleepPref = false
            }
        }
    }

    /// Update the sleep insights preference on the server
    private func updateSleepInsightsPreference(_ enabled: Bool) async {
        guard let token = KeychainManager.shared.getAccessToken(), !token.isEmpty else { return }

        guard let url = URL(string: "\(Constants.API.baseURL)/api/user/preferences/sleep-insights") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["useSleepDataForInsights": enabled]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                // Revert on failure
                await MainActor.run {
                    self.useSleepDataForInsights = !enabled
                }
                return
            }

            print("Sleep insights preference updated to: \(enabled)")
        } catch {
            print("Failed to update sleep insights preference: \(error)")
            // Revert on failure
            await MainActor.run {
                self.useSleepDataForInsights = !enabled
            }
        }
    }
}

#Preview {
    NavigationView {
        PrivacySettingsView()
    }
}

