import Foundation

/// Mock data for Enhanced Daily Summary (matches screenshots)
struct MockEnhancedDailySummaryData {
    
    static func generateMockSummary() -> EnhancedDailySummaryResponse {
        return EnhancedDailySummaryResponse(
            date: "2025-12-04",
            overview: "Today looks like a balanced day with 3 meetings and good opportunities for focused work. You're well-rested from last night's sleep, making it perfect for tackling challenging tasks.",
            keyHighlights: [
                HighlightItem(
                    title: "Well-Rested Morning",
                    details: "You got 7.5 hours of quality sleep - perfect for a productive day"
                ),
                HighlightItem(
                    title: "Balanced Schedule",
                    details: "3 meetings totaling 2 hours leaves plenty of time for deep work"
                ),
                HighlightItem(
                    title: "Good Energy Levels",
                    details: "Recovery score at 85% - you're in great shape for the day ahead"
                )
            ],
            potentialIssues: [],
            suggestions: [
                SuggestionItem(
                    timeWindow: TimeWindow(start: "2025-12-04T15:00:00Z", end: "2025-12-04T15:15:00Z"),
                    headline: "Take a short break after your 3 PM meeting to recharge.",
                    details: nil
                ),
                SuggestionItem(
                    timeWindow: TimeWindow(start: "2025-12-04T17:15:00Z", end: "2025-12-04T18:30:00Z"),
                    headline: "Use the time between 5:15 PM and 6:30 PM to prep for your evening meetings and grab a snack.",
                    details: nil
                ),
                SuggestionItem(
                    timeWindow: nil,
                    headline: "Stay hydrated throughout the day to keep your energy up.",
                    details: nil
                )
            ],
            dayIntel: DayIntel(
                aggregates: DayIntelAggregates(
                    totalEvents: 3,
                    meetingMinutes: 120,
                    firstEventTime: "9:00 AM",
                    lastEventTime: "3:00 PM",
                    hasEarlyStart: false,
                    hasLateEnd: false
                ),
                gaps: [],
                overlaps: [],
                backToBackBlocks: [],
                healthRisks: HealthRisks(
                    lunchRisk: false,
                    dinnerRisk: false,
                    travelRisks: [],
                    fatigueRisk: FatigueRisk(
                        hasRisk: false,
                        riskLevel: "low",
                        meetingDensity: 0.3,
                        consecutiveHours: 2,
                        reason: nil
                    )
                ),
                contextTotals: [:],
                eventsByContext: [:]
            ),
            healthBasedSuggestions: [
                HealthBasedSuggestion(
                    title: "Take a short walk",
                    description: "In between AllTime Test 1 and AllTime Test 2, take a 10-15 minute walk to refresh your mind and increase your step count.",
                    category: "exercise",
                    priority: "high",
                    relatedEvent: "AllTime Test 1",
                    suggestedTime: "3:00 PM - 3:15 PM"
                ),
                HealthBasedSuggestion(
                    title: "Stay hydrated",
                    description: "Make sure to drink water throughout the day. Staying hydrated can improve your energy levels and focus.",
                    category: "nutrition",
                    priority: "high",
                    relatedEvent: nil,
                    suggestedTime: "Throughout the day"
                ),
                HealthBasedSuggestion(
                    title: "Take a Midday Walk",
                    description: "Since you have no scheduled events, take a break and aim for a 20-minute walk to increase your steps and boost your mood.",
                    category: "exercise",
                    priority: "high",
                    relatedEvent: "None",
                    suggestedTime: "12:00 PM"
                ),
                HealthBasedSuggestion(
                    title: "Hydrate Regularly",
                    description: "Make sure to drink water throughout the day. Staying hydrated can improve your energy levels and focus.",
                    category: "nutrition",
                    priority: "medium",
                    relatedEvent: "None",
                    suggestedTime: "Throughout the day"
                ),
                HealthBasedSuggestion(
                    title: "Set a Timer for Breaks",
                    description: "To manage your time effectively, set a timer for 25 minutes of focused work followed by a 5-minute break to recharge.",
                    category: "time_management",
                    priority: "medium",
                    relatedEvent: "None",
                    suggestedTime: "Starting at 9:00 AM"
                ),
                HealthBasedSuggestion(
                    title: "Practice Deep Breathing",
                    description: "Take 5 minutes to practice deep breathing exercises to reduce stress and improve focus before your next meeting.",
                    category: "stress",
                    priority: "low",
                    relatedEvent: nil,
                    suggestedTime: "3:00 PM"
                ),
                HealthBasedSuggestion(
                    title: "Early Bedtime",
                    description: "Since you had a decent amount of sleep last night, aim for an early bedtime to maintain this positive trend and help recover from any fatigue.",
                    category: "sleep",
                    priority: "medium",
                    relatedEvent: nil,
                    suggestedTime: "10:00 PM"
                ),
                HealthBasedSuggestion(
                    title: "Increase Activity Level",
                    description: "Aim for at least 30 minutes of more vigorous activity today to help improve your fitness level, especially since you've only had 7 active minutes.",
                    category: "exercise",
                    priority: "high",
                    relatedEvent: nil,
                    suggestedTime: "Throughout the day"
                )
            ],
            healthImpactInsights: HealthImpactInsights(
                summary: "Today looks like a great opportunity for you to enjoy a restful day! With over 7 hours of sleep and a solid step count, you're on the right track for staying healthy and energized. Use this free time to relax or pursue something you love!",
                keyCorrelations: [
                    "Good sleep (7+ hours) correlates with better focus and decision-making",
                    "Regular hydration improves cognitive performance by 25%",
                    "Taking breaks every 90 minutes increases productivity by 15%"
                ],
                healthTrends: HealthTrends(
                    sleep: "improving",
                    steps: "stable",
                    activeMinutes: "declining",
                    restingHeartRate: "stable",
                    hrv: "improving"
                )
            )
        )
    }
}

