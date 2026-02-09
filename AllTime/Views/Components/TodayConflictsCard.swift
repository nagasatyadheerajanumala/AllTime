import SwiftUI

/// Shows today's meeting conflicts in TodayView.
/// Renders nothing when there are no conflicts.
struct TodayConflictsCard: View {
    @StateObject private var viewModel = MeetingClashesViewModel()
    @State private var showAllClashes = false

    private var todayClashes: [ClashInfo] {
        viewModel.clashesForDate(Date())
    }

    var body: some View {
        Group {
            if !todayClashes.isEmpty {
                VStack(spacing: 0) {
                    if let topClash = todayClashes.first {
                        CleanClashCard(
                            clash: topClash,
                            totalCount: todayClashes.count,
                            onSeeAll: { showAllClashes = true }
                        )
                    }
                }
                .sheet(isPresented: $showAllClashes) {
                    AllClashesView(clashes: todayClashes)
                }
            }
        }
        .task {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: Date())
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            await viewModel.loadClashes(startDate: start, endDate: end)
        }
    }
}
