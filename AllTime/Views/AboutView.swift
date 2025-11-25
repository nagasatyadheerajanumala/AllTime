import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AllTime")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("About AllTime")
                        .font(.headline)
                    
                    Text("AllTime is your unified calendar experience that brings together events from Google, Outlook, and Apple calendars. Get AI-powered daily summaries and never miss an important event.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Description")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "calendar", title: "Unified Calendar", description: "View all your events in one place")
                    FeatureRow(icon: "brain.head.profile", title: "AI Summaries", description: "Get daily insights about your schedule")
                    FeatureRow(icon: "bell", title: "Smart Notifications", description: "Never miss important events")
                    FeatureRow(icon: "lock", title: "Privacy First", description: "Your data stays secure and private")
                }
            } header: {
                Text("Features")
            }
            
            Section {
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                Link("Support", destination: URL(string: "https://example.com/support")!)
            } header: {
                Text("Legal")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Made with ❤️ by the AllTime Team")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("© 2024 AllTime. All rights reserved.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Credits")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    NavigationView {
        AboutView()
    }
}

