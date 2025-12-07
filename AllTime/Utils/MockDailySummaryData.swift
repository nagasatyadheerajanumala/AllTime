import Foundation

/// Mock data for testing and previewing the premium daily summary UI
struct MockDailySummaryData {
    
    /// Generate mock daily summary with rich, realistic data
    static func generateMockSummary() -> DailySummary {
        return DailySummary(
            daySummary: [
                "You have 6 meetings scheduled today, totaling 240 minutes (4.0 hours)",
                "Your day starts with \"Team Standup\" at 9:00 AM",
                "  → Location: Conference Room A",
                "Key meetings today:",
                "  • Sprint Planning at 10:00 AM (90 minutes)",
                "  • Client Review at 2:00 PM (60 minutes)",
                "  • 1-on-1 with Manager at 4:00 PM (30 minutes)",
                "Today is a heavy meeting day (67% above your average) - consider protecting time for focused work",
                "You have 2.5 hours of evening commitments (after 6 PM) - plan your day accordingly",
                "Your last meeting \"Team Sync\" ends at 5:00 PM"
            ],
            healthSummary: [
                "You got 7.5 hours of sleep last night, right on track with your average of 7.5 hours",
                "You got excellent sleep last night - you should have good energy today",
                "You took 8,245 steps yesterday - 1,755 short of your 10,000 step goal - aim to close the gap today",
                "You had 45 active minutes yesterday - exceeded your goal by 15 minutes!",
                "You completed 2 workouts yesterday including 3.2 km of walking and 5.1 km of running",
                "You drank 1.8 liters of water yesterday - 0.7 liters below your goal",
                "💧 With 6 meetings today (4.0 hours), aim to drink at least 1.5 liters of water throughout the day",
                "Your resting heart rate is 62 BPM, stable and consistent with your baseline",
                "Your recovery score is excellent (85%) - you're well-rested and ready for a productive day"
            ],
            focusRecommendations: [
                "🔄 Break Strategy: MODERATE LOAD: Busy day ahead - take at least one 5-minute break every hour to stay fresh and hydrated",
                "🔔 MEAL: 45-min meal break at 12:30 PM - No clear lunch break detected - block 45 minutes for a proper meal and recharge",
                "🔔 HYDRATION: 5-min hydration break at 10:00 AM - Keep water nearby during meetings to stay hydrated",
                "🔔 MOVEMENT: 20-min movement break at 3:00 PM - Yesterday's step count was low - take a walk to boost circulation and energy",
                "🔔 REST: 10-min rest break at 11:30 AM - Between back-to-back meetings - take a mental break",
                "You have a 90-minute focus block from 2:00 PM to 3:30 PM - perfect for deep work or tackling a complex project",
                "The best time for deep work today is around 11:00 AM (you have 75 minutes until lunch)",
                "You have back-to-back meetings: \"Sprint Planning\" leads directly into \"Team Discussion\" at 11:30 AM - consider a quick 5-minute break",
                "🍽️ You have a good lunch window from 12:30 PM to 1:15 PM - use this time to eat and recharge",
                "Given your recovery metrics, consider scheduling lighter tasks and taking more breaks between meetings today"
            ],
            alerts: [
                "⚠️ Busy day ahead: You have 6 meetings totaling 240 minutes - make sure to take breaks between sessions",
                "💧 Water intake low: You're 0.7 liters below your daily water goal - keep a water bottle nearby during meetings",
                "⚠️ Steps goal not met: You're 1,755 steps short of your daily goal - try to close the gap today",
                "⚠️ You have 1 back-to-back meeting(s) today - consider adding buffer time between meetings to avoid rushing"
            ]
        )
    }
    
    /// Generate empty summary (no events, no health data)
    static func generateEmptySummary() -> DailySummary {
        return DailySummary(
            daySummary: [
                "No events scheduled for this day"
            ],
            healthSummary: [
                "Health tracking is available. Connect HealthKit to see personalized insights."
            ],
            focusRecommendations: [],
            alerts: []
        )
    }
    
