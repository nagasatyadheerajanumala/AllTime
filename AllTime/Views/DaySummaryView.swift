import SwiftUI

/// End-of-day summary view showing how the user's day went
struct DaySummaryView: View {
    @StateObject private var viewModel = DaySummaryViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var calendarViewModel: CalendarViewModel

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(hex: "1A1A2E"),
                        Color(hex: "16213E"),
                        Color(hex: "0F0F1A")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header with greeting
                            headerSection

                            // Day mood card
                            dayMoodCard

                            // Quick stats
                            statsSection

                            // Meetings completed
                            if !viewModel.completedMeetings.isEmpty {
                                meetingsSection
                            }

                            // Accomplishments
                            if !viewModel.accomplishments.isEmpty {
                                accomplishmentsSection
                            }

                            // Tomorrow preview
                            tomorrowPreviewSection

                            // Closing message
                            closingMessage

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
            .navigationTitle("Day Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .task {
            await viewModel.loadSummary(events: calendarViewModel.eventsForToday())
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.greeting)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(viewModel.dateString)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Day Mood Card

    private var dayMoodCard: some View {
        VStack(spacing: 16) {
            // Mood emoji
            Text(viewModel.moodEmoji)
                .font(.system(size: 56))

            // Mood title
            Text(viewModel.moodTitle)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            // Summary line
            Text(viewModel.summaryLine)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: viewModel.moodGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Numbers")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                SummaryStatCard(
                    icon: "calendar.badge.checkmark",
                    value: "\(viewModel.meetingsCompleted)/\(viewModel.totalMeetings)",
                    label: "Meetings",
                    color: .blue
                )

                SummaryStatCard(
                    icon: "clock.fill",
                    value: viewModel.focusTimeUsed,
                    label: "Focus Time",
                    color: .purple
                )

                SummaryStatCard(
                    icon: "checkmark.circle.fill",
                    value: "\(viewModel.tasksCompleted)",
                    label: "Tasks Done",
                    color: .green
                )
            }
        }
    }

    // MARK: - Meetings Section

    private var meetingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Meetings Completed")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(viewModel.completedMeetings.count)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            VStack(spacing: 8) {
                ForEach(viewModel.completedMeetings.prefix(5), id: \.id) { meeting in
                    CompletedMeetingRow(meeting: meeting)
                }

                if viewModel.completedMeetings.count > 5 {
                    Text("+ \(viewModel.completedMeetings.count - 5) more")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    // MARK: - Accomplishments Section

    private var accomplishmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accomplishments")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 8) {
                ForEach(viewModel.accomplishments, id: \.self) { accomplishment in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 16))

                        Text(accomplishment)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.9))

                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    // MARK: - Tomorrow Preview

    private var tomorrowPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tomorrow at a Glance")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.tomorrowMeetings)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("meetings")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                if let firstMeeting = viewModel.tomorrowFirstMeeting {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("First meeting")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                        Text(firstMeeting)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // MARK: - Closing Message

    private var closingMessage: some View {
        VStack(spacing: 12) {
            Text(viewModel.closingMessage)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .italic()

            Text("- Clara")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 20)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)

            Text("Preparing your day summary...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Supporting Views

private struct SummaryStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
    }
}

private struct CompletedMeetingRow: View {
    let meeting: Event

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(meeting.displayColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)

                if let startDate = meeting.startDate {
                    Text(formatTime(startDate))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green.opacity(0.7))
                .font(.system(size: 14))
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    DaySummaryView()
        .environmentObject(CalendarViewModel())
}
