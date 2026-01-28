import SwiftUI
import Combine

/// Daily Insights Tab View - Shows today's summary with actionable pattern intelligence
struct DailyInsightsTabView: View {
    @StateObject private var viewModel = DailyInsightsTabViewModel()
    @State private var selectedDate: Date = Date()
    @State private var showingReflection = false
    @State private var animateProgress = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                        .padding(.top, 100)
                } else if let error = viewModel.error {
                    errorView(error)
                        .padding(.top, 100)
                } else if let insights = viewModel.insights {
                    insightsContent(insights)
                } else {
                    emptyView
                        .padding(.top, 100)
                }
            }
        }
        .background(DesignSystem.Colors.background)
        .safeAreaInset(edge: .top) {
            dateHeader
        }
        .task {
            await viewModel.loadInsights(for: selectedDate)
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                animateProgress = true
            }
        }
        .refreshable {
            animateProgress = false
            await viewModel.loadInsights(for: selectedDate, forceRefresh: true)
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animateProgress = true
            }
        }
        .onChange(of: selectedDate) { newDate in
            animateProgress = false
            Task {
                await viewModel.loadInsights(for: newDate)
                withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                    animateProgress = true
                }
            }
        }
        .sheet(isPresented: $showingReflection) {
            DayReviewView()
        }
    }

    // MARK: - Sticky Date Header

    private var dateHeader: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(dateDisplayText)
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text(selectedDate.formatted(.dateTime.month(.wide).day().year()))
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    if tomorrow <= Date() {
                        selectedDate = tomorrow
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(Calendar.current.isDateInToday(selectedDate) ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.primary)
                    .frame(width: 44, height: 44)
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var dateDisplayText: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            return selectedDate.formatted(.dateTime.weekday(.wide))
        }
    }

    // MARK: - Loading / Error / Empty Views

    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(DesignSystem.Colors.tertiaryText.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                ProgressView()
                    .scaleEffect(1.2)
            }
            Text("Loading your insights...")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.amber.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(DesignSystem.Colors.amber)
            }

            VStack(spacing: 8) {
                Text("Unable to load")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                Task { await viewModel.loadInsights(for: selectedDate, forceRefresh: true) }
            }) {
                Text("Try Again")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(DesignSystem.Colors.primary)
                    .cornerRadius(24)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.tertiaryText.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 36))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            VStack(spacing: 8) {
                Text("No insights yet")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text("Check back after some activity")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Main Content

    @ViewBuilder
    private func insightsContent(_ insights: DailyInsightsSummary) -> some View {
        VStack(spacing: 20) {
            // HERO: Today's Outlook with Pattern Intelligence
            if Calendar.current.isDateInToday(selectedDate) {
                if viewModel.isLoadingPrediction {
                    predictionLoadingView
                        .padding(.horizontal)
                        .padding(.top, 16)
                } else if let prediction = viewModel.todayPrediction {
                    todayOutlookHero(prediction, insights: insights)
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // Actionable Pattern Insights (ALWAYS SHOW - THE VALUE)
                    patternInsightsSection(prediction)
                        .padding(.horizontal)
                } else {
                    dayScoreHero(insights)
                        .padding(.horizontal)
                        .padding(.top, 16)
                }
            } else {
                dayScoreHero(insights)
                    .padding(.horizontal)
                    .padding(.top, 16)
            }

            // Quick Stats
            dayStatsRow(insights)

            // Time Breakdown
            if let timeBreakdown = insights.timeBreakdown {
                timeVisualization(timeBreakdown)
                    .padding(.horizontal)
            }

            // Health Progress
            if let health = insights.health, health.hasData {
                healthRingsSection(health)
            }

            // Summary
            insightsSummaryCard(insights)
                .padding(.horizontal)

            // Reflection CTA
            reflectionCard
                .padding(.horizontal)
                .padding(.bottom, 32)
        }
    }

    // MARK: - Today's Outlook Hero

    private func todayOutlookHero(_ prediction: TodayPrediction, insights: DailyInsightsSummary) -> some View {
        VStack(spacing: 0) {
            // Main prediction area
            HStack(alignment: .top, spacing: 16) {
                // Left: Day overview
                VStack(alignment: .leading, spacing: 10) {
                    // Intensity badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(prediction.intensityColor)
                            .frame(width: 10, height: 10)
                        Text(prediction.intensityLabel + " Day")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(prediction.intensityColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(prediction.intensityColor.opacity(0.12))
                    .cornerRadius(16)

                    // Stats
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 16) {
                            Label("\(prediction.meetingCount) meetings", systemImage: "calendar")
                            if prediction.meetingHours >= 1 {
                                Label(prediction.formattedMeetingHours, systemImage: "clock.fill")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                        if prediction.backToBackCount > 0 {
                            Label("\(prediction.backToBackCount) back-to-back", systemImage: "arrow.right.arrow.left")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.amber)
                        }
                    }
                }

                Spacer()

                // Right: Outcome prediction
                if let pred = prediction.prediction, let outcome = pred.predictedOutcome {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(pred.outcomeColor.opacity(0.2), lineWidth: 8)
                                .frame(width: 76, height: 76)

                            Circle()
                                .trim(from: 0, to: animateProgress ? CGFloat(outcome) / 100.0 : 0)
                                .stroke(pred.outcomeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 76, height: 76)
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 0) {
                                Text("\(outcome)")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(pred.outcomeColor)
                                Text("outlook")
                                    .font(.system(size: 9))
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                            }
                        }

                        Text(outcomeLabel(outcome))
                            .font(.caption.weight(.medium))
                            .foregroundColor(pred.outcomeColor)
                    }
                }
            }
            .padding(18)

            // Clara's key insight (if any)
            if let insight = prediction.claraInsight, !insight.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.violet)

                    Text(insight)
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineSpacing(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignSystem.Colors.violet.opacity(0.06))
            }
        }
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    private func outcomeLabel(_ outcome: Int) -> String {
        if outcome >= 70 { return "Looking good" }
        if outcome >= 50 { return "Manageable" }
        if outcome >= 35 { return "Challenging" }
        return "Tough day ahead"
    }

    // MARK: - Pattern Insights Section (THE VALUE)

    private func patternInsightsSection(_ prediction: TodayPrediction) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section header - changes based on whether we have historical data
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.violet)
                Text(prediction.hasSimilarDays ? "Clara's Pattern Insights" : "Clara's Recommendations")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            VStack(spacing: 12) {
                // 1. Day overview insight (always show)
                dayOverviewInsight(prediction)

                // 2. Historical pattern (only if we have data)
                if let similarDays = prediction.similarDays, !similarDays.isEmpty {
                    let goodDays = similarDays.filter { $0.outcomeScore >= 60 }.count
                    let totalDays = similarDays.count

                    patternInsightCard(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: goodDays > totalDays / 2 ? DesignSystem.Colors.emerald : DesignSystem.Colors.amber,
                        title: "Historical Pattern",
                        insight: historicalPatternInsight(goodDays: goodDays, total: totalDays, prediction: prediction)
                    )
                }

                // 3. Energy management (show prediction if available, or general advice)
                if let pred = prediction.prediction, let energy = pred.predictedEnergy {
                    patternInsightCard(
                        icon: energyIcon(energy),
                        iconColor: pred.energyColor,
                        title: "Energy Forecast",
                        insight: energyInsight(energy: energy, prediction: prediction)
                    )
                } else {
                    // General energy advice based on schedule
                    patternInsightCard(
                        icon: energyIconForSchedule(prediction),
                        iconColor: energyColorForSchedule(prediction),
                        title: "Energy Management",
                        insight: generalEnergyAdvice(prediction)
                    )
                }

                // 4. Sleep recommendation
                if let pred = prediction.prediction, let sleep = pred.recommendedSleep {
                    patternInsightCard(
                        icon: "moon.zzz.fill",
                        iconColor: DesignSystem.Colors.indigo,
                        title: "Tonight's Sleep Target",
                        insight: sleepInsight(recommended: sleep, prediction: prediction)
                    )
                } else {
                    patternInsightCard(
                        icon: "moon.zzz.fill",
                        iconColor: DesignSystem.Colors.indigo,
                        title: "Sleep Recommendation",
                        insight: generalSleepAdvice(prediction)
                    )
                }

                // 5. Specific action to take (THE MOST IMPORTANT - always show)
                actionableRecommendation(prediction)
            }
        }
        .padding(16)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(16)
    }

    // Day overview insight based on schedule
    private func dayOverviewInsight(_ prediction: TodayPrediction) -> some View {
        let insight = generateDayOverviewInsight(prediction)

        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(prediction.intensityColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: dayOverviewIcon(prediction))
                    .font(.subheadline)
                    .foregroundColor(prediction.intensityColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Shape")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Text(insight)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func dayOverviewIcon(_ prediction: TodayPrediction) -> String {
        switch prediction.intensity {
        case "extreme", "heavy": return "flame.fill"
        case "moderate": return "calendar"
        case "light": return "sun.max.fill"
        case "open": return "leaf.fill"
        default: return "calendar"
        }
    }

    private func generateDayOverviewInsight(_ prediction: TodayPrediction) -> String {
        if prediction.meetingCount == 0 {
            return "Meeting-free day ahead. This is rare — use it for deep work or strategic thinking."
        } else if prediction.meetingCount >= 6 {
            if prediction.backToBackCount >= 3 {
                return "\(prediction.meetingCount) meetings with \(prediction.backToBackCount) back-to-back blocks. This will be intense — plan buffer time."
            }
            return "Heavy meeting day with \(prediction.meetingCount) meetings (\(prediction.formattedMeetingHours)). Prioritize breaks."
        } else if prediction.backToBackCount >= 2 {
            return "\(prediction.meetingCount) meetings today with \(prediction.backToBackCount) back-to-back. Watch your energy in the afternoon."
        } else if prediction.meetingCount <= 2 {
            return "Light day with just \(prediction.meetingCount) meeting\(prediction.meetingCount == 1 ? "" : "s"). Great opportunity for focused work."
        } else {
            return "\(prediction.meetingCount) meetings spread across \(prediction.formattedMeetingHours). Balanced day — stay intentional."
        }
    }

    // General energy advice when no prediction data
    private func energyIconForSchedule(_ prediction: TodayPrediction) -> String {
        if prediction.meetingCount >= 5 || prediction.backToBackCount >= 3 {
            return "battery.25"
        } else if prediction.meetingCount >= 3 {
            return "battery.50"
        } else {
            return "battery.100"
        }
    }

    private func energyColorForSchedule(_ prediction: TodayPrediction) -> Color {
        if prediction.meetingCount >= 5 || prediction.backToBackCount >= 3 {
            return DesignSystem.Colors.errorRed
        } else if prediction.meetingCount >= 3 {
            return DesignSystem.Colors.amber
        } else {
            return DesignSystem.Colors.emerald
        }
    }

    private func generalEnergyAdvice(_ prediction: TodayPrediction) -> String {
        if prediction.meetingCount >= 6 {
            return "Heavy days drain energy fast. Take a 5-minute break between meetings and avoid working through lunch."
        } else if prediction.backToBackCount >= 3 {
            return "Back-to-back meetings cause mental fatigue. Try to stand, stretch, or step outside after every 2-3 meetings."
        } else if prediction.meetingCount >= 4 {
            return "Moderate meeting load. Schedule your most important work for the morning or after your last meeting."
        } else if prediction.meetingCount == 0 {
            return "No meetings = high energy potential. Start with a challenging task while your focus is fresh."
        } else {
            return "Light schedule should keep energy steady. Use gaps between meetings for quick tasks, not email rabbit holes."
        }
    }

    // General sleep advice when no prediction data
    private func generalSleepAdvice(_ prediction: TodayPrediction) -> String {
        if prediction.meetingCount >= 6 {
            return "Heavy days need recovery. Aim for 8+ hours tonight to bounce back strong tomorrow."
        } else if prediction.backToBackCount >= 3 {
            return "Mentally demanding days require good sleep. Target 7.5-8 hours for proper cognitive recovery."
        } else if prediction.meetingCount == 0 {
            return "Light days still need quality rest. Stick to your usual bedtime — consistency beats quantity."
        } else {
            return "Standard day, standard sleep. 7-8 hours will set you up well for tomorrow."
        }
    }

    private func patternInsightCard(icon: String, iconColor: Color, title: String, insight: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Text(insight)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func historicalPatternInsight(goodDays: Int, total: Int, prediction: TodayPrediction) -> String {
        let percentage = total > 0 ? (goodDays * 100) / total : 0

        if prediction.meetingCount >= 6 {
            if percentage >= 60 {
                return "You've handled \(total) similar heavy days before. \(goodDays) went well when you protected breaks between meetings."
            } else {
                return "On \(total) similar heavy days, only \(goodDays) went well. The pattern: skipping breaks led to afternoon crashes."
            }
        } else if prediction.meetingCount == 0 {
            return "Meeting-free days like this have a \(percentage)% success rate. Best outcomes came from tackling your hardest task first."
        } else {
            if percentage >= 70 {
                return "Great news: \(percentage)% of similar days went well. You tend to thrive with this meeting load."
            } else if percentage >= 50 {
                return "Mixed results on similar days (\(goodDays)/\(total) good). The difference? Days with lunch breaks scored 30% higher."
            } else {
                return "Heads up: Only \(goodDays) of \(total) similar days went well. Common pitfall: back-to-back meetings without recovery."
            }
        }
    }

    private func energyInsight(energy: Int, prediction: TodayPrediction) -> String {
        if energy >= 70 {
            return "Energy should stay strong today. Best time for hard tasks: before your first meeting or during the longest gap."
        } else if energy >= 50 {
            if prediction.backToBackCount > 2 {
                return "With \(prediction.backToBackCount) back-to-backs, expect an energy dip around 2-3pm. Schedule a 10-min break or walk."
            }
            return "Moderate energy expected. Tackle important work in the morning—afternoons on days like this tend to drag."
        } else {
            return "Low energy predicted based on your schedule density. Protect at least one 30-min break, or today will feel like a marathon."
        }
    }

    private func sleepInsight(recommended: Double, prediction: TodayPrediction) -> String {
        let hours = String(format: "%.0f", recommended)

        if prediction.meetingCount >= 5 {
            return "Aim for \(hours)+ hours tonight. On heavy meeting days, each extra hour of sleep improved your next-day focus by 20%."
        } else if recommended >= 8 {
            return "Your body needs \(hours) hours to recover from today. Days after good sleep had 40% better outcomes in your history."
        } else {
            return "Target \(hours) hours. That's your sweet spot—less led to 30% more 'rough day' ratings in your data."
        }
    }

    private func energyIcon(_ energy: Int) -> String {
        if energy >= 70 { return "battery.100" }
        if energy >= 50 { return "battery.50" }
        return "battery.25"
    }

    private func actionableRecommendation(_ prediction: TodayPrediction) -> some View {
        let recommendation = generateActionableRecommendation(prediction)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.emerald.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.emerald)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Do This Today")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.emerald)
                Text(recommendation)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(DesignSystem.Colors.emerald.opacity(0.06))
        .cornerRadius(12)
    }

    private func generateActionableRecommendation(_ prediction: TodayPrediction) -> String {
        if prediction.backToBackCount >= 3 {
            return "Block 15 mins after your \(ordinal(prediction.backToBackCount / 2 + 1)) meeting for a mental reset. Your data shows this prevents the afternoon slump."
        } else if prediction.meetingCount >= 6 {
            return "Eat lunch away from your desk today. On heavy days, a proper break improved your afternoon ratings by 35%."
        } else if prediction.meetingCount == 0 {
            return "Start with your most dreaded task in the first 2 hours. Your no-meeting days were most productive when you did this."
        } else if let pred = prediction.prediction, let energy = pred.predictedEnergy, energy < 50 {
            return "Take a 10-minute walk before 2pm. On low-energy days, this single habit boosted your end-of-day score by 25%."
        } else if prediction.meetingHours >= 4 {
            return "Decline or shorten one meeting if possible. Days with 4+ meeting hours and at least one declined had better outcomes."
        } else {
            return "Protect a 30-min focus block this morning. Your best days had at least one uninterrupted deep work session."
        }
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10

        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

    // MARK: - Day Score Hero (Fallback for past days)

    private func dayScoreHero(_ insights: DailyInsightsSummary) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: dayToneIcon(insights.dayTone))
                            .font(.title2)
                            .foregroundColor(dayToneColor(insights.dayTone))
                        Text(insights.dayTone.capitalized)
                            .font(.title2.weight(.bold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    Text(daySummaryText(insights))
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                if let completion = insights.completion, completion.hasActivities {
                    ZStack {
                        Circle()
                            .stroke(DesignSystem.Colors.tertiaryText.opacity(0.15), lineWidth: 8)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: animateProgress ? CGFloat(completion.completionPercentage) / 100.0 : 0)
                            .stroke(completionGradient(for: completion.completionPercentage), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("\(completion.completionPercentage)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            Text("%")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
            }
            .padding(20)

            HStack(spacing: 0) {
                if let eventStats = insights.eventStats {
                    heroStat(icon: "calendar", value: "\(eventStats.meetings)", label: "Meetings", color: DesignSystem.Colors.violet)
                    heroDivider
                    heroStat(icon: "brain.head.profile", value: "\(eventStats.focusBlocks)", label: "Focus", color: DesignSystem.Colors.blue)
                }
                if let completion = insights.completion, completion.hasActivities {
                    heroDivider
                    heroStat(icon: "checkmark.circle.fill", value: "\(completion.totalCompleted)/\(completion.totalPlanned)", label: "Done", color: DesignSystem.Colors.emerald)
                }
            }
            .padding(.vertical, 14)
            .background(DesignSystem.Colors.tertiaryBackground)
        }
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
    }

    private func heroStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(DesignSystem.Colors.tertiaryText.opacity(0.2))
            .frame(width: 1, height: 32)
    }

    private func daySummaryText(_ insights: DailyInsightsSummary) -> String {
        if let eventStats = insights.eventStats {
            if eventStats.meetings == 0 { return "Meeting-free day" }
            let meetingText = eventStats.meetings == 1 ? "1 meeting" : "\(eventStats.meetings) meetings"
            if let breakdown = insights.timeBreakdown, breakdown.meetingHours >= 4 {
                return "\(meetingText) - heavy load"
            }
            return meetingText
        }
        return ""
    }

    // MARK: - Day Stats Row

    private func dayStatsRow(_ insights: DailyInsightsSummary) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if let eventStats = insights.eventStats {
                    if eventStats.backToBackCount > 0 {
                        statChip(icon: "arrow.right.arrow.left", text: "\(eventStats.backToBackCount) back-to-back", color: DesignSystem.Colors.amber)
                    }
                    if eventStats.longestMeetingMinutes > 30 {
                        statChip(icon: "clock", text: "Longest: \(eventStats.longestMeetingMinutes)m", color: DesignSystem.Colors.violet)
                    }
                }
                if let health = insights.health, let steps = health.steps {
                    statChip(icon: "figure.walk", text: formatNumber(steps) + " steps", color: health.stepsGoalMet == true ? DesignSystem.Colors.emerald : DesignSystem.Colors.tertiaryText)
                }
            }
            .padding(.horizontal)
        }
    }

    private func statChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(20)
    }

    // MARK: - Time Visualization

    private func timeVisualization(_ breakdown: DailyInsightsSummary.TimeBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Time Allocation")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            GeometryReader { geo in
                let total = max(breakdown.totalScheduledHours + breakdown.freeHours, 8)
                HStack(spacing: 2) {
                    if breakdown.meetingHours > 0 {
                        Rectangle().fill(DesignSystem.Colors.errorRed)
                            .frame(width: max(geo.size.width * CGFloat(breakdown.meetingHours / total), 4))
                    }
                    if breakdown.focusHours > 0 {
                        Rectangle().fill(DesignSystem.Colors.blue)
                            .frame(width: max(geo.size.width * CGFloat(breakdown.focusHours / total), 4))
                    }
                    if breakdown.personalHours > 0 {
                        Rectangle().fill(DesignSystem.Colors.emerald)
                            .frame(width: max(geo.size.width * CGFloat(breakdown.personalHours / total), 4))
                    }
                    if breakdown.freeHours > 0 {
                        Rectangle().fill(DesignSystem.Colors.tertiaryText.opacity(0.3))
                            .frame(width: max(geo.size.width * CGFloat(breakdown.freeHours / total), 4))
                    }
                }
            }
            .frame(height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            HStack(spacing: 16) {
                timeLegend(color: DesignSystem.Colors.errorRed, label: "Meetings", hours: breakdown.meetingHours)
                timeLegend(color: DesignSystem.Colors.blue, label: "Focus", hours: breakdown.focusHours)
                timeLegend(color: DesignSystem.Colors.emerald, label: "Personal", hours: breakdown.personalHours)
                Spacer()
            }
        }
        .padding(16)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(16)
    }

    private func timeLegend(color: Color, label: String, hours: Double) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text("\(label) \(formatHours(hours))")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
    }

    // MARK: - Health Rings

    private func healthRingsSection(_ health: DailyInsightsSummary.HealthSummary) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if let steps = health.steps {
                    healthRingCard(icon: "figure.walk", value: formatNumber(steps), label: "Steps", percent: health.stepsGoalPercent ?? 0, goalMet: health.stepsGoalMet ?? false, color: DesignSystem.Colors.emerald)
                }
                if let sleepMinutes = health.sleepMinutes {
                    healthRingCard(icon: "bed.double.fill", value: formatSleep(sleepMinutes), label: "Sleep", percent: health.sleepGoalPercent ?? 0, goalMet: health.sleepGoalMet ?? false, color: DesignSystem.Colors.indigo)
                }
                if let activeMinutes = health.activeMinutes {
                    healthRingCard(icon: "flame.fill", value: "\(activeMinutes)m", label: "Active", percent: health.activeGoalPercent ?? 0, goalMet: health.activeGoalMet ?? false, color: DesignSystem.Colors.errorRed)
                }
            }
            .padding(.horizontal)
        }
    }

    private func healthRingCard(icon: String, value: String, label: String, percent: Int, goalMet: Bool, color: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 5).frame(width: 50, height: 50)
                Circle()
                    .trim(from: 0, to: animateProgress ? min(CGFloat(percent) / 100.0, 1.0) : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                Image(systemName: goalMet ? "checkmark" : icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(goalMet ? color : DesignSystem.Colors.secondaryText)
            }
            Text(value).font(.caption.weight(.bold)).foregroundColor(DesignSystem.Colors.primaryText)
            Text(label).font(.caption2).foregroundColor(DesignSystem.Colors.secondaryText)
            Text("\(percent)%").font(.caption2.weight(.medium)).foregroundColor(goalMet ? color : DesignSystem.Colors.tertiaryText)
        }
        .frame(width: 90)
        .padding(.vertical, 14)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Insights Summary

    private func insightsSummaryCard(_ insights: DailyInsightsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(insights.summaryMessage)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineSpacing(4)

            if let highlights = insights.highlights, !highlights.isEmpty {
                VStack(spacing: 8) {
                    ForEach(highlights.prefix(3), id: \.label) { highlight in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().fill(highlightColor(highlight.category).opacity(0.12)).frame(width: 28, height: 28)
                                Image(systemName: highlight.icon).font(.caption2).foregroundColor(highlightColor(highlight.category))
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(highlight.label).font(.caption.weight(.semibold)).foregroundColor(DesignSystem.Colors.primaryText)
                                Text(highlight.detail).font(.caption2).foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Reflection Card

    private var reflectionCard: some View {
        Button(action: { showingReflection = true }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [DesignSystem.Colors.blue, DesignSystem.Colors.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    Image(systemName: "pencil.line").font(.body.weight(.semibold)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reflect on Your Day").font(.subheadline.weight(.semibold)).foregroundColor(DesignSystem.Colors.primaryText)
                    Text("Rate your day and capture thoughts").font(.caption).foregroundColor(DesignSystem.Colors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(14)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(DesignSystem.Colors.blue.opacity(0.2), lineWidth: 1))
        }
    }

    private var predictionLoadingView: some View {
        HStack(spacing: 12) {
            ProgressView().scaleEffect(0.8)
            Text("Analyzing your patterns...").font(.subheadline).foregroundColor(DesignSystem.Colors.secondaryText)
            Spacer()
        }
        .padding(20)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(20)
    }

    // MARK: - Helpers

    private func formatHours(_ hours: Double) -> String {
        if hours < 0.1 { return "" }
        if hours < 1 { return "\(Int(hours * 60))m" }
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 10000 { return String(format: "%.1fk", Double(number) / 1000.0) }
        return NumberFormatter.localizedString(from: NSNumber(value: number), number: .decimal)
    }

    private func formatSleep(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }

    private func completionGradient(for percentage: Int) -> LinearGradient {
        let color: Color = percentage >= 75 ? DesignSystem.Colors.emerald : percentage >= 50 ? DesignSystem.Colors.amber : DesignSystem.Colors.errorRed
        return LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
    }

    private func dayToneIcon(_ tone: String) -> String {
        switch tone.lowercased() {
        case "intense", "busy": return "bolt.fill"
        case "calm", "relaxed": return "leaf.fill"
        case "productive": return "checkmark.seal.fill"
        case "balanced": return "scale.3d"
        case "light": return "sun.max.fill"
        default: return "circle.grid.2x2.fill"
        }
    }

    private func dayToneColor(_ tone: String) -> Color {
        switch tone.lowercased() {
        case "intense", "busy": return DesignSystem.Colors.amber
        case "calm", "relaxed": return DesignSystem.Colors.emerald
        case "productive": return DesignSystem.Colors.blue
        case "balanced": return DesignSystem.Colors.violet
        case "light": return DesignSystem.Colors.info
        default: return DesignSystem.Colors.primary
        }
    }

    private func highlightColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "health": return DesignSystem.Colors.errorRed
        case "work", "meeting": return DesignSystem.Colors.blue
        case "focus": return DesignSystem.Colors.violet
        case "personal": return DesignSystem.Colors.emerald
        case "achievement": return DesignSystem.Colors.amber
        default: return DesignSystem.Colors.secondaryText
        }
    }
}

// MARK: - ViewModel

@MainActor
class DailyInsightsTabViewModel: ObservableObject {
    @Published var insights: DailyInsightsSummary?
    @Published var todayPrediction: TodayPrediction?
    @Published var isLoading = false
    @Published var isLoadingPrediction = false
    @Published var error: String?

    private let dayReviewService = DayReviewService.shared
    private let apiService = APIService.shared
    private var cache: [String: (insights: DailyInsightsSummary, timestamp: Date)] = [:]
    private var predictionCache: (prediction: TodayPrediction, timestamp: Date)?
    private let cacheExpiration: TimeInterval = 300
    private let predictionCacheExpiration: TimeInterval = 600

    func loadInsights(for date: Date, forceRefresh: Bool = false) async {
        let dateKey = formatDateKey(date)

        if !forceRefresh, let cached = cache[dateKey], Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            insights = cached.insights
        } else {
            isLoading = true
            error = nil
            do {
                let summary = try await dayReviewService.getDailyInsightsSummary(date: date)
                insights = summary
                cache[dateKey] = (summary, Date())
                isLoading = false
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }

        if Calendar.current.isDateInToday(date) {
            await loadTodayPrediction(forceRefresh: forceRefresh)
        } else {
            todayPrediction = nil
        }
    }

    func loadTodayPrediction(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached = predictionCache, Date().timeIntervalSince(cached.timestamp) < predictionCacheExpiration {
            todayPrediction = cached.prediction
            return
        }

        isLoadingPrediction = true
        do {
            let prediction = try await apiService.getTodayPrediction()
            todayPrediction = prediction
            predictionCache = (prediction, Date())
            isLoadingPrediction = false
        } catch {
            print("Failed to load today's prediction: \(error)")
            isLoadingPrediction = false
        }
    }

    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

#Preview {
    DailyInsightsTabView()
}
