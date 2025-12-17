import SwiftUI

struct PlanMyDayView: View {
    @StateObject private var viewModel = PlanMyDayViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showingItinerary = false
    @State private var showingInterestsSetup = false

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

                    // Needs Setup Banner
                    if viewModel.needsInterestsSetup {
                        setupBanner
                    }

                    // Suggestions Section
                    if !viewModel.suggestions.isEmpty {
                        suggestionsSection
                    }

                    // Plan My Day Button
                    planButton

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
                await viewModel.loadSuggestions()
            }
            .onChange(of: viewModel.selectedDate) { _ in
                Task {
                    await viewModel.loadSuggestions()
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
            .overlay {
                if viewModel.isLoadingSuggestions {
                    ProgressView()
                        .scaleEffect(1.5)
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

    // MARK: - Suggestions Section
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
