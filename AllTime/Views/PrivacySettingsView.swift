import SwiftUI

struct PrivacySettingsView: View {
    @State private var dataSharingEnabled = false
    @State private var analyticsEnabled = true
    @State private var crashReportingEnabled = true
    
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
                Text("Help us understand how you use AllTime to improve features")
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
    }
    
    private func exportUserData() {
        // This would implement data export functionality
        print("Exporting user data...")
    }
}

#Preview {
    NavigationView {
        PrivacySettingsView()
    }
}

