import SwiftUI

struct WalkRecommendationsView: View {
    @StateObject private var viewModel = WalkRecommendationsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRoute: WalkRouteRecommendation?
    @State private var showingMapOptions = false

    // Block time properties
    var suggestedStartTime: Date?
    var suggestedEndTime: Date?
    var suggestionTitle: String?
    @State private var isBlockingTime = false
    @State private var showBlockTimeSuccess = false
    @State private var showBlockTimeError = false
    @State private var blockTimeMessage: String = ""
    @State private var focusModeUrl: String?

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Block Time Card (if times are available)
                        if suggestedStartTime != nil {
                            blockTimeCard
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Duration/Distance Filter Card
                        durationFilterCard
                            .transition(.move(edge: .top).combined(with: .opacity))

                        // Difficulty Filter
                        difficultyFilterCard
                            .transition(.move(edge: .top).combined(with: .opacity))

                        // Health Benefit Banner
                        if let benefit = viewModel.healthBenefit {
                            healthBenefitBanner(benefit)
                                .transition(.opacity)
                        }

                        // Content
                        if viewModel.isLoading {
                            loadingView
                                .transition(.opacity)
                        } else if let error = viewModel.errorMessage {
                            errorView(error)
                                .transition(.opacity)
                        } else if viewModel.hasResults {
                            routeTypeSectionsView
                                .transition(.opacity)
                        } else {
                            emptyStateView
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Walk Routes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
        .task {
            await viewModel.loadRecommendations()
        }
        .confirmationDialog("Open Route", isPresented: $showingMapOptions, presenting: selectedRoute) { route in
            Button("Apple Maps") {
                openInAppleMaps(route: route)
            }
            Button("Google Maps") {
                openInGoogleMaps(route: route)
            }
            Button("Cancel", role: .cancel) {}
        } message: { route in
            Text("Navigate \(route.name)")
        }
        .alert("Walk Time Blocked!", isPresented: $showBlockTimeSuccess) {
            Button("OK") {}
            if focusModeUrl != nil {
                Button("Enable Focus Mode") {
                    FocusTimeService.shared.triggerFocusModeShortcut(shortcutUrl: focusModeUrl)
                }
            }
        } message: {
            Text(blockTimeMessage)
        }
        .alert("Unable to Block Time", isPresented: $showBlockTimeError) {
            Button("OK") {}
        } message: {
            Text(blockTimeMessage)
        }
    }

    // MARK: - Block Time Card
    private var blockTimeCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.green)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Block Walk Time")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    if let start = suggestedStartTime, let end = suggestedEndTime {
                        Text(formatTimeRange(start: start, end: end))
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                Spacer()

