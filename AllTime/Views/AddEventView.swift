import SwiftUI
import Combine

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddEventViewModel
    @State private var isAllDay = false
    
    init(initialDate: Date = Date()) {
        _viewModel = StateObject(wrappedValue: AddEventViewModel(initialDate: initialDate))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // iOS 18 Glassy Background
                LinearGradient(
                    colors: [
                        Color(UIColor.systemBackground),
                        Color(UIColor.secondarySystemBackground).opacity(0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Title Card
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Title")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            
                            TextField("Event title", text: $viewModel.title)
                                .font(DesignSystem.Typography.bodyBold)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .padding(DesignSystem.Spacing.md)
                                .background(DesignSystem.Materials.cardMaterial)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignSystem.Materials.cardMaterial)
                        .background(DesignSystem.Colors.cardBackground.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                        
                        // Date & Time Card
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Date & Time")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            
                            DatePicker("Start", selection: $viewModel.startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                            
                            DatePicker("End", selection: $viewModel.endDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                            
                            Toggle("All Day", isOn: $isAllDay)
                                .toggleStyle(.switch)
                                .onChange(of: isAllDay) { _, _ in
                                    HapticManager.shared.selectionChanged()
                                }
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignSystem.Materials.cardMaterial)
                        .background(DesignSystem.Colors.cardBackground.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
                        
                        // Location Card
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Location")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            
                            TextField("Add location", text: $viewModel.location)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .padding(DesignSystem.Spacing.md)
                                .background(DesignSystem.Materials.cardMaterial)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignSystem.Materials.cardMaterial)
                        .background(DesignSystem.Colors.cardBackground.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
                        
                        // Description Card
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Description")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondaryText)

                            TextEditor(text: $viewModel.description)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .frame(minHeight: 100)
                                .padding(DesignSystem.Spacing.sm)
                                .background(DesignSystem.Materials.cardMaterial)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignSystem.Materials.cardMaterial)
                        .background(DesignSystem.Colors.cardBackground.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)

                        // Event Color Card
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            InlineColorPicker(selectedColor: $viewModel.selectedColor)
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignSystem.Materials.cardMaterial)
                        .background(DesignSystem.Colors.cardBackground.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)

                        // Calendar Selection Card
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Calendar")
                                .font(DesignSystem.Typography.subheadline)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            
                            if viewModel.isLoadingCalendars {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading calendars...")
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                }
                            } else {
                                Menu {
                                    Button(action: {
                                        viewModel.selectedCalendar = nil
                                    }) {
                                        Label("Local Only", systemImage: "calendar")
                                    }
                                    
                                    ForEach(viewModel.calendars) { calendar in
                                        Button(action: {
                                            viewModel.selectedCalendar = calendar
                                        }) {
                                            Label("\(calendar.provider.capitalized) (\(calendar.displayEmail))", systemImage: calendar.provider == "google" ? "g.circle.fill" : "m.circle.fill")
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(viewModel.selectedCalendar != nil ? "\(viewModel.selectedCalendar!.provider.capitalized) (\(viewModel.selectedCalendar!.displayEmail))" : "Local Only")
                                            .font(DesignSystem.Typography.body)
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                    }
                                    .padding(DesignSystem.Spacing.md)
                                    .background(DesignSystem.Materials.cardMaterial)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                                }
                                
                                if let selectedCalendar = viewModel.selectedCalendar {
                                    Text("Invites will be sent from: \(selectedCalendar.displayEmail)")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                                        .padding(.top, 4)
                                } else {
                                    Text("Event will be saved locally only")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignSystem.Materials.cardMaterial)
                        .background(DesignSystem.Colors.cardBackground.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
                        
                        // Attendees Card
                        if viewModel.selectedCalendar != nil {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                Text("Attendees")
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                
                                // Add attendee input
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    TextField("Add attendee email", text: $viewModel.newAttendeeEmail)
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .padding(DesignSystem.Spacing.md)
                                        .background(DesignSystem.Materials.cardMaterial)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                                    
                                    Button(action: {
                                        viewModel.addAttendee()
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(DesignSystem.Colors.primary)
                                    }
                                    .disabled(viewModel.newAttendeeEmail.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                                
                                // Attendees list
                                if !viewModel.attendees.isEmpty {
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                        ForEach(viewModel.attendees, id: \.self) { email in
                                            HStack {
                                                Image(systemName: "person.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(DesignSystem.Colors.primary)
                                                
                                                Text(email)
                                                    .font(DesignSystem.Typography.body)
                                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                                
                                                Spacer()
                                                
                                                Button(action: {
                                                    viewModel.removeAttendee(email)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 18))
                                                        .foregroundColor(.red.opacity(0.7))
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                    .padding(.top, DesignSystem.Spacing.sm)
                                }
                            }
                            .padding(DesignSystem.Spacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DesignSystem.Materials.cardMaterial)
                            .background(DesignSystem.Colors.cardBackground.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.05)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
                        }
                        
                        // Save Button
                        Button(action: {
                            Task {
                                await viewModel.createEvent(isAllDay: isAllDay)
                                // Dismiss immediately on success - success message will show briefly
                                if viewModel.isSuccess {
                                    // Small delay to show success feedback, then dismiss
                                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                                    await MainActor.run {
                                        dismiss()
                                    }
                                }
                            }
                        }) {
                            HStack {
                                if viewModel.isCreating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                }
                                
                                Text(viewModel.isCreating ? "Creating..." : "Create Event")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(DesignSystem.Spacing.md)
                            .background(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primary,
                                        DesignSystem.Colors.primaryLight
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                            .shadow(
                                color: DesignSystem.Colors.primary.opacity(0.4),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                        }
                        .buttonStyle(SmoothButtonStyle(haptic: .medium))
                        .disabled(viewModel.isCreating || viewModel.title.isEmpty)
                        .opacity(viewModel.title.isEmpty ? 0.6 : 1.0)
                        .animation(.smoothSpring, value: viewModel.title.isEmpty)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.top, DesignSystem.Spacing.sm)

                        if let errorMessage = viewModel.errorMessage {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                    Text("Error")
                                        .font(DesignSystem.Typography.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.red)

                                Text(errorMessage)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(.red.opacity(0.9))
                            }
                            .padding(DesignSystem.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .onAppear {
                                HapticManager.shared.error()
                            }
                        }

                        if let successMessage = viewModel.successMessage {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                    Text("Success")
                                        .font(DesignSystem.Typography.caption)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.green)

                                Text(successMessage)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(.green.opacity(0.9))
                            }
                            .padding(DesignSystem.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .onAppear {
                                HapticManager.shared.success()
                            }
                        }
                        
                        Spacer(minLength: 110) // Reserve space for tab bar
                    }
                    .padding(DesignSystem.Spacing.md)
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            .onAppear {
                // Load calendars when view appears
                Task {
                    await viewModel.loadCalendars()
                }
            }
        }
    }
}

    @MainActor
class AddEventViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var location = ""
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var selectedCalendar: ConnectedCalendar? = nil  // nil = local only
    @Published var calendars: [ConnectedCalendar] = []
    @Published var isLoadingCalendars = false
    @Published var attendees: [String] = []
    @Published var newAttendeeEmail = ""
    @Published var selectedColor: String = "#3B82F6"  // Default blue color
    
    init(initialDate: Date = Date()) {
        self.startDate = initialDate
        // Set end date to 1 hour after start date, preserving the selected day
        let calendar = Calendar.current
        self.endDate = calendar.date(byAdding: .hour, value: 1, to: initialDate) ?? initialDate.addingTimeInterval(3600)
    }
    @Published var isCreating = false
    @Published var isSuccess = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var syncStatus: CreateEventResponse?
    
    private let apiService = APIService()
    
    func loadCalendars() async {
        isLoadingCalendars = true
        do {
            let response = try await apiService.getConnectedCalendars()
            calendars = response.calendars
            print("✅ AddEventViewModel: Loaded \(calendars.count) calendars")
        } catch {
            print("❌ AddEventViewModel: Failed to load calendars: \(error)")
        }
        isLoadingCalendars = false
    }
    
    func addAttendee() {
        let email = newAttendeeEmail.trimmingCharacters(in: .whitespaces)
        guard !email.isEmpty else { return }
        
        // Basic email validation
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        
        guard emailPredicate.evaluate(with: email) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        guard !attendees.contains(email.lowercased()) else {
            errorMessage = "This attendee is already added"
            return
        }
        
        attendees.append(email.lowercased())
        newAttendeeEmail = ""
        errorMessage = nil
    }
    
    func removeAttendee(_ email: String) {
        attendees.removeAll { $0.lowercased() == email.lowercased() }
    }
    
    func createEvent(isAllDay: Bool) async {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter an event title"
            return
        }
        
        guard endDate > startDate else {
            errorMessage = "End time must be after start time"
            return
        }
        
        isCreating = true
        errorMessage = nil
        successMessage = nil
        syncStatus = nil
        
        do {
            // Adjust end date for all-day events
            var actualEndDate = endDate
            if isAllDay {
                // For all-day events, end date should be start of next day
                // (Google Calendar and Microsoft Calendar use exclusive end dates for all-day events)
                let calendar = Calendar.current
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: startDate)) {
                    actualEndDate = nextDay
                }
            }
            
            // Get provider from selected calendar
            let provider = selectedCalendar?.provider
            
            let response = try await apiService.createEvent(
                title: title,
                description: description.isEmpty ? nil : description,
                location: location.isEmpty ? nil : location,
                startDate: startDate,
                endDate: actualEndDate,
                isAllDay: isAllDay,
                provider: provider,
                attendees: attendees.isEmpty ? nil : attendees,
                eventColor: selectedColor
            )
            
            syncStatus = response
            
            // Build success message with sync status
            var message = "Event '\(response.title)' created successfully!"
            
            if response.syncStatus.synced {
                let providerName = response.syncStatus.provider.capitalized
                message += "\n✅ Synced to \(providerName) Calendar"
                
                if let attendeesCount = response.syncStatus.attendeesCount, attendeesCount > 0 {
                    message += "\n📧 Invites sent to \(attendeesCount) attendee\(attendeesCount == 1 ? "" : "s")"
                    
                    // Show meeting link info if available
                    if let meetingLink = response.syncStatus.meetingLink, !meetingLink.isEmpty {
                        if let meetingType = response.syncStatus.meetingType {
                            let meetingName = meetingType == "google_meet" ? "Google Meet" : "Microsoft Teams"
                            message += "\n🔗 \(meetingName) link added"
                        } else {
                            message += "\n🔗 Meeting link added"
                        }
                    }
                }
            } else {
                message += "\n⚠️ Saved locally (no external calendar selected)"
            }
            
            successMessage = message
            isSuccess = true
            isCreating = false
            
            // Post notification for UI to refresh events (before dismissing)
            NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: response)
            
            print("✅ AddEventViewModel: Event created successfully")
            print("   - Provider: \(response.syncStatus.provider)")
            print("   - Synced: \(response.syncStatus.synced)")
            if let attendeesCount = response.syncStatus.attendeesCount {
                print("   - Attendees: \(attendeesCount)")
            }
            if let meetingLink = response.syncStatus.meetingLink, !meetingLink.isEmpty {
                print("   - Meeting link: \(meetingLink)")
            }
            if let meetingType = response.syncStatus.meetingType {
                print("   - Meeting type: \(meetingType)")
            }
            
        } catch let error as NSError {
            let errorMsg = error.localizedDescription
            errorMessage = errorMsg
            isCreating = false
            print("❌ AddEventViewModel: Failed to create event: \(errorMsg)")
            print("   - Error code: \(error.code)")
            print("   - Error domain: \(error.domain)")
        } catch {
            errorMessage = "Failed to create event: \(error.localizedDescription)"
            isCreating = false
            print("❌ AddEventViewModel: Failed to create event: \(error)")
        }
    }
}

