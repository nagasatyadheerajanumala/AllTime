import SwiftUI
import Combine

/// Premium, minimal Meeting Clashes card - shows only the most urgent conflict
struct ClashesCardView: View {
    @StateObject private var viewModel = ClashesViewModel()
    @State private var showAllClashes = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.clashes.isEmpty {
                loadingView
            } else if viewModel.clashes.isEmpty {
                emptyView
            } else {
                // Show only the top clash
                if let topClash = viewModel.clashes.first {
                    clashCard(topClash)
                }
            }
        }
        .task {
            await viewModel.loadClashes()
        }
        .sheet(isPresented: $showAllClashes) {
            AllClashesSheet(viewModel: viewModel)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Checking for conflicts...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Empty State

    private var emptyView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("No Conflicts")
                    .font(.system(size: 16, weight: .semibold))
                Text("Your schedule is clear")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Clash Card

    private func clashCard(_ clash: ClashInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with count
            HStack {
                Label("Conflict", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)

                Spacer()

                if viewModel.totalClashes > 1 {
                    Button {
                        showAllClashes = true
                    } label: {
                        Text("\(viewModel.totalClashes) total")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }

            // The two conflicting events
            VStack(spacing: 12) {
                eventRow(clash.eventA, highlight: clash.recommendedKeep == clash.eventA.id)

                // Overlap indicator
                HStack {
                    Rectangle()
                        .fill(Color.orange.opacity(0.3))
                        .frame(height: 1)

                    Text("\(clash.overlapMinutes) min overlap")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)

                    Rectangle()
                        .fill(Color.orange.opacity(0.3))
                        .frame(height: 1)
                }

                eventRow(clash.eventB, highlight: clash.recommendedKeep == clash.eventB.id)
            }

            // Action button
            if let recommended = clash.recommendedResolution,
               let targetId = recommended.targetEventId {
                actionButton(option: recommended, eventId: targetId)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }

    // MARK: - Event Row

    private func eventRow(_ event: ClashEventInfo, highlight: Bool) -> some View {
        HStack(spacing: 12) {
            // Time column
            VStack(spacing: 2) {
                Text(formatTime(event.startTime))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                Text(formatTime(event.endTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)

            // Divider
            Rectangle()
                .fill(highlight ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 3)
                .cornerRadius(2)

            // Event info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(event.source)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    if highlight {
                        Text("Keep")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(highlight ? Color.green.opacity(0.05) : Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    // MARK: - Action Button

    private func actionButton(option: ResolutionOption, eventId: Int64) -> some View {
        Button {
            Task {
                await viewModel.resolveClash(eventId: eventId, action: option.isDecline ? "decline" : "reschedule")
            }
        } label: {
            HStack {
                if viewModel.isResolving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: option.icon)
                }

                Text(viewModel.isResolving ? "Resolving..." : option.label)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(.white)
            .background(option.isDecline ? Color.red : Color.blue)
            .cornerRadius(12)
        }
        .disabled(viewModel.isResolving)
    }

    // MARK: - Helpers

    private func formatTime(_ isoString: String) -> String {
        // Try ISO8601 with fractional seconds
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: isoString) {
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            return tf.string(from: date)
        }

        // Try without fractional seconds
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: isoString) {
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            return tf.string(from: date)
        }

        // Try simple format (no timezone)
        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = simple.date(from: String(isoString.prefix(19))) {
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            return tf.string(from: d)
        }

        // Manual extraction fallback
        if let tIndex = isoString.firstIndex(of: "T"),
           isoString.distance(from: tIndex, to: isoString.endIndex) >= 6 {
            let timeStart = isoString.index(after: tIndex)
            let timeEnd = isoString.index(timeStart, offsetBy: 5)
            let timeStr = String(isoString[timeStart..<timeEnd])
            if let hour = Int(timeStr.prefix(2)), let minute = Int(timeStr.suffix(2)) {
                let period = hour >= 12 ? "PM" : "AM"
                let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
                return String(format: "%d:%02d %@", hour12, minute, period)
            }
        }

        return "—"
    }
}

// MARK: - All Clashes Sheet

struct AllClashesSheet: View {
    @ObservedObject var viewModel: ClashesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.clashes) { clash in
                        compactClashRow(clash)
                    }
                }
                .padding()
            }
            .navigationTitle("All Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func compactClashRow(_ clash: ClashInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Events
            HStack {
                VStack(alignment: .leading) {
                    Text(clash.eventA.title)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    Text(formatTime(clash.eventA.startTime))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(clash.overlapMinutes)m")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(6)

                Spacer()

                VStack(alignment: .trailing) {
                    Text(clash.eventB.title)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    Text(formatTime(clash.eventB.startTime))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            // Quick action
            if let option = clash.recommendedResolution,
               let targetId = option.targetEventId {
                Button {
                    Task {
                        await viewModel.resolveClash(eventId: targetId, action: option.isDecline ? "decline" : "reschedule")
                    }
                } label: {
                    HStack {
                        Image(systemName: option.icon)
                            .font(.system(size: 12))
                        Text(option.label)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(option.isDecline ? .red : .blue)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func formatTime(_ isoString: String) -> String {
        // Try ISO8601 with fractional seconds
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: isoString) {
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            return tf.string(from: date)
        }

        // Try without fractional seconds
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: isoString) {
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            return tf.string(from: date)
        }

        // Try simple format
        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = simple.date(from: String(isoString.prefix(19))) {
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            return tf.string(from: d)
        }

        // Manual extraction fallback
        if let tIndex = isoString.firstIndex(of: "T"),
           isoString.distance(from: tIndex, to: isoString.endIndex) >= 6 {
            let timeStart = isoString.index(after: tIndex)
            let timeEnd = isoString.index(timeStart, offsetBy: 5)
            let timeStr = String(isoString[timeStart..<timeEnd])
            if let hour = Int(timeStr.prefix(2)), let minute = Int(timeStr.suffix(2)) {
                let period = hour >= 12 ? "PM" : "AM"
                let hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
                return String(format: "%d:%02d %@", hour12, minute, period)
            }
        }

        return "—"
    }
}

// MARK: - ViewModel

@MainActor
class ClashesViewModel: ObservableObject {
    @Published var clashes: [ClashInfo] = []
    @Published var totalClashes: Int = 0
    @Published var isLoading = false
    @Published var isResolving = false
    @Published var errorMessage: String?

    private let apiService = APIService()

    func loadClashes() async {
        isLoading = true

        do {
            let response = try await apiService.getMeetingClashes()
            totalClashes = response.effectiveTotalClashes

            // Flatten all clashes, sorted by importance
            clashes = response.clashesByDate.values
                .flatMap { $0 }
                .sorted { ($0.importanceScore ?? 5) > ($1.importanceScore ?? 5) }

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func resolveClash(eventId: Int64, action: String) async {
        isResolving = true

        do {
            let response = try await apiService.resolveClash(eventId: eventId, action: action)
            if response.success {
                await loadClashes()
            } else {
                errorMessage = response.error
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isResolving = false
    }
}

#Preview {
    VStack {
        ClashesCardView()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
