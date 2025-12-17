import SwiftUI

/// A compact check-in card for the main view
struct MoodCheckInCardView: View {
    @StateObject private var viewModel = CheckInViewModel()
    @State private var showCheckInSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundColor(.pink)

                Text("How are you feeling?")
                    .font(.headline)

                Spacer()

                if let status = viewModel.checkInStatus, status.streakDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(status.streakDays)")
                            .font(.subheadline.bold())
                            .foregroundColor(.orange)
                    }
                }
            }

            // Quick mood selector
            if !viewModel.isCheckInDoneForCurrentPeriod {
                // Show energy prediction from HealthKit
                if viewModel.isPredictingEnergy {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Analyzing your health data...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                } else if let prediction = viewModel.energyPrediction {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Image(systemName: "waveform.path.ecg")
                                        .foregroundColor(.pink)
                                    Text("Your Energy:")
                                        .font(.subheadline)
                                    Text(prediction.energyDescription)
                                        .font(.subheadline.bold())
                                        .foregroundColor(energyColor(prediction.predictedEnergy))
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: prediction.confidence.icon)
                                        .font(.caption2)
                                    Text(prediction.confidence.description)
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Energy level bars
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(i <= prediction.predictedEnergy ? energyColor(prediction.predictedEnergy) : Color.gray.opacity(0.2))
                                        .frame(width: 6, height: 16)
                                }
                            }
                        }

                        // Show factors
                        if !prediction.factors.isEmpty {
                            HStack(spacing: 12) {
                                ForEach(prediction.factors.prefix(3), id: \.name) { factor in
                                    HStack(spacing: 4) {
                                        Image(systemName: factor.icon)
                                            .font(.caption2)
                                            .foregroundColor(factorColor(factor.impact))
                                        Text(factor.name)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                }

                // Mood selector
                HStack(spacing: 12) {
                    ForEach(MoodOption.allCases) { mood in
                        Button {
                            viewModel.selectedMood = mood
                            viewModel.energyLevel = moodToEnergy(mood)
                            Task {
                                await viewModel.submitQuickCheckIn()
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(mood.emoji)
                                    .font(.title)
                                Text(mood.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(viewModel.selectedMood == mood ?
                                          Color.blue.opacity(0.15) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isSubmitting)
                    }
                }

                // Detailed check-in link
                Button {
                    showCheckInSheet = true
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("More detailed check-in")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .padding(.top, 4)
            } else {
                // Already checked in
                Button {
                    showCheckInSheet = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("\(TimeOfDay.current.displayName) check-in complete!")
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)

                // Show suggestions if available
                if let suggestions = viewModel.suggestions, !suggestions.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text("Based on how you're feeling:")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }

                        ForEach(suggestions.suggestions.prefix(2)) { suggestion in
                            CompactSuggestionView(suggestion: suggestion)
                        }
                    }
                    .padding(.top, 4)
                } else if viewModel.isLoadingSuggestions {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading suggestions...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Energy Analysis from HealthKit
                if viewModel.isPredictingEnergy {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Analyzing health data...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let prediction = viewModel.energyPrediction {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.caption)
                                        .foregroundColor(.pink)
                                    Text("Your Energy:")
                                        .font(.caption)
                                    Text(prediction.energyDescription)
                                        .font(.caption.bold())
                                        .foregroundColor(energyColor(prediction.predictedEnergy))
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: prediction.confidence.icon)
                                        .font(.caption2)
                                    Text(prediction.confidence.description)
                                        .font(.caption2)
                                }
                                .foregroundColor(.secondary)
                            }

                            Spacer()

                            // Energy level bars
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(i <= prediction.predictedEnergy ? energyColor(prediction.predictedEnergy) : Color.gray.opacity(0.2))
                                        .frame(width: 5, height: 14)
                                }
                            }
                        }

                        // Show factors
                        if !prediction.factors.isEmpty {
                            HStack(spacing: 10) {
                                ForEach(prediction.factors.prefix(3), id: \.name) { factor in
                                    HStack(spacing: 3) {
                                        Image(systemName: factor.icon)
                                            .font(.caption2)
                                            .foregroundColor(factorColor(factor.impact))
                                        Text(factor.name)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .sheet(isPresented: $showCheckInSheet) {
            MoodCheckInSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.loadStatus()
        }
        .alert("Success!", isPresented: $viewModel.showSuccess) {
            Button("OK") {
                viewModel.dismissSuccess()
            }
        } message: {
            Text(viewModel.successMessage ?? "Check-in recorded")
        }
    }

    private func moodToEnergy(_ mood: MoodOption) -> Int {
        switch mood {
        case .great: return 5
        case .good: return 4
        case .okay: return 3
        case .tired: return 2
        case .stressed: return 2
        }
    }

    private func energyColor(_ level: Int) -> Color {
        switch level {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
        }
    }

    private func factorColor(_ impact: EnergyImpact) -> Color {
        switch impact {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .orange
        }
    }
}

/// Full check-in sheet with detailed options
struct MoodCheckInSheet: View {
    @ObservedObject var viewModel: CheckInViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Time of day
                Section {
                    Picker("Time of day", selection: $viewModel.selectedTimeOfDay) {
                        ForEach(TimeOfDay.allCases, id: \.self) { time in
                            Text(time.displayName).tag(time)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("When")
                }

                // Energy Level - Auto-predicted from HealthKit
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // Predicted energy display
                        if viewModel.isPredictingEnergy {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Analyzing your health data...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else if let prediction = viewModel.energyPrediction {
                            // Show prediction with confidence
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text("Predicted Energy:")
                                            .font(.subheadline)
                                        Text(prediction.energyDescription)
                                            .font(.subheadline.bold())
                                            .foregroundColor(energyColor(prediction.predictedEnergy))
                                    }

                                    HStack(spacing: 4) {
                                        Image(systemName: prediction.confidence.icon)
                                            .font(.caption2)
                                        Text(prediction.confidence.description)
                                            .font(.caption)
                                    }
                                    .foregroundColor(.secondary)
                                }

                                Spacer()

                                // Energy level indicator
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { i in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(i <= viewModel.energyLevel ? energyColor(viewModel.energyLevel) : Color.gray.opacity(0.2))
                                            .frame(width: 8, height: 20)
                                    }
                                }
                            }

                            // Factors that influenced the prediction
                            if !prediction.factors.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Based on:")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)

                                    ForEach(prediction.factors, id: \.name) { factor in
                                        HStack(spacing: 8) {
                                            Image(systemName: factor.icon)
                                                .font(.caption)
                                                .foregroundColor(factorImpactColor(factor.impact))
                                                .frame(width: 16)

                                            Text(factor.value)
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                        }
                                    }
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray6))
                                )
                            }

                            // Option to adjust
                            if viewModel.userOverrodeEnergy {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                    Text("Using your adjusted value")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Manual adjustment option
                        DisclosureGroup("Adjust energy level") {
                            HStack(spacing: 12) {
                                ForEach(1...5, id: \.self) { level in
                                    Button {
                                        viewModel.userDidOverrideEnergy(level)
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(viewModel.energyLevel >= level ?
                                                      energyColor(level) : Color.gray.opacity(0.2))
                                                .frame(width: 44, height: 44)
                                            Text("\(level)")
                                                .font(.headline)
                                                .foregroundColor(viewModel.energyLevel >= level ? .white : .gray)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                } header: {
                    HStack {
                        Text("Your Energy")
                        Spacer()
                        if viewModel.energyPrediction != nil {
                            Image(systemName: "waveform.path.ecg")
                                .font(.caption)
                                .foregroundColor(.pink)
                            Text("From HealthKit")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Mood
                Section {
                    HStack(spacing: 8) {
                        ForEach(MoodOption.allCases) { mood in
                            Button {
                                viewModel.selectedMood = mood
                            } label: {
                                VStack(spacing: 4) {
                                    Text(mood.emoji)
                                        .font(.title2)
                                    Text(mood.displayName)
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(viewModel.selectedMood == mood ?
                                              Color.blue.opacity(0.15) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(viewModel.selectedMood == mood ?
                                                Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Mood")
                }

                // Focus & Stress
                Section {
                    SliderRow(title: "Focus", value: $viewModel.focusLevel, range: 1...5)
                    SliderRow(title: "Stress", value: $viewModel.stressLevel, range: 1...5)
                } header: {
                    Text("Mental state")
                }

                // Morning-specific: Sleep
                if viewModel.selectedTimeOfDay == .morning {
                    Section {
                        HStack {
                            Text("Hours slept")
                            Spacer()
                            Text(String(format: "%.1f hrs", viewModel.sleepHours))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $viewModel.sleepHours, in: 3...12, step: 0.5)

                        SliderRow(title: "Sleep quality", value: $viewModel.sleepQuality, range: 1...5)
                    } header: {
                        Text("Last night's sleep")
                    }
                }

                // Evening-specific: Productivity
                if viewModel.selectedTimeOfDay == .evening {
                    Section {
                        SliderRow(title: "Today's productivity", value: $viewModel.productivityRating, range: 1...5)
                    } header: {
                        Text("Day review")
                    }
                }

                // Notes
                Section {
                    TextField("Any notes?", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes (optional)")
                }
            }
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            await viewModel.submitCheckIn()
                            if viewModel.error == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSubmitting)
                }
            }
            .overlay {
                if viewModel.isSubmitting {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func energyDescription(_ level: Int) -> String {
        switch level {
        case 1: return "Very low"
        case 2: return "Low"
        case 3: return "Moderate"
        case 4: return "Good"
        case 5: return "Excellent"
        default: return ""
        }
    }

    private func energyColor(_ level: Int) -> Color {
        switch level {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
        }
    }

    private func factorImpactColor(_ impact: EnergyImpact) -> Color {
        switch impact {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .orange
        }
    }
}

/// Reusable slider row for forms
struct SliderRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value)/\(range.upperBound)")
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(Array(range), id: \.self) { level in
                    Button {
                        value = level
                    } label: {
                        Circle()
                            .fill(value >= level ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    MoodCheckInCardView()
        .padding()
        .background(Color(.systemGroupedBackground))
}
