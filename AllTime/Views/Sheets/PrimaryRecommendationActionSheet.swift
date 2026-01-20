import SwiftUI

/// Sheet for displaying and acting on Clara's primary recommendations
struct PrimaryRecommendationActionSheet: View {
    let recommendation: PrimaryRecommendation
    let focusWindow: FocusWindow?  // The intelligent time slot from briefing
    @Environment(\.dismiss) private var dismiss
    @State private var showingQuickBook = false

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Header
                        VStack(spacing: DesignSystem.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(recommendation.urgencyColor.opacity(0.15))
                                    .frame(width: DesignSystem.Components.avatarXLarge, height: DesignSystem.Components.avatarXLarge)

                                Image(systemName: recommendation.displayIcon)
                                    .font(.system(size: DesignSystem.Components.iconXXLarge, weight: .semibold))
                                    .foregroundColor(recommendation.urgencyColor)
                            }

                            VStack(spacing: DesignSystem.Spacing.sm) {
                                Text(recommendation.urgencyLabel)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(recommendation.urgencyColor)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, DesignSystem.Spacing.sm)
                                    .padding(.vertical, DesignSystem.Spacing.xs)
                                    .background(recommendation.urgencyColor.opacity(0.15))
                                    .clipShape(Capsule())

                                Text(recommendation.action)
                                    .font(.title2.weight(.semibold))
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, DesignSystem.Spacing.lg)

                        // Reason
                        if let reason = recommendation.reason, !reason.isEmpty {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Why this matters")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    .textCase(.uppercase)

                                Text(reason)
                                    .font(.body)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .padding(DesignSystem.Spacing.md)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(DesignSystem.Colors.cardBackground)
                                    .cornerRadius(DesignSystem.CornerRadius.md)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                        }

                        // Consequence warning
                        if let consequence = recommendation.ignoredConsequence, !consequence.isEmpty {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: DesignSystem.Components.iconMedium + 2))
                                    .foregroundColor(DesignSystem.Colors.warningYellow)

                                Text(consequence)
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                            }
                            .padding(DesignSystem.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DesignSystem.Colors.warningYellow.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.md)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                        }

                        Spacer(minLength: 60)

                        // Action buttons
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Button(action: {
                                let category = (recommendation.category ?? "").lowercased()
                                let healthCategories = ["health", "movement", "exercise", "activity", "walk", "wellness", "health_insight", "fitness", "workout"]
                                let isHealthRelated = healthCategories.contains(category) ||
                                    category.contains("health") || category.contains("move") ||
                                    category.contains("exercise") || category.contains("fitness") || category.contains("walk")

                                if isHealthRelated {
                                    takeAction()
                                } else {
                                    takeAction()
                                    dismiss()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Take Action")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(DesignSystem.Spacing.md)
                                .background(recommendation.urgencyColor)
                                .foregroundColor(.white)
                                .cornerRadius(DesignSystem.CornerRadius.md)
                            }

                            Button(action: { dismiss() }) {
                                Text("Remind Me Later")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.bottom, DesignSystem.Spacing.lg)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .sheet(isPresented: $showingQuickBook) {
                QuickBookView()
            }
        }
    }

    private func takeAction() {
        let category = (recommendation.category ?? "").lowercased()
        print("🎯 TakeAction called with category: '\(category)'")

        switch category {
        case "protect_time":
            if let window = focusWindow,
               let startDate = window.startDate,
               let endDate = window.endDate {
                print("🎯 Taking action: Protect time - blocking \(window.formattedTimeRange)")
                Task {
                    do {
                        let response = try await FocusTimeService.shared.blockFocusTime(
                            start: startDate,
                            end: endDate,
                            title: "Focus Time",
                            description: "Protected focus time recommended by Clara"
                        )
                        print("✅ Focus time blocked: \(response.success)")
                        if response.success {
                            HapticManager.shared.success()
                            NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)
                        }
                    } catch {
                        print("❌ Failed to block focus time: \(error)")
                        HapticManager.shared.error()
                    }
                }
            } else {
                let duration = parseDurationFromAction(recommendation.action)
                print("🎯 Taking action: Protect time - quick blocking \(duration) minutes starting now")
                Task {
                    do {
                        let response = try await FocusTimeService.shared.quickBlock(
                            minutes: duration,
                            title: "Focus Time"
                        )
                        print("✅ Quick block successful: \(response.success)")
                        if response.success {
                            HapticManager.shared.success()
                            NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)
                        }
                    } catch {
                        print("❌ Failed to quick block: \(error)")
                        HapticManager.shared.error()
                    }
                }
            }
        case "reduce_load":
            NavigationManager.shared.navigateToCalendar()
        case "health", "movement", "exercise", "activity", "walk", "wellness", "health_insight", "fitness", "workout":
            print("🎯 Taking action: Opening QuickBook for health category")
            showingQuickBook = true
        case "catch_up":
            NavigationManager.shared.navigateToReminders()
        default:
            if category.contains("health") || category.contains("move") || category.contains("exercise") || category.contains("fitness") || category.contains("walk") {
                print("🎯 Taking action: Unknown category '\(category)' looks health-related, opening QuickBook")
                showingQuickBook = true
            } else {
                print("🎯 Taking action: Unknown category '\(category)', no action taken")
            }
        }
    }

    /// Parse duration in minutes from action text like "Block 90 minutes for deep work"
    private func parseDurationFromAction(_ action: String) -> Int {
        let lowercased = action.lowercased()

        let minutePatterns = [
            #"(\d+)\s*minutes?"#,
            #"(\d+)\s*min"#
        ]

        for pattern in minutePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
               let range = Range(match.range(at: 1), in: lowercased),
               let minutes = Int(lowercased[range]) {
                return minutes
            }
        }

        let hourPatterns = [
            #"(\d+\.?\d*)\s*hours?"#,
            #"(\d+\.?\d*)\s*hr"#
        ]

        for pattern in hourPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)),
               let range = Range(match.range(at: 1), in: lowercased),
               let hours = Double(lowercased[range]) {
                return Int(hours * 60)
            }
        }

        return 60
    }
}
