import SwiftUI

struct FoodRecommendationsView: View {
    @StateObject private var viewModel = FoodRecommendationsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSpot: FoodSpot?
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

                        // Distance Filter Card
                        distanceFilterCard
                            .transition(.move(edge: .top).combined(with: .opacity))

                        // Content
                        if viewModel.isLoading {
                            loadingView
                                .transition(.opacity)
                        } else if let error = viewModel.errorMessage {
                            errorView(error)
                                .transition(.opacity)
                        } else if viewModel.hasResults {
                            dietarySectionsView
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
            .navigationTitle("Food Nearby")
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
        .confirmationDialog("Open in Maps", isPresented: $showingMapOptions, presenting: selectedSpot) { spot in
            Button("Apple Maps") {
                openInAppleMaps(spot: spot)
            }
            Button("Google Maps") {
                openInGoogleMaps(spot: spot)
            }
            Button("Cancel", role: .cancel) {}
        } message: { spot in
            Text("Navigate to \(spot.name)")
        }
        .alert("Lunch Break Blocked!", isPresented: $showBlockTimeSuccess) {
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
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.orange)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Block Lunch Break")
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
                .background(Color.orange)
                .cornerRadius(10)
                .disabled(isBlockingTime)
            }

            // Info text
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text("Add this time to your calendar so others know you're taking a break")
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
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
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
        let end = suggestedEndTime ?? start.addingTimeInterval(3600)
        let title = suggestionTitle ?? "Lunch Break"

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
                        blockTimeMessage = response.message ?? "Lunch break added to your calendar."
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

