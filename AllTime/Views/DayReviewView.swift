import SwiftUI

/// End-of-day review view showing planned vs completed activities and reflection
struct DayReviewView: View {
    @StateObject private var viewModel = DayReviewViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.isLoading {
                        loadingView
                    } else if let error = viewModel.error {
                        errorView(error)
                    } else if let review = viewModel.dayReview {
                        headerSection(review)
                        completionCard(review)
                        activitiesSection(review)
                        reflectionSection
                    } else {
                        noPlanView
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Day Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadDayReview()
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    viewModel.dismissSuccess()
                }
            } message: {
                Text(viewModel.successMessage ?? "Saved!")
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your day...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(error)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await viewModel.loadDayReview()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - No Plan View

    private var noPlanView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No Plan Found")
                .font(.title2)
                .fontWeight(.semibold)
            Text("You didn't create a day plan for today. Use 'Plan Your Day' to generate activities!")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
    }

    // MARK: - Header Section

    private func headerSection(_ review: DayReviewResponse) -> some View {
        VStack(spacing: 8) {
            Text("How was your day?")
                .font(.title)
                .fontWeight(.bold)
            Text(viewModel.formattedDate)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Completion Card

    private func completionCard(_ review: DayReviewResponse) -> some View {
        VStack(spacing: 16) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: viewModel.completionRatio)
                    .stroke(
                        completionColor(for: review.completionPercentage),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: viewModel.completionRatio)

                VStack(spacing: 4) {
                    Text("\(review.completionPercentage)%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 120)

            // Summary message
            Text(review.summaryMessage)
                .font(.headline)
                .multilineTextAlignment(.center)

            // Stats row
            HStack(spacing: 32) {
                statItem(value: "\(review.totalCompleted)", label: "Done", color: .green)
                statItem(value: "\(review.totalPlanned - review.totalCompleted)", label: "Missed", color: .red)
                statItem(value: "\(review.totalPlanned)", label: "Planned", color: .blue)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func completionColor(for percentage: Int) -> Color {
        if percentage >= 75 {
            return .green
        } else if percentage >= 50 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Activities Section

    private func activitiesSection(_ review: DayReviewResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !viewModel.completedActivities.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)

                    ForEach(viewModel.completedActivities) { activity in
                        activityRow(activity, isCompleted: true)
                    }
                }
            }

            if !viewModel.missedActivities.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Missed", systemImage: "xmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.red)

                    ForEach(viewModel.missedActivities) { activity in
                        activityRow(activity, isCompleted: false)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private func activityRow(_ activity: ActivityStatus, isCompleted: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : .gray)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let time = activity.plannedTime {
                    Text(time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let location = activity.location {
                    Label(location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let category = activity.category {
                Text(category)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Reflection Section

    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How did today feel?")
                .font(.headline)

            // Rating buttons
            HStack(spacing: 16) {
                ForEach(DayRating.allCases, id: \.self) { rating in
                    ratingButton(rating)
                }
            }

            // Notes field
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (optional)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $viewModel.reflectionNotes)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }

            // Save button
            Button(action: {
                Task {
                    await viewModel.saveReflection()
                }
            }) {
                HStack {
                    if viewModel.isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(viewModel.hasExistingReflection ? "Update Reflection" : "Save Reflection")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.selectedRating.color)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isSaving)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private func ratingButton(_ rating: DayRating) -> some View {
        Button(action: {
            viewModel.selectedRating = rating
        }) {
            VStack(spacing: 8) {
                Text(rating.emoji)
                    .font(.system(size: 36))
                Text(rating.label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                viewModel.selectedRating == rating
                    ? rating.color.opacity(0.2)
                    : Color(.systemGray6)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        viewModel.selectedRating == rating ? rating.color : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DayReviewView()
}
