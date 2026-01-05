import SwiftUI
import Combine

/// Timeline Day View - Chat-like feed for the day
struct TimelineDayView: View {
    @StateObject private var viewModel = TimelineDayViewModel()
    let date: Date
    
    init(date: Date = Date()) {
        self.date = date
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading timeline...")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else if let timeline = viewModel.timeline {
                    if timeline.items.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(DesignSystem.Colors.primary)
                            Text("Open day ahead")
                                .font(DesignSystem.Typography.title3)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            Text("This is rare. Block focus time before it fills with reactive work.")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else {
                        ForEach(timeline.items) { item in
                            TimelineItemRow(item: item)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                        }
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Error loading timeline")
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Text(errorMessage)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        
                        Button("Retry") {
                            Task {
                                await viewModel.loadTimeline(for: date)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    // Initial state - should trigger loading
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading timeline...")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                }
            }
            .padding(.bottom, 85)
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Always try to load when view appears
            if !viewModel.isLoading {
                Task {
                    await viewModel.loadTimeline(for: date)
                }
            }
        }
    }
}

// MARK: - Timeline Item Row
struct TimelineItemRow: View {
    let item: TimelineItem
    
    var body: some View {
        switch item {
        case .event(let event):
            EventTimelineRow(event: event)
        case .gap(let gap):
            GapTimelineRow(gap: gap)
        }
    }
}

// MARK: - Event Timeline Row
struct EventTimelineRow: View {
    let event: EventItem
    
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time
            if let startDate = Self.iso8601Formatter.date(from: event.startTime) {
                Text(Self.timeFormatter.string(from: startDate))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .frame(width: 60, alignment: .leading)
            }
            
            // Event content
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                if let context = event.context, !context.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 10))
                        Text(context.capitalized)
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(contextColor(for: context))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(contextColor(for: context).opacity(0.15))
                    .cornerRadius(6)
                }
                
                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 10))
                        Text(location)
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                
                if let provider = event.provider, !provider.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(Constants.Providers.displayName(for: provider))
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
    
    private func contextColor(for context: String) -> Color {
        switch context.lowercased() {
        case "meeting":
            return .blue
        case "deep_work", "deep work":
            return .purple
        case "social":
            return .green
        case "health":
            return .red
        default:
            return DesignSystem.Colors.primary
        }
    }
}

// MARK: - Gap Timeline Row
struct GapTimelineRow: View {
    let gap: GapItem
    
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time
            if let startDate = Self.iso8601Formatter.date(from: gap.startTime) {
                Text(Self.timeFormatter.string(from: startDate))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .frame(width: 60, alignment: .leading)
            }
            
            // Gap content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("Free for \(formatDuration(gap.durationMinutes))")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
                
                Text("Good slot for focused work or a break")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.green.opacity(0.08))
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours) hr"
            } else {
                return "\(hours) hr \(mins) min"
            }
        }
    }
}

// MARK: - Timeline Day View Model
@MainActor
class TimelineDayViewModel: ObservableObject {
    @Published var timeline: TimelineDayResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService()
    private let cacheService = CacheService.shared
    
    func loadTimeline(for date: Date) async {
        // Step 1: Load from disk cache first (instant UI update)
        if let cached = await cacheService.loadCachedTimeline(for: date) {
            await MainActor.run {
                self.timeline = cached
                self.isLoading = false
            }
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Step 2: Fetch from backend in background
        do {
            let fetchedTimeline = try await Task.detached { [apiService] in
                try await apiService.fetchDayTimeline(date: date)
            }.value
            
            // Save to disk cache
            await cacheService.cacheTimeline(fetchedTimeline, for: date)
            
            await MainActor.run {
                self.timeline = fetchedTimeline
                self.isLoading = false
                print("✅ TimelineDayViewModel: Loaded timeline with \(fetchedTimeline.items.count) items")
            }
        } catch {
            // On error, keep cached data if available
            await MainActor.run {
                if self.timeline == nil {
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
                print("❌ TimelineDayViewModel: Failed to load timeline: \(error.localizedDescription)")
            }
        }
    }
}