    // MARK: - Distance Filter Card
    private var distanceFilterCard: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search Radius")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", viewModel.maxDistanceMiles))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .contentTransition(.numericText())

                        Text("miles")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                Spacer()

                // Walk time estimate
                VStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)

                    Text("~\(Int(viewModel.maxDistanceMiles * 20)) min")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                .padding(14)
                .background(
                    Circle()
                        .fill(DesignSystem.Colors.primary.opacity(0.12))
                )
            }

            // Slider
            VStack(spacing: 8) {
                Slider(
                    value: $viewModel.maxDistanceMiles,
                    in: 0.25...3.0,
                    step: 0.25
                )
                .tint(DesignSystem.Colors.primary)
                .onChange(of: viewModel.maxDistanceMiles) { _ in
                    Task {
                        await viewModel.loadRecommendations()
                    }
                }

                // Distance markers
                HStack {
                    Text("0.25")
                    Spacer()
                    Text("1.5")
                    Spacer()
                    Text("3.0")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            // Location info
            if let location = viewModel.userLocation {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text(location)
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

    // MARK: - Dietary Sections View
    private var dietarySectionsView: some View {
        VStack(spacing: 24) {
            // Healthy Options Section
            if !viewModel.healthyOptions.isEmpty {
                DietarySectionView(
                    title: "Healthy Options",
                    icon: "leaf.fill",
                    iconColor: .green,
                    spots: viewModel.healthyOptions,
                    onSpotTap: { spot in
                        selectedSpot = spot
                        showingMapOptions = true
                    }
                )
            }

            // Group by dietary tags
            let veganSpots = viewModel.foodSpots.filter { $0.dietaryTags?.contains("vegan") == true }
            let vegetarianSpots = viewModel.foodSpots.filter {
                $0.dietaryTags?.contains("vegetarian") == true && $0.dietaryTags?.contains("vegan") != true
            }
            let glutenFreeSpots = viewModel.foodSpots.filter { $0.dietaryTags?.contains("gluten-free") == true }
            let organicSpots = viewModel.foodSpots.filter { $0.dietaryTags?.contains("organic") == true }

            if !veganSpots.isEmpty {
                DietarySectionView(
                    title: "Vegan",
                    icon: "sparkle",
                    iconColor: Color(hex: "10B981"),
                    spots: veganSpots,
                    onSpotTap: { spot in
                        selectedSpot = spot
                        showingMapOptions = true
                    }
                )
            }

            if !vegetarianSpots.isEmpty {
                DietarySectionView(
                    title: "Vegetarian",
                    icon: "carrot.fill",
                    iconColor: Color(hex: "F59E0B"),
                    spots: vegetarianSpots,
                    onSpotTap: { spot in
                        selectedSpot = spot
                        showingMapOptions = true
                    }
                )
            }

            if !glutenFreeSpots.isEmpty {
                DietarySectionView(
                    title: "Gluten-Free",
                    icon: "checkmark.seal.fill",
                    iconColor: Color(hex: "8B5CF6"),
                    spots: glutenFreeSpots,
                    onSpotTap: { spot in
                        selectedSpot = spot
                        showingMapOptions = true
                    }
                )
            }

            if !organicSpots.isEmpty {
                DietarySectionView(
                    title: "Organic",
                    icon: "leaf.arrow.circlepath",
                    iconColor: Color(hex: "059669"),
                    spots: organicSpots,
                    onSpotTap: { spot in
                        selectedSpot = spot
                        showingMapOptions = true
                    }
                )
            }

            // Regular Options Section
            if !viewModel.regularOptions.isEmpty {
                DietarySectionView(
                    title: "All Nearby",
                    icon: "fork.knife",
                    iconColor: DesignSystem.Colors.primary,
                    spots: viewModel.regularOptions,
                    onSpotTap: { spot in
                        selectedSpot = spot
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

            Text("Finding nearby places...")
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

            Text("Unable to load")
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
            Image(systemName: "fork.knife")
                .font(.system(size: 44))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            Text("No places found")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Try increasing the search radius")
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
    private func openInAppleMaps(spot: FoodSpot) {
        if let lat = spot.latitude, let lon = spot.longitude {
            let encodedName = spot.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "maps://?ll=\(lat),\(lon)&q=\(encodedName)") {
                UIApplication.shared.open(url)
                return
            }
        }

        var searchQuery = spot.name
        if let address = spot.address {
            searchQuery += " \(address)"
        }
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encodedQuery)") {
            UIApplication.shared.open(url)
        }
    }

    private func openInGoogleMaps(spot: FoodSpot) {
        // Use mapUrl from API if available (preferred - includes placeId for deep linking)
        if let mapUrlString = spot.mapUrl, let url = URL(string: mapUrlString) {
            UIApplication.shared.open(url)
            return
        }

        // Fallback: construct URL from coordinates
        if let lat = spot.latitude, let lon = spot.longitude {
            let encodedName = spot.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            // Try Google Maps app first
            if let url = URL(string: "comgooglemaps://?center=\(lat),\(lon)&q=\(encodedName)"),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
            // Fall back to web
            if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(lat),\(lon)") {
                UIApplication.shared.open(url)
                return
            }
        }

        // Final fallback: search by name
        var searchQuery = spot.name
        if let address = spot.address {
            searchQuery += " \(address)"
        }
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encodedQuery)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Dietary Section View
struct DietarySectionView: View {
    let title: String
    let icon: String
    let iconColor: Color
    let spots: [FoodSpot]
    let onSpotTap: (FoodSpot) -> Void

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
                            .frame(width: 40, height: 40)

                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(iconColor)
                    }

                    // Title and count
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        Text("\(spots.count) places")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    Spacer()

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

            // Spots List
            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(spots) { spot in
                        FoodSpotCard(spot: spot) {
                            onSpotTap(spot)
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

// MARK: - Food Spot Card
struct FoodSpotCard: View {
    let spot: FoodSpot
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Photo or placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(spot.healthScoreColor.opacity(0.15))
                        .frame(width: 64, height: 64)

                    if let photoUrl = spot.photoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            default:
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 22))
                                    .foregroundColor(spot.healthScoreColor)
                            }
                        }
                    } else {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 22))
                            .foregroundColor(spot.healthScoreColor)
                    }
                }

                // Details
                VStack(alignment: .leading, spacing: 6) {
                    // Name
                    Text(spot.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)

                    // Cuisine
                    if let cuisine = spot.cuisine {
                        Text(cuisine)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }

                    // Stats row
                    HStack(spacing: 12) {
                        // Distance
                        if !spot.formattedDistance.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9))
                                Text(spot.formattedDistance)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        }

                        // Walk time
                        if !spot.formattedWalkTime.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 9))
                                Text(spot.formattedWalkTime)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        }

                        // Rating
                        if let rating = spot.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                        }
                    }
                }

                Spacer()

                // Right side: Price + Open status + Chevron
                VStack(alignment: .trailing, spacing: 8) {
                    // Price level
                    if !spot.priceLevelDisplay.isEmpty {
                        Text(spot.priceLevelDisplay)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                    }

                    // Open status
                    if let openNow = spot.openNow {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(openNow ? Color.green : Color.red)
                                .frame(width: 6, height: 6)
                            Text(openNow ? "Open" : "Closed")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(openNow ? .green : .red)
                        }
                    }

                    // Navigate icon
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.cardBackgroundElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DesignSystem.Colors.tertiaryText.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    FoodRecommendationsView()
}