                // Block Time Button
                Button(action: blockTime) {
                    if isBlockingTime {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 20, height: 20)
                    } else {
                        Text("Block Time")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.green)
                .cornerRadius(10)
                .disabled(isBlockingTime)
            }

            // Info text
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text("Add this time to your calendar so others know you're taking a walk")
                    .font(.caption)
            }
            .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private func blockTime() {
        guard !isBlockingTime else { return }

        let start = suggestedStartTime ?? Date()
        let end = suggestedEndTime ?? start.addingTimeInterval(1800) // Default 30 min for walks
        let title = suggestionTitle ?? "Walk Break"

        isBlockingTime = true

        Task {
            do {
                let response = try await FocusTimeService.shared.blockFocusTime(
                    start: start,
                    end: end,
                    title: title,
                    enableFocusMode: false
                )

                await MainActor.run {
                    isBlockingTime = false
                    if response.success {
                        blockTimeMessage = response.message ?? "Walk time added to your calendar."
                        focusModeUrl = response.focusMode?.shortcutUrl
                        showBlockTimeSuccess = true
                    } else {
                        blockTimeMessage = response.message ?? "Failed to create calendar event."
                        showBlockTimeError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isBlockingTime = false
                    blockTimeMessage = error.localizedDescription
                    showBlockTimeError = true
                }
            }
        }
    }

    // MARK: - Duration Filter Card
    private var durationFilterCard: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Walk Duration")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(viewModel.selectedDuration)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .contentTransition(.numericText())

                        Text("minutes")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                Spacer()

                // Distance & Calories estimate
                VStack(spacing: 8) {
                    VStack(spacing: 2) {
                        Image(systemName: "ruler")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.green)
                        Text(String(format: "~%.1f mi", viewModel.targetDistanceMiles))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.green.opacity(0.12))
                    )

                    Text("~\(viewModel.selectedDuration * 5) cal")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }

            // Duration Chips
            HStack(spacing: 8) {
                ForEach(viewModel.durationOptions, id: \.self) { duration in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.updateDuration(duration)
                        }
                    } label: {
                        Text("\(duration)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        viewModel.selectedDuration == duration
                                        ? Color.green
                                        : DesignSystem.Colors.cardBackgroundElevated
                                    )
                            )
                            .foregroundColor(
                                viewModel.selectedDuration == duration
                                ? .white
                                : DesignSystem.Colors.secondaryText
                            )
                            .scaleEffect(viewModel.selectedDuration == duration ? 1.05 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Location info
            if let location = viewModel.userLocation {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text("Starting from \(location)")
                        .font(.caption)
                }
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignSystem.Colors.cardBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
    }

    // MARK: - Difficulty Filter Card
    private var difficultyFilterCard: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Intensity Level")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                Spacer()

                // Current selection description
                Text(viewModel.selectedDifficulty.description)
                    .font(.caption)
                    .foregroundColor(viewModel.selectedDifficulty.color)
            }

            // Difficulty options
            HStack(spacing: 12) {
                ForEach(WalkDifficulty.allCases, id: \.self) { difficulty in
                    difficultyButton(for: difficulty)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignSystem.Colors.cardBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
    }

    private func difficultyButton(for difficulty: WalkDifficulty) -> some View {
        let isSelected = viewModel.selectedDifficulty == difficulty

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                viewModel.updateDifficulty(difficulty)
            }
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? difficulty.color : difficulty.color.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: difficulty.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : difficulty.color)
                }

                Text(difficulty.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? difficulty.color.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? difficulty.color.opacity(0.3) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Health Benefit Banner
    private func healthBenefitBanner(_ benefit: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundColor(.red)

            Text(benefit)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Route Type Sections View
    private var routeTypeSectionsView: some View {
        VStack(spacing: 24) {
            // Group routes by type
            let parkRoutes = viewModel.walkRoutes.filter { $0.routeType?.lowercased() == "park" }
            let neighborhoodRoutes = viewModel.walkRoutes.filter { $0.routeType?.lowercased() == "neighborhood" }
            let urbanRoutes = viewModel.walkRoutes.filter { $0.routeType?.lowercased() == "urban" }
            let otherRoutes = viewModel.walkRoutes.filter {
                let type = $0.routeType?.lowercased()
                return type != "park" && type != "neighborhood" && type != "urban"
            }

            if !parkRoutes.isEmpty {
                RouteTypeSectionView(
                    title: "Park Routes",
                    subtitle: "Green spaces & nature",
                    icon: "leaf.fill",
                    iconColor: .green,
                    routes: parkRoutes,
                    onRouteTap: { route in
                        selectedRoute = route
                        showingMapOptions = true
                    }
                )
            }

            if !neighborhoodRoutes.isEmpty {
                RouteTypeSectionView(
                    title: "Neighborhood",
                    subtitle: "Explore your local area",
                    icon: "house.fill",
                    iconColor: Color(hex: "F59E0B"),
                    routes: neighborhoodRoutes,
                    onRouteTap: { route in
                        selectedRoute = route
                        showingMapOptions = true
                    }
                )
            }

            if !urbanRoutes.isEmpty {
                RouteTypeSectionView(
                    title: "Urban Discovery",
                    subtitle: "City streets & shops",
                    icon: "building.2.fill",
                    iconColor: DesignSystem.Colors.primary,
                    routes: urbanRoutes,
                    onRouteTap: { route in
                        selectedRoute = route
                        showingMapOptions = true
                    }
                )
            }

            if !otherRoutes.isEmpty {
                RouteTypeSectionView(
                    title: "Other Routes",
                    subtitle: "More walking options",
                    icon: "figure.walk",
                    iconColor: Color(hex: "8B5CF6"),
                    routes: otherRoutes,
                    onRouteTap: { route in
                        selectedRoute = route
                        showingMapOptions = true
                    }
                )
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.3)

            Text("Finding walking routes...")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Error View
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.orange)

            Text("Unable to load routes")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(error)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.refreshRecommendations() }
            } label: {
                Text("Try Again")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(DesignSystem.Colors.primary)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.walk")
                .font(.system(size: 44))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            Text("No routes found")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Try adjusting the duration or difficulty")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Maps Functions
    private func openInAppleMaps(route: WalkRouteRecommendation) {
        // Use waypoints if available
        if let waypoints = route.waypoints, let firstWaypoint = waypoints.first,
           let lat = firstWaypoint.latitude, let lon = firstWaypoint.longitude {
            let encodedName = route.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "maps://?ll=\(lat),\(lon)&q=\(encodedName)") {
                UIApplication.shared.open(url)
                return
            }
        }

        // Fallback to search
        let encodedQuery = route.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encodedQuery)") {
            UIApplication.shared.open(url)
        }
    }

    private func openInGoogleMaps(route: WalkRouteRecommendation) {
        // Use mapUrl if available
        if let mapUrlString = route.mapUrl, let url = URL(string: mapUrlString) {
            UIApplication.shared.open(url)
            return
        }

        // Use waypoints if available
        if let waypoints = route.waypoints, let firstWaypoint = waypoints.first,
           let lat = firstWaypoint.latitude, let lon = firstWaypoint.longitude {
            // Try Google Maps app first
            if let url = URL(string: "comgooglemaps://?center=\(lat),\(lon)&zoom=15"),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
            // Fall back to web
            if let url = URL(string: "https://www.google.com/maps/@\(lat),\(lon),15z") {
                UIApplication.shared.open(url)
                return
            }
        }

        // Fallback to search
        let encodedQuery = route.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedQuery)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Route Type Section View
