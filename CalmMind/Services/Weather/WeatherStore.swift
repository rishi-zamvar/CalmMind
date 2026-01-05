import Foundation
import CoreLocation

/// Weather history and cache management for journal correlation
/// All thresholds from config, NO magic numbers
final class WeatherStore {

    // MARK: - Cache Keys

    private enum Keys {
        static let weatherHistory = "weather_history"
        static let locationLat = "weather_location_lat"
        static let locationLon = "weather_location_lon"
        static let locationAt = "weather_location_at"
        static let weatherCache = "weather_cache_current"
        static let weatherCacheAt = "weather_cache_at"
    }

    // MARK: - Properties

    private let defaults: UserDefaults
    private let config: WeatherConfig

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard, config: WeatherConfig = .shared) {
        self.defaults = defaults
        self.config = config
    }

    // MARK: - Record Weather (for journal correlation)

    func record(_ weather: Weather) {
        var history = loadHistory()
        history.append(weather)

        // Prune old entries (keep last 7 days)
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        history = history.filter { $0.timestamp >= cutoff }

        saveHistory(history)
    }

    // MARK: - Get History

    func getHistory(for date: Date) -> [Weather] {
        let history = loadHistory()
        let calendar = Calendar.current

        return history.filter { weather in
            calendar.isDate(weather.timestamp, inSameDayAs: date)
        }.sorted { $0.timestamp < $1.timestamp }
    }

    func getRecentDays() -> [Weather] {
        return getRecentDays(count: config.rainyDaysLookbackWindow)
    }

    func getRecentDays(count: Int) -> [Weather] {
        let history = loadHistory()
        let cutoff = Calendar.current.date(byAdding: .day, value: -count, to: Date()) ?? Date()

        return history
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Weather Progression

    func getProgression(for date: Date) -> WeatherProgression {
        let snapshots = getHistory(for: date)

        guard !snapshots.isEmpty else {
            return WeatherProgression(
                snapshots: [],
                dominantCondition: .clouds,
                hadTransition: false,
                transitionDescription: nil
            )
        }

        // Find dominant condition
        let conditionCounts = Dictionary(grouping: snapshots, by: { $0.condition })
        let dominantCondition = conditionCounts.max(by: { $0.value.count < $1.value.count })?.key ?? .clouds

        // Detect transition
        var hadTransition = false
        var transitionDescription: String? = nil

        if snapshots.count >= 2 {
            let firstCondition = snapshots.first?.condition
            let lastCondition = snapshots.last?.condition

            if firstCondition != lastCondition {
                hadTransition = true

                // Generate natural language description
                if let first = firstCondition, let last = lastCondition {
                    transitionDescription = describeTransition(from: first, to: last)
                }
            }
        }

        return WeatherProgression(
            snapshots: snapshots,
            dominantCondition: dominantCondition,
            hadTransition: hadTransition,
            transitionDescription: transitionDescription
        )
    }

    // MARK: - Location Cache

    func cacheLocation(latitude: Double, longitude: Double) {
        defaults.set(latitude, forKey: Keys.locationLat)
        defaults.set(longitude, forKey: Keys.locationLon)
        defaults.set(Date(), forKey: Keys.locationAt)
    }

    func getCachedLocation() -> CLLocationCoordinate2D? {
        guard defaults.object(forKey: Keys.locationLat) != nil else { return nil }
        let lat = defaults.double(forKey: Keys.locationLat)
        let lon = defaults.double(forKey: Keys.locationLon)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func shouldRefreshLocation() -> Bool {
        guard let lastAt = defaults.object(forKey: Keys.locationAt) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastAt) > config.refreshIntervalSeconds
    }

    // MARK: - Weather Cache

    func cacheWeather(_ weather: Weather) {
        guard let data = try? JSONEncoder().encode(weather) else { return }
        defaults.set(data, forKey: Keys.weatherCache)
        defaults.set(Date(), forKey: Keys.weatherCacheAt)
    }

    func getCachedWeather() -> Weather? {
        guard let data = defaults.data(forKey: Keys.weatherCache) else { return nil }
        return try? JSONDecoder().decode(Weather.self, from: data)
    }

    func shouldRefreshWeather() -> Bool {
        guard let lastAt = defaults.object(forKey: Keys.weatherCacheAt) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastAt) > config.refreshIntervalSeconds
    }

    // MARK: - Private Helpers

    private func loadHistory() -> [Weather] {
        guard let data = defaults.data(forKey: Keys.weatherHistory) else { return [] }
        return (try? JSONDecoder().decode([Weather].self, from: data)) ?? []
    }

    private func saveHistory(_ history: [Weather]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Keys.weatherHistory)
    }

    private func describeTransition(from: WeatherCondition, to: WeatherCondition) -> String {
        switch (from, to) {
        case (.rain, .clear), (.drizzle, .clear), (.thunderstorm, .clear):
            return "Started rainy, cleared up later"
        case (.clear, .rain), (.clear, .drizzle), (.clear, .thunderstorm):
            return "Started clear, became rainy"
        case (.clouds, .clear):
            return "Cloudy morning, cleared up"
        case (.clear, .clouds):
            return "Clear morning, became cloudy"
        case (.snow, .clear):
            return "Snowy earlier, cleared up"
        case (_, .rain), (_, .thunderstorm):
            return "Weather turned rainy"
        case (_, .clear):
            return "Weather cleared up"
        default:
            return "Weather changed through the day"
        }
    }
}

// MARK: - Weather Progression

struct WeatherProgression: Sendable {
    let snapshots: [Weather]
    let dominantCondition: WeatherCondition
    let hadTransition: Bool
    let transitionDescription: String?
}
