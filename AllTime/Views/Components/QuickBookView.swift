import SwiftUI
import EventKit

/// Destination for quick booking
enum QuickBookDestination: String, CaseIterable {
    case calendar = "Calendar"
    case reminder = "Reminder"

    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .reminder: return "bell.fill"
        }
    }
}

/// Quick Book View - Easy one-tap calendar booking for common activities
/// Accessible from "Take Action" buttons and other places in the app
struct QuickBookView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var calendarViewModel: CalendarViewModel

    @State private var selectedActivity: QuickActivity?
    @State private var selectedDate = Date()
    @State private var selectedDuration: TimeInterval = 3600 // 1 hour default
    @State private var isBooking = false
    @State private var bookingSuccess = false
    @State private var bookingError: String?
    @State private var showDatePicker = false
    @State private var selectedDestination: QuickBookDestination = .calendar

    // Pre-defined quick activities
    private let activities: [QuickActivity] = [
        QuickActivity(id: "gym", title: "Gym / Workout", icon: "dumbbell.fill", color: DesignSystem.Colors.errorRed, defaultDuration: 3600),
        QuickActivity(id: "walk", title: "Walk / Exercise", icon: "figure.walk", color: DesignSystem.Colors.emerald, defaultDuration: 1800),
        QuickActivity(id: "focus", title: "Focus Time", icon: "brain.head.profile", color: DesignSystem.Colors.violet, defaultDuration: 5400),
        QuickActivity(id: "personal", title: "Personal Time", icon: "person.fill", color: DesignSystem.Colors.amber, defaultDuration: 3600),
        QuickActivity(id: "lunch", title: "Lunch Break", icon: "fork.knife", color: Color(hex: "06B6D4"), defaultDuration: 3600),
        QuickActivity(id: "meditation", title: "Meditation", icon: "sparkles", color: Color(hex: "EC4899"), defaultDuration: 900),
        QuickActivity(id: "reading", title: "Reading Time", icon: "book.fill", color: DesignSystem.Colors.indigo, defaultDuration: 1800),
        QuickActivity(id: "custom", title: "Custom Event", icon: "plus.circle.fill", color: Color(hex: "64748B"), defaultDuration: 3600)
    ]

    private let durations: [(label: String, seconds: TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("45 min", 2700),
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.primary)

                        Text("Quick Book")
                            .font(.title2.bold())
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text("Block time on your calendar in seconds")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .padding(.top, 20)

                    // Activity Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(activities) { activity in
                            activityButton(activity)
                        }
                    }
                    .padding(.horizontal)

                    // Selected Activity Details
                    if let activity = selectedActivity {
                        VStack(spacing: 16) {
                            Divider()
                                .padding(.horizontal)

                            // Time Selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("When?")
                                    .font(.headline)
                                    .foregroundColor(DesignSystem.Colors.primaryText)

                                Button(action: { showDatePicker.toggle() }) {
                                    HStack {
                                        Image(systemName: "clock.fill")
                                            .foregroundColor(activity.color)
                                        Text(formatDateTime(selectedDate))
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    }
                                    .padding()
                                    .background(DesignSystem.Colors.cardBackground)
                                    .cornerRadius(12)
                                }

                                if showDatePicker {
                                    DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.graphical)
                                        .padding()
                                        .background(DesignSystem.Colors.cardBackground)
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)

                            // Duration Selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("How long?")
                                    .font(.headline)
                                    .foregroundColor(DesignSystem.Colors.primaryText)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(durations, id: \.seconds) { duration in
                                            durationChip(duration.label, seconds: duration.seconds, activity: activity)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)

                            // Destination Selection (Calendar or Reminder)
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Add to")
                                    .font(.headline)
                                    .foregroundColor(DesignSystem.Colors.primaryText)

                                HStack(spacing: 12) {
                                    ForEach(QuickBookDestination.allCases, id: \.self) { destination in
                                        destinationButton(destination, activity: activity)
                                    }
                                }
                            }
                            .padding(.horizontal)

                            // Book Button
                            Button(action: bookEvent) {
                                HStack {
                                    if isBooking {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: selectedDestination == .calendar ? "calendar.badge.plus" : "bell.badge.fill")
                                        Text(selectedDestination == .calendar ? "Book \(activity.title)" : "Set Reminder")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(activity.color)
                                .foregroundColor(.white)
                                .cornerRadius(14)
                            }
                            .disabled(isBooking)
                            .padding(.horizontal)
                            .padding(.top, 8)

                            if let error = bookingError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .alert(selectedDestination == .calendar ? "Booked!" : "Reminder Set!", isPresented: $bookingSuccess) {
                Button("Great", role: .cancel) { dismiss() }
            } message: {
                if let activity = selectedActivity {
                    Text("\(activity.title) has been added to your \(selectedDestination.rawValue.lowercased()).")
                }
            }
        }
    }

    // MARK: - Activity Button
    private func activityButton(_ activity: QuickActivity) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedActivity = activity
                selectedDuration = activity.defaultDuration
                // Round to next 15 minutes
                let calendar = Calendar.current
                let minute = calendar.component(.minute, from: Date())
                let roundedMinute = ((minute / 15) + 1) * 15
                selectedDate = calendar.date(bySettingHour: calendar.component(.hour, from: Date()),
                                             minute: roundedMinute % 60,
                                             second: 0,
                                             of: Date()) ?? Date()
                if roundedMinute >= 60 {
                    selectedDate = calendar.date(byAdding: .hour, value: 1, to: selectedDate) ?? selectedDate
                }
            }
            HapticManager.shared.lightTap()
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(activity.color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: activity.icon)
                        .font(.system(size: 24))
                        .foregroundColor(activity.color)
                }

                Text(activity.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(selectedActivity?.id == activity.id ? activity.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Duration Chip
    private func durationChip(_ label: String, seconds: TimeInterval, activity: QuickActivity) -> some View {
        Button(action: {
            selectedDuration = seconds
            HapticManager.shared.lightTap()
        }) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(selectedDuration == seconds ? .white : DesignSystem.Colors.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(selectedDuration == seconds ? activity.color : DesignSystem.Colors.cardBackground)
                )
        }
    }

    // MARK: - Destination Button
    private func destinationButton(_ destination: QuickBookDestination, activity: QuickActivity) -> some View {
        Button(action: {
            selectedDestination = destination
            HapticManager.shared.lightTap()
        }) {
            HStack(spacing: 8) {
                Image(systemName: destination.icon)
                    .font(.system(size: 16))
                Text(destination.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(selectedDestination == destination ? .white : DesignSystem.Colors.primaryText)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedDestination == destination ? activity.color : DesignSystem.Colors.cardBackground)
            )
        }
    }

    // MARK: - Book Event
    private func bookEvent() {
        guard let activity = selectedActivity else { return }

        isBooking = true
        bookingError = nil

        switch selectedDestination {
        case .calendar:
            bookToCalendar(activity: activity)
        case .reminder:
            bookToReminder(activity: activity)
        }
    }

    private func bookToCalendar(activity: QuickActivity) {
        let endDate = selectedDate.addingTimeInterval(selectedDuration)

        Task {
            do {
                // Use the FocusTimeService to book the event on calendar
                let response = try await FocusTimeService.shared.blockFocusTime(
                    start: selectedDate,
                    end: endDate,
                    title: activity.title,
                    description: "Booked via Quick Book"
                )

                await MainActor.run {
                    isBooking = false
                    if response.success {
                        HapticManager.shared.success()
                        bookingSuccess = true
                        // Post notification so all views refresh their calendar data
                        NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)
                    } else {
                        bookingError = response.message ?? "Failed to book event"
                        HapticManager.shared.error()
                    }
                }
            } catch {
                await MainActor.run {
                    isBooking = false
                    bookingError = "Failed to book: \(error.localizedDescription)"
                    HapticManager.shared.error()
                }
            }
        }
    }

    private func bookToReminder(activity: QuickActivity) {
        let eventStore = EKEventStore()

        // Request access to reminders
        if #available(iOS 17.0, *) {
            Task {
                do {
                    let granted = try await eventStore.requestFullAccessToReminders()
                    if granted {
                        await createReminder(eventStore: eventStore, activity: activity)
                    } else {
                        await MainActor.run {
                            isBooking = false
                            bookingError = "Please allow access to Reminders in Settings"
                            HapticManager.shared.error()
                        }
                    }
                } catch {
                    await MainActor.run {
                        isBooking = false
                        bookingError = "Failed to access Reminders: \(error.localizedDescription)"
                        HapticManager.shared.error()
                    }
                }
            }
        } else {
            eventStore.requestAccess(to: .reminder) { granted, error in
                if granted {
                    Task {
                        await createReminder(eventStore: eventStore, activity: activity)
                    }
                } else {
                    DispatchQueue.main.async {
                        isBooking = false
                        bookingError = error?.localizedDescription ?? "Please allow access to Reminders in Settings"
                        HapticManager.shared.error()
                    }
                }
            }
        }
    }

    private func createReminder(eventStore: EKEventStore, activity: QuickActivity) async {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = activity.title
        reminder.notes = "Added via Quick Book"

        // Set the due date
        let calendar = Calendar.current
        var dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: selectedDate)
        reminder.dueDateComponents = dueDateComponents

        // Add alarm at the scheduled time
        let alarm = EKAlarm(absoluteDate: selectedDate)
        reminder.addAlarm(alarm)

        // Use default reminders list
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        do {
            try eventStore.save(reminder, commit: true)
            await MainActor.run {
                isBooking = false
                HapticManager.shared.success()
                bookingSuccess = true
                // Post notification so views know a reminder was created
                NotificationCenter.default.post(name: NSNotification.Name("ReminderCreated"), object: nil)
            }
        } catch {
            await MainActor.run {
                isBooking = false
                bookingError = "Failed to create reminder: \(error.localizedDescription)"
                HapticManager.shared.error()
            }
        }
    }

    // MARK: - Helpers
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Quick Activity Model
struct QuickActivity: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
    let defaultDuration: TimeInterval
}

// MARK: - Preview
#Preview {
    QuickBookView()
        .environmentObject(CalendarViewModel())
        .preferredColorScheme(.dark)
}
