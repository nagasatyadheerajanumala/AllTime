import SwiftUI

struct PlanMyDayView: View {
    @StateObject private var viewModel = PlanMyDayViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingItinerary = false
    @State private var showingInterestsSetup = false
    @State private var showingWeekendPlan = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Date Picker Section
                    datePickerSection

                    // Day Type Badge
                    if let dayType = viewModel.dayType {
                        DayTypeBadge(dayType: dayType)
                    }

                    // Location Card (for weekend/holiday planning)
                    if viewModel.isFreeDayOff {
                        locationCard
                    }

                    // Needs Setup Banner
                    if viewModel.needsInterestsSetup {
                        setupBanner
                    }

                    // AI Plan Section (for weekends and holidays)
                    if viewModel.isFreeDayOff && !viewModel.needsInterestsSetup {
                        aiWeekendPlanSection
                    }

                    // Weekend Plan Results
                    if let plan = viewModel.weekendPlan {
                        weekendPlanResults(plan: plan)
                    }

                    // Task Suggestions Section (AI-suggested tasks with + button)
                    if !viewModel.taskSuggestions.isEmpty {
                        taskSuggestionsSection
                    }

                    // Activity Suggestions Section
                    if !viewModel.suggestions.isEmpty {
                        suggestionsSection
                    }

                    // Plan My Day Button (for regular workdays)
                    if !viewModel.isFreeDayOff {
                        planButton
                    }

