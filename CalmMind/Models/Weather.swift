import Foundation

/// Weather data model with config-driven temperature classifications
/// All thresholds reference WeatherConfig, NO magic numbers here
struct Weather: Codable, Sendable, Equatable {

    /// Temperature in Fahrenheit (API returns imperial units)
    let temperature: Double

    /// Weather condition category
    let condition: WeatherCondition

    /// Human-readable description from API (e.g., "light rain", "clear sky")
    let description: String

    /// Humidity percentage (0-100)
    let humidity: Int

    /// Location name from API
    let locationName: String

    /// When this weather was recorded
    let timestamp: Date

    // MARK: - Temperature Classification (Config-Driven)

    /// Check if weather is extreme (uses config thresholds)
    /// BOUNDARY: <= extremeColdThreshold OR >= extremeHeatThreshold
    /// - Parameter config: Weather configuration for thresholds
    /// - Returns: true if condition is extreme OR temperature outside thresholds
    func isExtreme(config: WeatherConfig = .shared) -> Bool {
        condition.isExtreme ||
        temperature <= config.extremeColdThreshold ||
        temperature >= config.extremeHeatThreshold
    }

    /// Check if weather is pleasant (uses config thresholds)
    /// - Parameter config: Weather configuration for thresholds
    /// - Returns: true if clear sky AND temperature in pleasant range
    func isPleasant(config: WeatherConfig = .shared) -> Bool {
        condition.isPleasant &&
        temperature >= config.pleasantTempMin &&
        temperature <= config.pleasantTempMax
    }

    /// Check if weather is mildly uncomfortable (worth mentioning but not extreme)
    /// BOUNDARY: Non-overlapping with isExtreme - see partition table:
    /// | temp <= 32      | Extreme cold (NOT mild)
    /// | 32 < temp < 45  | Mild cold (chilly)
    /// | 45 <= temp < 85 | Comfortable (NOT mild)
    /// | 85 <= temp < 95 | Mild hot (warm)
    /// | temp >= 95      | Extreme hot (NOT mild)
    /// - Parameter config: Weather configuration for thresholds
    /// - Returns: true if temperature is in chilly or warm range (but not extreme)
    func isMildlyUncomfortable(config: WeatherConfig = .shared) -> Bool {
        // Chilly range: strictly above extreme cold, strictly below mild cold threshold
        let isChilly = temperature > config.extremeColdThreshold && temperature < config.mildColdThreshold
        // Warm range: at or above mild heat threshold, strictly below extreme heat
        let isWarm = temperature >= config.mildHeatThreshold && temperature < config.extremeHeatThreshold
        return isChilly || isWarm
    }

    /// Formatted temperature with units (for accessibility)
    var formattedTemperature: String {
        "\(Int(temperature)) degrees Fahrenheit"
    }

    // MARK: - Display Formatting

    /// For system prompt context: "58°F, Sunny"
    var displayString: String {
        "\(Int(temperature))°F, \(condition.displayName)"
    }

    /// For WeatherCard compact line: "San Francisco · 58°F ☀️"
    var compactLine: String {
        "\(locationName) · \(Int(temperature))°F \(condition.emoji)"
    }
}

// MARK: - Weather Condition

/// Weather condition categories from OpenWeather API
enum WeatherCondition: String, Codable, CaseIterable, Sendable {
    case clear
    case clouds
    case rain
    case drizzle
    case thunderstorm
    case snow
    case mist
    case fog

    /// Initialize from OpenWeather API "main" field
    /// - Parameter apiMain: The "main" field from API response (e.g., "Clear", "Rain")
    init(apiMain: String) {
        let normalized = apiMain.lowercased()
        switch normalized {
        case "clear":
            self = .clear
        case "clouds":
            self = .clouds
        case "rain":
            self = .rain
        case "drizzle":
            self = .drizzle
        case "thunderstorm":
            self = .thunderstorm
        case "snow":
            self = .snow
        case "mist", "haze", "smoke", "dust", "sand", "ash", "squall", "tornado":
            self = .mist
        case "fog":
            self = .fog
        default:
            self = .clouds  // Default to neutral
        }
    }

    /// True for conditions that are inherently extreme (rain, storm, snow)
    var isExtreme: Bool {
        switch self {
        case .rain, .thunderstorm, .snow:
            return true
        case .clear, .clouds, .drizzle, .mist, .fog:
            return false
        }
    }

    /// True only for clear weather
    var isPleasant: Bool {
        self == .clear
    }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .clear: return "Sunny"
        case .clouds: return "Cloudy"
        case .rain: return "Rainy"
        case .drizzle: return "Drizzle"
        case .thunderstorm: return "Stormy"
        case .snow: return "Snowy"
        case .mist: return "Misty"
        case .fog: return "Foggy"
        }
    }

    /// Weather emoji for compact display
    var emoji: String {
        switch self {
        case .clear: return "☀️"
        case .clouds: return "☁️"
        case .rain: return "🌧️"
        case .drizzle: return "🌦️"
        case .thunderstorm: return "⛈️"
        case .snow: return "❄️"
        case .mist, .fog: return "🌫️"
        }
    }
}

// MARK: - OpenWeather API Response

/// Intermediate type for decoding OpenWeather API responses
struct OpenWeatherResponse: Codable {

    struct Main: Codable {
        let temp: Double
        let humidity: Int
    }

    struct WeatherInfo: Codable {
        let main: String
        let description: String
    }

    let main: Main
    let weather: [WeatherInfo]
    let name: String

    /// Convert API response to Weather model
    func toWeather() -> Weather {
        let firstWeather = weather.first ?? WeatherInfo(main: "Clouds", description: "unknown")
        return Weather(
            temperature: main.temp,
            condition: WeatherCondition(apiMain: firstWeather.main),
            description: firstWeather.description,
            humidity: main.humidity,
            locationName: name,
            timestamp: Date()
        )
    }
}
