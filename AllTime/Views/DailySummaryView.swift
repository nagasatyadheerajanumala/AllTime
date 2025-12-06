import SwiftUI

// NOTE: This view is deprecated. The daily summary is now integrated into TodayView.
// The new API (/api/v1/daily-summary) returns today's summary with location recommendations.

struct DailySummaryView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "calendar.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("Daily Summary")
                    .font(.title.weight(.bold))
                
                Text("Your daily summary is now integrated into the Today tab for a better experience.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .navigationTitle("Daily Summary")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
