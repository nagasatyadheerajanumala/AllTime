import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 60))
                        .foregroundColor(DesignSystem.Colors.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clara")
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
                    Text("About Clara")
                        .font(.headline)

                    Text("Clara is your intelligent calendar assistant that brings together events from Google, Outlook, and Apple calendars. Get AI-powered daily briefings, work-life balance insights, and personalized recommendations.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Description")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "calendar", color: DesignSystem.Colors.blue, title: "Unified Calendar", description: "View all your events in one place")
                    FeatureRow(icon: "brain.head.profile", color: DesignSystem.Colors.violet, title: "AI Briefings", description: "Get personalized daily insights")
                    FeatureRow(icon: "heart.fill", color: Color(hex: "EC4899"), title: "Work-Life Balance", description: "Track and improve your balance")
                    FeatureRow(icon: "bell.badge.fill", color: DesignSystem.Colors.amber, title: "Smart Notifications", description: "Never miss important events")
                    FeatureRow(icon: "lock.shield.fill", color: DesignSystem.Colors.emerald, title: "Privacy First", description: "Your data stays secure")
                }
            } header: {
                Text("Features")
            }

            Section {
                Link(destination: URL(string: "https://theclaraai.com/privacy")!) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(DesignSystem.Colors.blue)
                        Text("Privacy Policy")
                    }
                }
                Link(destination: URL(string: "https://theclaraai.com/terms")!) {
                    HStack {
                        Image(systemName: "doc.plaintext")
                            .foregroundColor(DesignSystem.Colors.blue)
                        Text("Terms of Service")
                    }
                }
                Link(destination: URL(string: "https://theclaraai.com/support")!) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(DesignSystem.Colors.blue)
                        Text("Support")
                    }
                }
            } header: {
                Text("Legal")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Made with ❤️ by the Clara Team")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("© 2025 Clara. All rights reserved.")
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
    var color: Color = .blue
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
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
