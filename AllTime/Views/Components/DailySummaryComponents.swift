import SwiftUI

// MARK: - AI Narrative Summary Section (for AI-generated paragraphs)
struct AINarrativeSummarySection: View {
    let paragraphs: [String]
    let title: String
    let icon: String
    let accentColor: Color
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with expand/collapse
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.title3.weight(.bold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                        VStack(alignment: .leading, spacing: 8) {
                            // First paragraph gets larger font for emphasis
                            Text(paragraph)
                                .font(index == 0 ? .body.weight(.medium) : .body)
                                .foregroundColor(index == 0 ? DesignSystem.Colors.primaryText : DesignSystem.Colors.secondaryText)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)

                            // Add divider between paragraphs (except last)
                            if index < paragraphs.count - 1 {
                                Divider()
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Daily Summary Section (Legacy - for bullet points)
struct DailySummarySectionView: View {
    let items: [String]
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text(item)
                            .font(.body)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Alerts Section (Enhanced for AI summaries)
struct AlertsSectionView: View {
    let alerts: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Important Alerts", systemImage: "exclamationmark.triangle.fill")
                .font(.title3.weight(.bold))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(alerts, id: \.self) { alert in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: getSeverityIcon(for: alert))
                            .foregroundColor(getSeverityColor(for: alert))
                            .font(.body)
                            .frame(width: 24)

                        Text(alert)
                            .font(.body)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
            )
        }
    }

    private func getSeverityIcon(for alert: String) -> String {
        if alert.contains("🚨") || alert.lowercased().contains("critical") {
            return "exclamationmark.octagon.fill"
        } else if alert.contains("⚠️") || alert.lowercased().contains("warning") {
            return "exclamationmark.triangle.fill"
        } else if alert.contains("💧") || alert.lowercased().contains("dehydration") {
            return "drop.fill"
        } else {
            return "info.circle.fill"
        }
    }

    private func getSeverityColor(for alert: String) -> Color {
        if alert.contains("🚨") || alert.lowercased().contains("critical") {
            return .red
        } else if alert.contains("⚠️") {
            return .orange
        } else if alert.contains("💧") {
            return .blue
        } else {
            return .yellow
        }
    }
}

// MARK: - AI Loading View
struct AILoadingView: View {
    @State private var animationPhase = 0

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Pulsing circles
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(DesignSystem.Colors.primary.opacity(0.3), lineWidth: 2)
                        .frame(width: 60 + CGFloat(index * 20), height: 60 + CGFloat(index * 20))
                        .scaleEffect(animationPhase == index ? 1.2 : 1.0)
                        .opacity(animationPhase == index ? 0.3 : 0.6)
                }

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 36))
                    .foregroundColor(DesignSystem.Colors.primary)
            }
            .frame(height: 120)

            VStack(spacing: 12) {
                Text("Generating Your AI Summary")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text("Analyzing your schedule, health data, and patterns...\nThis may take 3-10 seconds")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                // Progress indicator
                ProgressView()
                    .tint(DesignSystem.Colors.primary)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animationPhase = 0
            }
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    animationPhase = (animationPhase + 1) % 3
                }
            }
        }
    }
}

// MARK: - Health Suggestions
struct HealthSuggestionsView: View {
    let suggestions: [DailyHealthSuggestion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💡 Health Suggestions")
                .font(.title3.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            VStack(spacing: 12) {
                ForEach(suggestions) { suggestion in
                    HealthSuggestionCard(suggestion: suggestion)
                }
            }
        }
    }
}

struct HealthSuggestionCard: View {
    let suggestion: DailyHealthSuggestion
    
    private var categoryColor: Color {
        switch suggestion.category.lowercased() {
        case "exercise", "movement": return .orange
        case "nutrition", "hydration": return .green
        case "sleep": return .purple
        case "stress": return .red
        default: return .blue
        }
    }
    
    private var priorityColor: Color {
        switch suggestion.priority.lowercased() {
        case "high", "urgent": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .blue
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let icon = suggestion.icon {
                        Text(icon)
                            .font(.caption)
                    }
                    Text(suggestion.category.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(categoryColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(categoryColor.opacity(0.15))
                .cornerRadius(4)
                
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text(suggestion.description)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Text(suggestion.priority.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(priorityColor.opacity(0.2))
                .foregroundColor(priorityColor)
                .cornerRadius(3)
        }
        .padding()
        .background(priorityColor.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Lunch Spots
struct LunchSpotsView: View {
    let spots: [LunchPlace]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🍽️ Lunch Spots")
                .font(.title3.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            if !spots.isEmpty {
                VStack(spacing: 8) {
                    ForEach(spots.prefix(3)) { spot in
                        LunchSpotCardCompact(spot: spot)
                    }
                }
            }
        }
    }
}

struct LunchSpotCardCompact: View {
    let spot: LunchPlace
    
    private var distanceText: String? {
        guard let km = spot.distanceKm else { return nil }
        return String(format: "%.1f km", km)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text("🍽️")
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(spot.name)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    if let rating = spot.rating {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                    }
                    if let quickGrab = spot.quickGrab, quickGrab {
                        Text("• Quick grab")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let minutes = spot.walkingMinutes, let distance = distanceText {
                    Text("\(minutes) min walk • \(distance)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "arrow.right.circle.fill")
                .foregroundColor(.orange)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onTapGesture {
            openInMaps()
        }
    }
    
    private func openInMaps() {
        let query = spot.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?q=\(query)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Walk Routes List
struct WalkRoutesListView: View {
    let routes: [WalkRoute]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🚶 Walk Routes")
                .font(.title3.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            VStack(spacing: 8) {
                ForEach(routes.prefix(3)) { route in
                    WalkRouteCardCompact(route: route)
                }
            }
        }
    }
}

struct WalkRouteCardCompact: View {
    let route: WalkRoute
    
    private var difficultyColor: Color {
        switch route.difficulty.lowercased() {
        case "easy": return .green
        case "moderate": return .orange
        case "challenging": return .red
        default: return .blue
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(difficultyColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text("🚶")
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(route.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(route.difficulty.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.2))
                        .foregroundColor(difficultyColor)
                        .cornerRadius(4)
                }
                
                Text(route.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label("\(route.estimatedMinutes) min", systemImage: "clock")
                    Label(String(format: "%.1f km", route.distanceKm), systemImage: "figure.walk")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Image(systemName: "arrow.right.circle.fill")
                .foregroundColor(difficultyColor)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onTapGesture {
            openInMaps()
        }
    }
    
    private func openInMaps() {
        guard let mapUrl = route.mapUrl, let url = URL(string: mapUrl) else { return }
        UIApplication.shared.open(url)
    }
}

