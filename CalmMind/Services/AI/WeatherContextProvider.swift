import Foundation

/// Discretionary weather context for AI conversations
/// CONSERVATIVE: Only mention weather when clearly relevant
/// All thresholds from config, NO magic numbers
struct WeatherContextProvider {

    // MARK: - Should Mention Weather

    /// Determine if weather should be mentioned
    /// PRIORITY ORDER: Extreme > Transition > MildlyUncomfortable > MentionConditions > FirstClear
    ///
    /// Returns true for:
    /// 1. Extreme conditions (rain, snow, thunderstorm, extreme temps <=32°F or >=95°F)
    /// 2. Notable transitions today (rain → clear)
    /// 3. Mild discomfort (chilly 32-45°F or warm 85-95°F)
    /// 4. Mention-worthy conditions (drizzle, mist, fog)
    /// 5. First clear day after rainy yesterday
    ///
    /// Does NOT return true for:
    /// - Normal pleasant weather (60-80°F and clear/cloudy)
    static func shouldMentionWeather(
        current: Weather?,
        progression: WeatherProgression?,
        recentHistory: [Weather]?,
        config: WeatherConfig = .shared
    ) -> Bool {
        guard let current = current else { return false }

        // 1. Extreme weather: HIGHEST PRIORITY - always relevant
        if current.isExtreme(config: config) {
            return true
        }

        // 2. Notable transition TODAY (rain → clear, etc.)
        if progression?.hadTransition == true {
            return true
        }

        // 3. Mild discomfort (chilly or warm) - only if NOT extreme
        if current.isMildlyUncomfortable(config: config) {
            return true
        }

        // 4. Conditions from config.mentionConditions (drizzle, mist, fog)
        if config.mentionConditions.contains(current.condition) {
            return true
        }

        // 5. First clear day after rainy YESTERDAY
        // Use explicit date equality, NOT array index assumption
        if current.condition == .clear,
           let history = recentHistory,
           !history.isEmpty {
            let calendar = Calendar.current
            let now = Date()
            guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else {
                return false
            }

            // Find record for yesterday by date equality, not by index
            if let yesterdayRecord = history.first(where: { calendar.isDate($0.timestamp, inSameDayAs: yesterdayStart) }) {
                // If yesterday was rainy, and today is clear → transition mention
                if config.rainyConditions.contains(yesterdayRecord.condition) {
                    return true
                }
            }
        }

        // Otherwise: DO NOT mention (avoid eager pleasant-day triggers)
        return false
    }

    // MARK: - Build Context

    /// Build natural language weather context with discretion instruction
    /// Returns nil if weather should not be mentioned
    static func buildContext(
        current: Weather?,
        progression: WeatherProgression?,
        location: String?,
        recentHistory: [Weather]? = nil,
        config: WeatherConfig = .shared
    ) -> String? {
        // Check if we should mention weather at all
        guard shouldMentionWeather(
            current: current,
            progression: progression,
            recentHistory: recentHistory,
            config: config
        ) else {
            return nil
        }

        guard let current = current else { return nil }

        var lines: [String] = []

        // Weather context header
        lines.append("Weather context (use only if directly relevant):")
        lines.append("Currently \(current.displayString) in \(location ?? current.locationName).")

        // Add transition info if available
        if let transition = progression?.transitionDescription {
            lines.append(transition)
        }

        // IMPORTANT: Discretion instruction
        lines.append("")
        lines.append("IMPORTANT: Mention weather ONLY when it directly improves the response")
        lines.append("or helps with emotional grounding. Otherwise omit entirely.")

        return lines.joined(separator: "\n")
    }
}
