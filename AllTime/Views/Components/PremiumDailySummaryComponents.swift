import SwiftUI

// MARK: - Premium Summary Content View

struct PremiumSummaryContentView: View {
    let summary: DailySummary
    let parsed: ParsedSummary
    let waterGoal: Double?
    
    @State private var hasAppeared = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Critical Alerts Banner
            if !parsed.criticalAlerts.isEmpty {
                PremiumAlertsBanner(alerts: parsed.criticalAlerts, severity: .critical)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : -20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: hasAppeared)
            }
            
            // Health Metrics Overview
            if parsed.waterIntake != nil || parsed.steps != nil || parsed.sleepHours != nil {
                PremiumHealthMetricsCard(
                    waterIntake: parsed.waterIntake,
                    waterGoal: waterGoal ?? parsed.waterGoal,
                    steps: parsed.steps,
                    stepsGoal: parsed.stepsGoal,
                    sleepHours: parsed.sleepHours,
                    sleepStatus: parsed.sleepStatus
                )
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
            }
            
            // Break Strategy & Recommendations
            if !parsed.suggestedBreaks.isEmpty || parsed.breakStrategy != nil {
                PremiumBreakStrategyCard(
                    strategy: parsed.breakStrategy,
                    breaks: parsed.suggestedBreaks
                )
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
            }
            
            // Day Summary Section
            if !summary.daySummary.isEmpty {
                PremiumSectionCard(
                    icon: "calendar.badge.clock",
                    iconColor: .blue,
                    title: "Your Day",
                    items: summary.daySummary
                )
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: hasAppeared)
            }
            
            // Health Summary Section
            if !summary.healthSummary.isEmpty {
                PremiumSectionCard(
                    icon: "heart.text.square.fill",
                    iconColor: .red,
                    title: "Health Insights",
                    items: summary.healthSummary
                )
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: hasAppeared)
            }
            
            // Focus Recommendations Section
            if !summary.focusRecommendations.isEmpty {
                PremiumSectionCard(
                    icon: "brain.head.profile",
                    iconColor: .purple,
                    title: "Focus & Productivity",
                    items: summary.focusRecommendations
                )
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: hasAppeared)
            }
            
            // Warnings Banner
            if !parsed.warnings.isEmpty {
                PremiumAlertsBanner(alerts: parsed.warnings, severity: .warning)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.7), value: hasAppeared)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .onAppear {
            hasAppeared = true
        }
    }
}

// MARK: - Premium Health Metrics Card

struct PremiumHealthMetricsCard: View {
    let waterIntake: Double?
    let waterGoal: Double?
    let steps: Int?
    let stepsGoal: Int?
    let sleepHours: Double?
    let sleepStatus: SleepStatus
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Health Metrics")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Metrics Grid
            VStack(spacing: DesignSystem.Spacing.md) {
                // Sleep Metric
                if let sleep = sleepHours {
                    PremiumMetricRow(
                        icon: "moon.stars.fill",
                        iconColor: sleepStatusColor(sleepStatus),
                        title: "Sleep",
                        value: String(format: "%.1fh", sleep),
                        subtitle: sleepStatusText(sleepStatus),
                        progress: min(sleep / 8.0, 1.0),
                        progressColor: sleepStatusColor(sleepStatus)
                    )
                }
                
                // Steps Metric
                if let steps = steps, let goal = stepsGoal {
                    PremiumMetricRow(
                        icon: "figure.walk",
                        iconColor: .green,
                        title: "Steps",
                        value: steps.formatted(),
                        subtitle: "\(goal.formatted()) goal",
                        progress: min(Double(steps) / Double(goal), 1.0),
                        progressColor: stepsProgressColor(Double(steps) / Double(goal))
                    )
                }
                
                // Water Intake Metric
                if let water = waterIntake, let goal = waterGoal {
                    PremiumMetricRow(
                        icon: "drop.fill",
                        iconColor: .cyan,
                        title: "Water",
                        value: String(format: "%.1fL", water),
                        subtitle: String(format: "%.1fL goal", goal),
                        progress: min(water / goal, 1.0),
                        progressColor: waterProgressColor(water / goal)
                    )
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
    
    // Helper functions
    private func sleepStatusColor(_ status: SleepStatus) -> Color {
        switch status {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    private func sleepStatusText(_ status: SleepStatus) -> String {
        switch status {
        case .excellent: return "Excellent rest"
        case .good: return "Good rest"
        case .fair: return "Could be better"
        case .poor: return "Need more sleep"
        }
    }
    
    private func stepsProgressColor(_ progress: Double) -> Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.7 { return .orange }
        return .red
    }
    
    private func waterProgressColor(_ progress: Double) -> Color {
        if progress >= 1.0 { return .green }
        if progress >= 0.7 { return .cyan }
        return .red
    }
}

// MARK: - Premium Metric Row

struct PremiumMetricRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String
    let progress: Double
    let progressColor: Color
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(iconColor.opacity(0.12))
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    
                    Text(value)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
                
                Spacer()
                
                // Status Badge
                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(progressColor)
                    
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [progressColor, progressColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Premium Break Strategy Card

struct PremiumBreakStrategyCard: View {
    let strategy: String?
    let breaks: [BreakWindow]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Breaks & Focus")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                LinearGradient(
                    colors: [Color.green.opacity(0.05), Color.mint.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Break Strategy
                if let strategy = strategy {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.yellow)
                        
                        Text(strategy)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .fill(Color.yellow.opacity(0.08))
                    )
                }
                
                // Break Windows
                if !breaks.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(breaks) { breakWindow in
                            PremiumBreakWindowCard(breakWindow: breakWindow)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Premium Break Window Card

struct PremiumBreakWindowCard: View {
    let breakWindow: BreakWindow
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Break Type Icon
            Text(breakWindow.type.rawValue)
                .font(.system(size: 28))
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(breakTypeColor(breakWindow.type).opacity(0.15))
                )
            
            // Break Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(breakWindow.type.displayName)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    Spacer()
                    
                    Text(timeFormatter.string(from: breakWindow.time))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(breakTypeColor(breakWindow.type))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(breakTypeColor(breakWindow.type).opacity(0.15))
                        )
                }
                
                Text("\(breakWindow.duration) min")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                
                if !breakWindow.reasoning.isEmpty {
                    Text(breakWindow.reasoning)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .lineLimit(2)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private func breakTypeColor(_ type: BreakType) -> Color {
        switch type {
        case .hydration: return .cyan
        case .meal: return .orange
        case .rest: return .indigo
        case .movement: return .green
        case .prep: return .blue
        }
    }
}

// MARK: - Premium Section Card

struct PremiumSectionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let items: [String]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
                
                // Item count badge
                Text("\(items.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(iconColor)
                    )
            }
            .padding(DesignSystem.Spacing.lg)
            .background(iconColor.opacity(0.05))
            
            // Items List
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    PremiumSectionItem(text: item, icon: icon, color: iconColor)
                    
                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Premium Section Item

struct PremiumSectionItem: View {
    let text: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Bullet point
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            // Text
            Text(text)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
        }
    }
}

// MARK: - Premium Alerts Banner

struct PremiumAlertsBanner: View {
    let alerts: [Alert]
    let severity: AlertSeverity
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(alerts) { alert in
                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                    // Icon
                    Image(systemName: severityIcon(severity))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(severityColor(severity))
                    
                    // Message
                    Text(alert.message)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding(DesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(severityColor(severity).opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .strokeBorder(severityColor(severity).opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private func severityIcon(_ severity: AlertSeverity) -> String {
        switch severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    private func severityColor(_ severity: AlertSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