                    // Error Message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Plan Your Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .task {
                await viewModel.loadAllData()
            }
            .onChange(of: viewModel.selectedDate) { _ in
                Task {
                    await viewModel.loadAllData()
                    // Clear previous weekend plan when date changes
                    viewModel.weekendPlan = nil
                }
            }
            .sheet(isPresented: $showingItinerary) {
                if let itinerary = viewModel.itinerary {
                    ItineraryDetailView(itinerary: itinerary)
                }
            }
            .sheet(isPresented: $showingInterestsSetup) {
                InterestsSetupView()
            }
            .sheet(isPresented: $showingWeekendPlan) {
                if let plan = viewModel.weekendPlan {
                    WeekendPlanDetailView(plan: plan)
                }
            }
            .overlay {
                if viewModel.isLoadingSuggestions || viewModel.isLoadingTaskSuggestions || viewModel.isGeneratingWeekendPlan {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            if viewModel.isGeneratingWeekendPlan {
                                Text("Creating your perfect day...")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.7))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Date Picker Section
    private var datePickerSection: some View {
        VStack(spacing: 12) {
            DatePicker(
                "Select Date",
                selection: $viewModel.selectedDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(DesignSystem.Colors.primary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Setup Banner
    private var setupBanner: some View {
        Button(action: { showingInterestsSetup = true }) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Set Up Your Interests")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text("Get personalized suggestions based on what you love")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.primary.opacity(0.1))
            )
        }
    }

    // MARK: - Task Suggestions Section
    private var taskSuggestionsSection: some View {
        TaskSuggestionsSection(
            suggestions: viewModel.taskSuggestions,
            onAccept: { suggestion in
                Task {
                    await viewModel.acceptTaskSuggestion(suggestion)
                }
            },
            onDismiss: { suggestion in
                Task {
                    await viewModel.dismissTaskSuggestion(suggestion)
                }
            }
        )
    }

    // MARK: - Activity Suggestions Section
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Suggested Activities")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
                Text("\(viewModel.suggestions.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(DesignSystem.Colors.primary.opacity(0.15)))
            }

            ForEach(viewModel.suggestions) { suggestion in
                ActivitySuggestionCard(suggestion: suggestion)
            }
        }
    }

    // MARK: - Plan Button
    private var planButton: some View {
        VStack(spacing: 16) {
            // Preferences
            VStack(alignment: .leading, spacing: 12) {
                Text("Itinerary Preferences")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                HStack(spacing: 16) {
                    // Pace picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pace")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        Picker("Pace", selection: $viewModel.pace) {
                            Text("Relaxed").tag("relaxed")
                            Text("Balanced").tag("balanced")
                            Text("Active").tag("active")
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Toggle("Include meal suggestions", isOn: $viewModel.includeMeals)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.cardBackground)
            )

            // Generate Button
            Button(action: {
                Task {
                    await viewModel.generateItinerary()
                    if viewModel.itinerary != nil {
                        showingItinerary = true
                    }
                }
            }) {
                HStack {
                    if viewModel.isGeneratingItinerary {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "calendar.badge.plus")
                        Text("Generate Itinerary")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(viewModel.needsInterestsSetup ? Color.gray : DesignSystem.Colors.primary)
                )
            }
            .disabled(viewModel.isGeneratingItinerary || viewModel.needsInterestsSetup)
        }
    }

    // MARK: - Location Card
    private var locationCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                Text("Your Location")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
            }

            if let location = viewModel.locationString {
                HStack {
                    Text(location)
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            } else {
                Button(action: {
                    viewModel.requestLocation()
                }) {
                    HStack {
                        Image(systemName: "location.circle")
                        Text("Enable Location for Better Recommendations")
                            .font(.subheadline)
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - AI Weekend Plan Section
    private var aiWeekendPlanSection: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Day Planner")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text("Get personalized activities based on your interests")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.purple)
            }

            // Generate Button
            Button(action: {
                Task {
                    await viewModel.generateAIWeekendPlan()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                    Text("Generate My Perfect Day")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
            .disabled(viewModel.isGeneratingWeekendPlan)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Weekend Plan Results
    private func weekendPlanResults(plan: WeekendPlanResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Plan")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text(plan.summary)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                Spacer()
                Button(action: { showingWeekendPlan = true }) {
                    Text("View Full")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.blue)
                }
            }

            // Activities Preview
            ForEach(plan.activities.prefix(3)) { activity in
                WeekendActivityRow(activity: activity)
            }

            if plan.activities.count > 3 {
                Text("+ \(plan.activities.count - 3) more activities")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // Budget & Duration
            HStack(spacing: 20) {
                Label(plan.estimatedBudget, systemImage: "dollarsign.circle")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                Label("\(plan.totalDuration / 60)h planned", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            // Tips
            if !plan.tips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tips")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    ForEach(plan.tips.prefix(2), id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text(tip)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Weekend Activity Row
struct WeekendActivityRow: View {
    let activity: PlannedActivity

    var body: some View {
        HStack(spacing: 12) {
            // Time
            VStack(alignment: .trailing, spacing: 2) {
                Text(activity.startTime)
                    .font(.caption.weight(.medium))
                    .foregroundColor(activity.categoryColor)
                Text(activity.endTime)
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .frame(width: 50)

            // Icon
            ZStack {
                Circle()
                    .fill(activity.categoryColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: activity.icon)
                    .font(.system(size: 14))
                    .foregroundColor(activity.categoryColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                if let location = activity.location {
                    Text(location)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Cost
            if let cost = activity.estimatedCost {
                Text(cost)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Weekend Plan Detail View
struct WeekendPlanDetailView: View {
    let plan: WeekendPlanResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Summary Header
                    VStack(spacing: 8) {
                        Text(plan.date)
                            .font(.title2.weight(.bold))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text(plan.summary)
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 20) {
                            StatPill(icon: "clock", text: "\(plan.totalDuration / 60)h")
                            StatPill(icon: "dollarsign.circle", text: plan.estimatedBudget)
                            StatPill(icon: "list.bullet", text: "\(plan.activities.count)")
                        }
                        .padding(.top, 8)
                    }
                    .padding()

                    // Timeline
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(plan.activities.enumerated()), id: \.element.id) { index, activity in
                            WeekendActivityDetailRow(
                                activity: activity,
                                isLast: index == plan.activities.count - 1
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(DesignSystem.Colors.cardBackground)
                    )

                    // Tips Section
                    if !plan.tips.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tips for Your Day")
                                .font(.headline)
                                .foregroundColor(DesignSystem.Colors.primaryText)

                            ForEach(plan.tips, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.yellow)
                                    Text(tip)
                                        .font(.subheadline)
                                        .foregroundColor(DesignSystem.Colors.secondaryText)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(DesignSystem.Colors.cardBackground)
                        )
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Your Day Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
    }
}

// MARK: - Weekend Activity Detail Row
struct WeekendActivityDetailRow: View {
    let activity: PlannedActivity
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(activity.categoryColor)
                        .frame(width: 12, height: 12)
                }

                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(activity.startTime)
                        .font(.caption.weight(.medium))
                        .foregroundColor(activity.categoryColor)
                    Text("-")
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    Text(activity.endTime)
                        .font(.caption.weight(.medium))
                        .foregroundColor(activity.categoryColor)

                    Spacer()

                    if let cost = activity.estimatedCost {
                        Text(cost)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                            .foregroundColor(.green)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: activity.icon)
                        .foregroundColor(activity.categoryColor)
                    Text(activity.title)
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }

                Text(activity.description)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                if let location = activity.location {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text(location)
                            .font(.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                }

                if let notes = activity.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .italic()
                }

                // Get Directions Button
                if activity.hasCoordinates, let lat = activity.latitude, let lng = activity.longitude {
                    Button(action: {
                        MapLauncherService.showDirectionsOptions(
                            latitude: lat,
                            longitude: lng,
                            destinationName: activity.location ?? activity.title,
                            address: activity.address
                        )
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                .font(.caption)
                            Text("Get Directions")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                        )
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, isLast ? 0 : 24)
        }
    }
}

// MARK: - Day Type Badge
struct DayTypeBadge: View {
    let dayType: DayTypeInfo

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: badgeIcon)
                .font(.headline)
            Text(dayType.dayTypeLabel)
                .font(.headline)
            if dayType.isRestDay {
                Text("Rest Day")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.3)))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(badgeGradient)
        )
    }

    private var badgeIcon: String {
        if dayType.isHoliday { return "star.fill" }
        if dayType.isWeekend { return "sun.max.fill" }
        return "briefcase.fill"
    }

    private var badgeGradient: LinearGradient {
        if dayType.isHoliday || dayType.isWeekend {
            return LinearGradient(
                colors: [Color(hex: "F59E0B"), Color(hex: "EF4444")],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [Color(hex: "3B82F6"), Color(hex: "6366F1")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Activity Suggestion Card
struct ActivitySuggestionCard: View {
    let suggestion: ActivitySuggestion

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(suggestion.categoryColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: suggestion.icon)
                    .font(.title3)
                    .foregroundColor(suggestion.categoryColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                if let desc = suggestion.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    if let time = suggestion.formattedTime {
                        Label(time, systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    if let duration = suggestion.formattedDuration {
                        Label(duration, systemImage: "timer")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Itinerary Detail View
struct ItineraryDetailView: View {
    let itinerary: ItineraryResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    if let message = itinerary.message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    // Day Plans
                    ForEach(itinerary.days) { day in
                        DayPlanCard(day: day)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Your Itinerary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Day Plan Card
struct DayPlanCard: View {
    let day: DayPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Day Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.formattedDate)
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    if let label = day.dayTypeLabel {
                        Text(label)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
                Spacer()
                if let summary = day.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }

            Divider()

            // Time Slots
            if let slots = day.timeSlots {
                ForEach(slots) { slot in
                    TimeSlotRow(slot: slot)
                }
            }

            // Meals
            if let meals = day.meals, !meals.isEmpty {
                Text("Meals")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.top, 8)

                ForEach(meals) { meal in
                    MealRow(meal: meal)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Time Slot Row
struct TimeSlotRow: View {
    let slot: ItineraryTimeSlot

    var body: some View {
        HStack(spacing: 12) {
            // Time
            Text(slot.formattedTimeRange)
                .font(.caption.weight(.medium))
                .foregroundColor(slot.categoryColor)
                .frame(width: 100, alignment: .leading)

            // Activity
            HStack(spacing: 8) {
                Image(systemName: slot.categoryIcon)
                    .font(.caption)
                    .foregroundColor(slot.categoryColor)
                Text(slot.activity)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Meal Row
struct MealRow: View {
    let meal: MealSuggestion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: meal.mealIcon)
                .font(.caption)
                .foregroundColor(Color(hex: "F59E0B"))
                .frame(width: 20)

            Text(meal.mealType.capitalized)
                .font(.caption.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primaryText)

            if let suggestion = meal.suggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()

            if let time = meal.time {
                Text(time)
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    PlanMyDayView()
}