struct RouteTypeSectionView: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let routes: [WalkRouteRecommendation]
    let onRouteTap: (WalkRouteRecommendation) -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(iconColor)
                    }

                    // Title and subtitle
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    Spacer()

                    // Count badge
                    Text("\(routes.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(iconColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(iconColor.opacity(0.15))
                        )

                    // Chevron
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
            .buttonStyle(.plain)

            // Routes List
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(routes) { route in
                        WalkRouteCard(route: route) {
                            onRouteTap(route)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .padding(.top, 12)
            }
        }
    }
}

// MARK: - Walk Route Card
struct WalkRouteCard: View {
    let route: WalkRouteRecommendation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header row
                HStack(spacing: 12) {
                    // Route type icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(route.difficultyColor.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: route.routeTypeIcon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(route.difficultyColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .lineLimit(1)

                        if let description = route.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    // Navigate icon
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(route.difficultyColor)
                }

                // Stats row
                HStack(spacing: 16) {
                    // Distance
                    if !route.formattedDistance.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "ruler")
                                .font(.system(size: 11))
                            Text(route.formattedDistance)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    // Duration
                    if !route.formattedDuration.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text(route.formattedDuration)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.primary)
                    }

                    // Elevation
                    if let elevation = route.elevationGain, elevation > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11))
                            Text(String(format: "%.0f ft", elevation * 3.28084))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    Spacer()

                    // Difficulty badge
                    if let difficulty = route.difficulty {
                        Text(difficulty.capitalized)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(route.difficultyColor)
                            .cornerRadius(6)
                    }
                }

                // Highlights
                if let highlights = route.highlights, !highlights.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(highlights.prefix(4), id: \.self) { highlight in
                                Text(highlight)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(route.difficultyColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(route.difficultyColor.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }

                // Accessibility & Best time
                HStack(spacing: 12) {
                    if route.wheelchairAccessible == true {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.roll")
                                .font(.system(size: 10))
                            Text("Accessible")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.green)
                    }

                    if let bestTime = route.bestTimeOfDay, bestTime != "anytime" {
                        HStack(spacing: 4) {
                            Image(systemName: "sun.max")
                                .font(.system(size: 10))
                            Text("Best: \(bestTime)")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.cardBackgroundElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(route.difficultyColor.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    WalkRecommendationsView()
}
