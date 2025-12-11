import Foundation

class SummaryParser {
    func parse(_ summary: DailySummary) -> ParsedSummary {
        var parsed = ParsedSummary(
            sleepStatus: .good,
            dehydrationRisk: false,
            suggestedBreaks: [],
            totalMeetings: 0,
            meetingDuration: 0,
            criticalAlerts: [],
            warnings: []
        )

        // Parse health summary for metrics
        for line in summary.healthSummary {
            // Extract sleep hours
            if let sleepMatch = extractPattern(from: line, pattern: #"(\d+\.?\d*) hours? of sleep"#) {
                let hours = Double(sleepMatch) ?? 0
                parsed.sleepHours = hours
                parsed.sleepStatus = determineSleepStatus(hours)
            }

            // Extract steps - use capture group 1 to get just the number part
            if let stepsMatch = extractPattern(from: line, pattern: #"(\d{1,3}(?:,\d{3})*|\d+) steps"#, captureGroup: 1) {
                let stepsStr = stepsMatch.replacingOccurrences(of: ",", with: "")
                parsed.steps = Int(stepsStr)
            }

            // Extract steps goal - use capture group 1
            if let stepsGoalMatch = extractPattern(from: line, pattern: #"(\d{1,3}(?:,\d{3})*|\d+) step goal"#, captureGroup: 1) {
                let goalStr = stepsGoalMatch.replacingOccurrences(of: ",", with: "")
                parsed.stepsGoal = Int(goalStr)
            }

            // Extract active minutes
            if let activeMatch = extractPattern(from: line, pattern: #"(\d+) active minutes"#) {
                parsed.activeMinutes = Int(activeMatch)
            }

            // Extract active minutes goal
            if let activeGoalMatch = extractPattern(from: line, pattern: #"goal of (\d+) minutes"#, captureGroup: 1) {
                parsed.activeMinutesGoal = Int(activeGoalMatch)
            }

            // Extract water intake
            if let waterMatch = extractPattern(from: line, pattern: #"(\d+\.?\d*) liters? of water"#) {
                parsed.waterIntake = Double(waterMatch)
            }

            // Extract water goal
            if let waterGoalMatch = extractPattern(from: line, pattern: #"drink at least (\d+\.?\d*) liters"#, captureGroup: 1) {
                parsed.waterGoal = Double(waterGoalMatch)
            } else if let waterGoalMatch2 = extractPattern(from: line, pattern: #"(\d+\.?\d*) liters? below your goal"#) {
                // Calculate goal from deficit
                if let intake = parsed.waterIntake {
                    let deficit = Double(waterGoalMatch2) ?? 0
                    parsed.waterGoal = intake + deficit
                }
            }

            // Detect dehydration risk
            if line.lowercased().contains("dehydration") {
                parsed.dehydrationRisk = true
            }
        }

        // Parse day summary for meeting metrics
        for line in summary.daySummary {
            if let meetingMatch = extractPattern(from: line, pattern: #"(\d+) meetings? scheduled"#) {
                parsed.totalMeetings = Int(meetingMatch) ?? 0
            }

            if let durationMatch = extractPattern(from: line, pattern: #"(\d+) minutes"#) {
                parsed.meetingDuration = TimeInterval((Int(durationMatch) ?? 0) * 60)
            }
        }

        // Parse focus recommendations for breaks
        for line in summary.focusRecommendations {
            if line.contains("🔄 Break Strategy:") {
                parsed.breakStrategy = line.replacingOccurrences(of: "🔄 Break Strategy: ", with: "")
            }

            // Parse individual break windows
            if line.contains("🔔") {
                if let breakWindow = parseBreakWindow(from: line) {
                    parsed.suggestedBreaks.append(breakWindow)
                }
            }
        }

        // Parse alerts
        for alert in summary.alerts {
            let parsedAlert = Alert(
                message: alert,
                severity: determineSeverity(from: alert),
                category: determineCategory(from: alert)
            )

            if parsedAlert.severity == .critical {
                parsed.criticalAlerts.append(parsedAlert)
            } else {
                parsed.warnings.append(parsedAlert)
            }
        }

        return parsed
    }

    // MARK: - Helper Methods

    private func extractPattern(from text: String, pattern: String, captureGroup: Int = 0) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }

        let matchRange = match.range(at: captureGroup)
        guard matchRange.location != NSNotFound,
              let range = Range(matchRange, in: text) else {
            return nil
        }

        var result = String(text[range])

        // Clean up the result - extract just numbers and decimal points
        if captureGroup == 0 {
            // Extract first number/decimal from the match
            let numberPattern = #"\d+\.?\d*"#
            if let numberRegex = try? NSRegularExpression(pattern: numberPattern, options: []) {
                let numberRange = NSRange(result.startIndex..., in: result)
                if let numberMatch = numberRegex.firstMatch(in: result, range: numberRange) {
                    let numRange = numberMatch.range
                    if let numSwiftRange = Range(numRange, in: result) {
                        result = String(result[numSwiftRange])
                    }
                }
            }
        }

        return result
    }

    private func parseBreakWindow(from line: String) -> BreakWindow? {
        // Example: "🔔 MEAL: 45-min meal break at 12:30 PM - No clear lunch break detected"
        let components = line.components(separatedBy: ": ")
        guard components.count >= 2 else { return nil }

        let typeStr = components[0].replacingOccurrences(of: "🔔 ", with: "")
        let details = components.dropFirst().joined(separator: ": ")

        // Extract duration
        guard let durationMatch = extractPattern(from: details, pattern: #"(\d+)-min"#) else {
            return nil
        }
        let duration = Int(durationMatch) ?? 15

        // Extract time
        guard let timeMatch = extractPattern(from: details, pattern: #"at (\d{1,2}:\d{2} [AP]M)"#, captureGroup: 1) else {
            return nil
        }
        let time = parseTime(timeMatch) ?? Date()

        // Extract reasoning
        let reasoning = details.components(separatedBy: " - ").last ?? ""

        let type: BreakType
        switch typeStr.uppercased() {
        case "HYDRATION": type = .hydration
        case "MEAL": type = .meal
        case "REST": type = .rest
        case "MOVEMENT": type = .movement
        case "PREP": type = .prep
        default: type = .rest
        }

        return BreakWindow(
            time: time,
            duration: duration,
            type: type,
            reasoning: reasoning
        )
    }

    private func determineSleepStatus(_ hours: Double) -> SleepStatus {
        if hours >= 8.0 { return .excellent }
        if hours >= 7.0 { return .good }
        if hours >= 6.0 { return .fair }
        return .poor
    }

    private func determineSeverity(from alert: String) -> AlertSeverity {
        if alert.contains("🚨") || alert.lowercased().contains("critical") {
            return .critical
        } else if alert.contains("⚠️") {
            return .warning
        }
        return .info
    }

    private func determineCategory(from alert: String) -> AlertCategory {
        let lowercased = alert.lowercased()
        if lowercased.contains("sleep") {
            return .sleep
        } else if lowercased.contains("water") || lowercased.contains("hydration") {
            return .hydration
        } else if lowercased.contains("step") || lowercased.contains("activity") || lowercased.contains("exercise") {
            return .activity
        } else if lowercased.contains("stress") {
            return .stress
        }
        return .recovery
    }

    private func parseTime(_ timeStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current

        if let time = formatter.date(from: timeStr) {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: time)
            return calendar.date(bySettingHour: components.hour ?? 0,
                                minute: components.minute ?? 0,
                                second: 0,
                                of: Date())
        }
        return nil
    }
}
