import SwiftUI

struct HealthGoalsView: View {
    @StateObject private var viewModel = HealthGoalsViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Official Chrona Dark Theme Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                Form {
                Section {
                    Text("Set your health goals to receive personalized AI suggestions tailored to your targets.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                
                Section("Sleep") {
                    GoalField(
                        label: "Sleep Hours",
                        value: $viewModel.sleepHours,
                        unit: "hours",
                        range: 4...12,
                        step: 0.5
                    )
                }
                
                Section("Activity") {
                    GoalField(
                        label: "Daily Steps",
                        value: Binding(
                            get: { Double(viewModel.steps) },
                            set: { viewModel.steps = Int($0) }
                        ),
                        unit: "steps",
                        range: 1000...30000,
                        step: 500
                    )
                    
                    GoalField(
                        label: "Active Minutes",
                        value: Binding(
                            get: { Double(viewModel.activeMinutes) },
                            set: { viewModel.activeMinutes = Int($0) }
                        ),
                        unit: "minutes",
                        range: 10...180,
                        step: 5
                    )
                    
                    GoalField(
                        label: "Active Energy",
                        value: $viewModel.activeEnergyBurned,
                        unit: "kcal",
                        range: 100...2000,
                        step: 50
                    )
                }
                
                Section("Heart Health") {
                    GoalField(
                        label: "Resting Heart Rate",
                        value: $viewModel.restingHeartRate,
                        unit: "bpm",
                        range: 40...100,
                        step: 1
                    )
                    
                    GoalField(
                        label: "HRV",
                        value: $viewModel.hrv,
                        unit: "ms",
                        range: 20...100,
                        step: 1
                    )
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(DesignSystem.Typography.caption)
                    }
                }
            }
            .navigationTitle("Health Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        print("💾 HealthGoalsView: Save button tapped")
                        print("💾 HealthGoalsView: Current state - hasChanges: \(viewModel.hasChanges), isSaving: \(viewModel.isSaving)")
                        Task { @MainActor in
                            await viewModel.saveGoals()
                            print("💾 HealthGoalsView: Save completed, saveSuccess = \(viewModel.saveSuccess)")
                            if viewModel.saveSuccess {
                                // Small delay to show success feedback
                                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                                dismiss()
                            } else {
                                print("⚠️ HealthGoalsView: Save did not succeed, error: \(viewModel.errorMessage ?? "unknown")")
                            }
                        }
                    }
                    .disabled(viewModel.isSaving || !viewModel.hasChanges)
                    .onChange(of: viewModel.hasChanges) { newValue in
                        print("💾 HealthGoalsView: hasChanges changed to: \(newValue)")
                    }
                    .onChange(of: viewModel.isSaving) { newValue in
                        print("💾 HealthGoalsView: isSaving changed to: \(newValue)")
                    }
                }
            }
            .onAppear {
                // Only load if we don't have goals yet (to preserve user input)
                // But if we just saved successfully, don't reload to avoid overwriting
                if viewModel.goals == nil && !viewModel.saveSuccess {
                    Task {
                        await viewModel.loadGoals()
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading goals...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DesignSystem.Colors.background.opacity(0.9))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                } else if viewModel.isSaving {
                    ProgressView("Saving goals...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DesignSystem.Colors.background.opacity(0.9))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
            }
            }
        }
    }
}

// MARK: - Goal Field

struct GoalField: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let range: ClosedRange<Double>
    let step: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: formatString, value))
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primary)
                    
                    Text(unit)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            
            Slider(value: $value, in: range, step: step)
                .tint(DesignSystem.Colors.primary)
        }
        .padding(.vertical, 4)
    }
    
    private var formatString: String {
        if step < 1 {
            return "%.1f"
        } else {
            return "%.0f"
        }
    }
}

#Preview {
    HealthGoalsView()
}

