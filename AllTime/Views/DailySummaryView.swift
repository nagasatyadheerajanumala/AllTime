import SwiftUI

struct DailySummaryView: View {
    @EnvironmentObject var summaryViewModel: DailySummaryViewModel
    @State private var showingDatePicker = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Date Selector
                    HStack {
                        Button(action: {
                            showingDatePicker = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16, weight: .medium))
                                Text(summaryViewModel.selectedDate, style: .date)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(DesignSystem.Colors.primary)
                        }

                        Spacer()

                        Button(action: {
                            Task {
                                await summaryViewModel.refreshSummary()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.primary)
                                .rotationEffect(.degrees(summaryViewModel.isLoading ? 360 : 0))
                                .animation(summaryViewModel.isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: summaryViewModel.isLoading)
                        }
                        .disabled(summaryViewModel.isLoading)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Content
                    if summaryViewModel.isLoading && summaryViewModel.summary == nil {
                        LoadingView()
                            .padding(.top, 60)
                    } else if let summary = summaryViewModel.summary {
                        NewEnhancedSummaryContentView(
                            summary: summary,
                            parsed: summaryViewModel.parsedSummary,
                            waterGoal: summaryViewModel.waterGoal
                        )
                        .padding(.horizontal)
                    } else if let errorMessage = summaryViewModel.errorMessage {
                        ErrorView(message: errorMessage) {
                            Task {
                                await summaryViewModel.refreshSummary()
                            }
                        }
                        .padding(.top, 60)
                    } else {
                        EmptyStateView()
                            .padding(.top, 60)
                    }
                }
                .padding(.bottom, 85) // Reserve space for tab bar
            }
            .navigationTitle("Daily Summary")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(selectedDate: $summaryViewModel.selectedDate)
            }
            .onAppear {
                if summaryViewModel.summary == nil {
                    Task {
                        await summaryViewModel.loadSummary(for: summaryViewModel.selectedDate)
                    }
                }
            }
            .onChange(of: summaryViewModel.selectedDate) { oldDate, newDate in
                Task {
                    await summaryViewModel.loadSummary(for: newDate)
                }
            }
        }
    }
}

// MARK: - New Enhanced Summary Content View

struct NewEnhancedSummaryContentView: View {
    let summary: DailySummary
    let parsed: ParsedSummary
    let waterGoal: Double?

    var body: some View {
        PremiumSummaryContentView(
            summary: summary,
            parsed: parsed,
            waterGoal: waterGoal
        )
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(DesignSystem.Colors.primary)

            Text("Generating your daily summary...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Unable to load summary")
                .font(.title3)
                .foregroundColor(.primary)

            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 50))
                .foregroundColor(DesignSystem.Colors.primary.opacity(0.6))

            Text("No summary available")
                .font(.title3)
                .foregroundColor(.primary)

            Text("Your daily summary will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DailySummaryView()
        .environmentObject(DailySummaryViewModel())
}
