import SwiftUI
import Combine

/// Card view showing meeting clashes on TodayView
struct ClashesCardView: View {
    @StateObject private var viewModel = ClashesViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)

                Text("Meeting Clashes")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if viewModel.isLoading && viewModel.clashDays.isEmpty {
                HStack {
                    Spacer()
                    Text("Checking for clashes...")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if viewModel.clashDays.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        Text("No conflicts this week")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                // Show clashes
                ForEach(viewModel.clashDays.prefix(3)) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        // Date label
                        Text(day.isToday ? "Today" : (day.isTomorrow ? "Tomorrow" : day.displayDate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)

                        // Clash items
                        ForEach(day.clashes.prefix(2)) { clash in
                            ClashRowView(clash: clash)
                        }

                        if day.clashes.count > 2 {
                            Text("+\(day.clashes.count - 2) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if viewModel.totalClashes > 3 {
                    Text("View all \(viewModel.totalClashes) clashes")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .task {
            await viewModel.loadClashes()
        }
    }
}

/// Row view for a single clash
struct ClashRowView: View {
    let clash: ClashInfo

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Severity indicator
            Circle()
                .fill(clash.severityColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                // Event names
                Text("\(clash.eventA.title) & \(clash.eventB.title)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                // Overlap info
                HStack(spacing: 4) {
                    Text(clash.overlapText)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("\u{2022}")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(clash.eventA.formattedTimeRange)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

/// ViewModel for managing clashes
@MainActor
class ClashesViewModel: ObservableObject {
    @Published var clashDays: [ClashDay] = []
    @Published var totalClashes: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService()

    func loadClashes() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiService.getMeetingClashes()
            totalClashes = response.effectiveTotalClashes

            // Convert to ClashDay array, sorted by date
            clashDays = response.clashesByDate.map { date, clashes in
                ClashDay(date: date, clashes: clashes)
            }.sorted { $0.date < $1.date }

        } catch {
            errorMessage = error.localizedDescription
            print("Failed to load clashes: \(error)")
        }

        isLoading = false
    }
}

#Preview {
    ClashesCardView()
        .padding()
        .background(Color(.systemGroupedBackground))
}
