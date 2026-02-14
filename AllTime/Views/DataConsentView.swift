import SwiftUI

/// Data consent view shown during onboarding to comply with App Store guideline 5.1.1(i)/5.1.2(i)
/// Clearly discloses what user data Clara AI processes and requires explicit consent before proceeding
struct DataConsentView: View {
    let onConsent: () -> Void
    @State private var hasScrolledToBottom = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(DesignSystem.Colors.blue)

                            Text("Your Data & Privacy")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)

                            Text("Clara uses AI to help you manage your time. Here's exactly what data is processed and how.")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        .padding(.bottom, 8)

                        // Data categories
                        VStack(spacing: 16) {
                            DataDisclosureCard(
                                icon: "calendar",
                                iconColor: DesignSystem.Colors.blue,
                                title: "Calendar Events",
                                description: "Your calendar events, including titles, times, and locations, are sent to Clara's AI service to provide scheduling insights and conflict detection."
                            )

                            DataDisclosureCard(
                                icon: "heart.fill",
                                iconColor: .pink,
                                title: "Health & Wellness Data",
                                description: "If you connect Apple Health, data such as steps, sleep, heart rate, and workouts are sent to Clara's AI service to provide personalized wellness recommendations."
                            )

                            DataDisclosureCard(
                                icon: "checklist",
                                iconColor: .orange,
                                title: "Tasks & Reminders",
                                description: "Your tasks and reminders are sent to Clara's AI service to help prioritize your day and provide productivity insights."
                            )

                            DataDisclosureCard(
                                icon: "bubble.left.fill",
                                iconColor: DesignSystem.Colors.claraPurple,
                                title: "Chat Messages",
                                description: "Messages you send to Clara are processed by our AI service to generate personalized responses and recommendations."
                            )

                            DataDisclosureCard(
                                icon: "location.fill",
                                iconColor: .green,
                                title: "Location (Optional)",
                                description: "If you grant location access, your approximate location may be used for weather-aware scheduling suggestions."
                            )
                        }
                        .padding(.horizontal, 4)

                        // Who receives the data
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WHO PROCESSES YOUR DATA")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(0.5)

                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "server.rack")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.blue)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Clara AI Backend")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)

                                    Text("Your data is sent to Clara's cloud service powered by AI language models. Data is encrypted in transit and used solely to provide you with personalized time management features. We do not sell your data to third parties.")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06))
                            )
                        }
                        .padding(.horizontal, 4)

                        // Privacy policy link
                        VStack(spacing: 12) {
                            Link(destination: URL(string: "https://theclaraai.com/privacy")!) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 13))
                                    Text("Read our Privacy Policy")
                                        .font(.system(size: 14, weight: .medium))
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(DesignSystem.Colors.blue)
                            }

                            Link(destination: URL(string: "https://theclaraai.com/terms")!) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.plaintext.fill")
                                        .font(.system(size: 13))
                                    Text("Terms of Service")
                                        .font(.system(size: 14, weight: .medium))
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(DesignSystem.Colors.blue)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)

                        // Spacer for bottom padding
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                }

                // Bottom consent bar
                VStack(spacing: 12) {
                    Button(action: onConsent) {
                        Text("I Understand & Agree")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(DesignSystem.Colors.blue)
                            .cornerRadius(14)
                    }

                    Text("You can manage your data sharing preferences anytime in Settings > Privacy & Security.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black, Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(.all, edges: .bottom)
                )
            }
        }
    }
}

// MARK: - Data Disclosure Card

private struct DataDisclosureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }
}

#Preview {
    DataConsentView(onConsent: {})
}