    /// Generate light day summary (few meetings, good health)
    static func generateLightDaySummary() -> DailySummary {
        return DailySummary(
            daySummary: [
                "You have 2 meetings scheduled today, totaling 90 minutes (1.5 hours)",
                "Your day starts with \"Team Standup\" at 9:00 AM",
                "Today is a light meeting day - you have plenty of time for focused work",
                "Your last meeting ends at 10:30 AM"
            ],
            healthSummary: [
                "You got 8.2 hours of sleep last night - excellent rest!",
                "You took 10,500 steps yesterday - exceeded your goal by 500 steps!",
                "You drank 2.6 liters of water yesterday - above your goal!",
                "You had 35 active minutes yesterday",
                "Your recovery score is excellent (92%) - you're in great shape"
            ],
            focusRecommendations: [
                "🔄 Break Strategy: LIGHT DAY: Perfect day for deep work - maintain regular 15-minute breaks every 2 hours",
                "🔔 HYDRATION: 5-min hydration break at 11:00 AM - Maintain your excellent hydration",
                "You have a 6-hour focus block from 11:00 AM to 5:00 PM - ideal for tackling important projects",
                "With only 2 meetings, you have excellent flexibility today - prioritize your most challenging work"
            ],
            alerts: [
                "✅ Great recovery: You're well-rested and hydrated - perfect conditions for productivity"
            ]
        )
    }
    
    /// Generate heavy day summary (many meetings, some health concerns)
    static func generateHeavyDaySummary() -> DailySummary {
        return DailySummary(
            daySummary: [
                "You have 9 meetings scheduled today, totaling 360 minutes (6.0 hours)",
                "Your day starts with \"Executive Briefing\" at 8:00 AM",
                "  → Location: Zoom",
                "Key meetings today:",
                "  • Board Meeting at 9:00 AM (120 minutes)",
                "  • Product Review at 11:30 AM (90 minutes)",
                "  • Customer Call at 2:00 PM (60 minutes)",
                "Today is an extremely heavy meeting day (150% above your average) - very little time for focused work",
                "You have 4 back-to-back meetings without breaks",
                "Your last meeting \"Team Retrospective\" ends at 6:30 PM"
            ],
            healthSummary: [
                "You got 5.5 hours of sleep last night - 2 hours below your goal",
                "Poor sleep detected - you may have low energy today, plan accordingly",
                "You took 4,200 steps yesterday - 5,800 short of your 10,000 step goal",
                "You had only 15 active minutes yesterday - well below your 30-minute goal",
                "You drank 1.2 liters of water yesterday - 1.3 liters below your goal",
                "🚨 DEHYDRATION RISK: Very low water intake with heavy meeting schedule",
                "Your resting heart rate is elevated at 72 BPM (baseline: 62 BPM) - possible stress indicator",
                "Your recovery score is low (45%) - you're not fully recovered from yesterday"
            ],
            focusRecommendations: [
                "🔄 Break Strategy: CRITICAL: VERY heavy meeting load (6 hours) - you MUST take breaks or risk burnout",
                "🔔 HYDRATION: 5-min hydration break at 10:00 AM - URGENT: Keep water accessible during all meetings",
                "🔔 MEAL: 60-min meal break at 12:30 PM - REQUIRED: You need proper nutrition to sustain this schedule",
                "🔔 REST: 15-min rest break at 2:00 PM - Mental reset needed after 3 hours of continuous meetings",
                "🔔 MOVEMENT: 10-min movement break at 4:00 PM - Combat prolonged sitting, stretch your legs",
                "⚠️ You have very little time for deep work today - consider rescheduling non-critical meetings if possible",
                "🚨 WELLNESS ALERT: Low sleep + low recovery + heavy schedule = high burnout risk",
                "Consider declining optional meetings or delegating to preserve your energy"
            ],
            alerts: [
                "🚨 CRITICAL: Sleep deficit (5.5h) + heavy meeting load (6h) - high risk of poor decision-making and stress",
                "🚨 DEHYDRATION RISK: Only 1.2L yesterday with 9 meetings today - set hourly water reminders",
                "⚠️ Extremely busy day: 9 meetings totaling 360 minutes - protect your breaks at all costs",
                "⚠️ 4 back-to-back meetings detected - this violates healthy meeting practices",
                "⚠️ Steps and activity critically low - try to walk between meetings",
                "😰 Elevated stress indicators: High heart rate + low recovery - monitor your stress levels today"
            ]
        )
    }
}

