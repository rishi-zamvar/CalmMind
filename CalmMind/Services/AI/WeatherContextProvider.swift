import Foundation

/// Discretionary weather context for AI conversations
/// CONSERVATIVE: Only mention weather when clearly relevant
/// All thresholds from config, NO magic numbers
struct WeatherContextProvider {

    // MARK: - Should Mention Weather

    /// Determine if weather should be mentioned - CONSERVATIVE logic
    /// Only returns true for:
    /// 1. Extreme conditions (rain, snow, thunderstorm, extreme temps)
    /// 2. Notable transitions today (rain → clear)
    /// 3. First clear day after multiple rainy days
    ///
    /// Does NOT return true for:
    /// - Normal pleasant weather
    /// - Cloudy but otherwise unremarkable days
    static func shouldMentionWeather(
        current: Weather?,
        progression: WeatherProgression?,
        recentHistory: [Weather]?,
        config: WeatherConfig = .shared
    ) -> Bool {
        guard let current = current else { return false }

        // 1. Extreme weather: always relevant (uses config thresholds)
        if current.isExtreme(config: config) {
            return true
        }

        // 2. Notable transition TODAY (rain → clear, etc.)
        if progression?.hadTransition == true {
            return true
        }

        // 3. First clear day after multiple rainy days
        // Uses config.rainyDaysLookbackWindow and config.minRainyDaysForTransition
        if current.condition == .clear,
           let history = recentHistory,
           !history.isEmpty {
            let rainyDays = history.filter { $0.condition == .rain || $0.condition == .drizzle || $0.condition == .thunderstorm }
            if rainyDays.count >= config.minRainyDaysForTransition {
                return true
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
