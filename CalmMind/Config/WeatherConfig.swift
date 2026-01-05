import Foundation

/// Configuration for weather features - all tunable values centralized
/// NO MAGIC NUMBERS: All values live here, implementation references config
struct WeatherConfig {

    // MARK: - Defaults (easily adjustable)

    enum Defaults {
        // API
        static let apiEndpoint = "https://api.openweathermap.org/data/2.5/weather"
        static let units = "imperial"  // PINNED: Fahrenheit only

        // Throttling
        static let refreshIntervalMinutes = 30
        static let cacheExpirationMinutes = 60

        // Extreme temperature thresholds (°F)
        static let extremeColdThreshold: Double = 32
        static let extremeHeatThreshold: Double = 95

        // Pleasant temperature range (°F)
        static let pleasantTempMin: Double = 60
        static let pleasantTempMax: Double = 80

        // Weather transition detection
        static let rainyDaysLookbackWindow = 3   // Days to look back for rain pattern
        static let minRainyDaysForTransition = 2 // Min rainy days to trigger "first clear" mention
    }

    // MARK: - Properties

    /// OpenWeather API endpoint
    let apiEndpoint: String

    /// Temperature units (imperial = Fahrenheit)
    let units: String

    /// Minutes between location/weather refresh attempts
    let refreshIntervalMinutes: Int

    /// Minutes before cached weather expires
    let cacheExpirationMinutes: Int

    /// Temperature below which weather is considered extreme cold (°F)
    let extremeColdThreshold: Double

    /// Temperature above which weather is considered extreme heat (°F)
    let extremeHeatThreshold: Double

    /// Minimum temperature for "pleasant" classification (°F)
    let pleasantTempMin: Double

    /// Maximum temperature for "pleasant" classification (°F)
    let pleasantTempMax: Double

    /// Days to look back when detecting rain → clear transitions
    let rainyDaysLookbackWindow: Int

    /// Minimum rainy days in lookback window to trigger "first clear day" mention
    let minRainyDaysForTransition: Int

    // MARK: - Computed Properties

    /// Refresh interval in seconds (for TimeInterval comparisons)
    var refreshIntervalSeconds: TimeInterval {
        TimeInterval(refreshIntervalMinutes * 60)
    }

    /// Cache expiration in seconds (for TimeInterval comparisons)
    var cacheExpirationSeconds: TimeInterval {
        TimeInterval(cacheExpirationMinutes * 60)
    }

    // MARK: - Initialization

    /// Initialize with specific values - all injectable for testing
    init(
        apiEndpoint: String = Defaults.apiEndpoint,
        units: String = Defaults.units,
        refreshIntervalMinutes: Int = Defaults.refreshIntervalMinutes,
        cacheExpirationMinutes: Int = Defaults.cacheExpirationMinutes,
        extremeColdThreshold: Double = Defaults.extremeColdThreshold,
        extremeHeatThreshold: Double = Defaults.extremeHeatThreshold,
        pleasantTempMin: Double = Defaults.pleasantTempMin,
        pleasantTempMax: Double = Defaults.pleasantTempMax,
        rainyDaysLookbackWindow: Int = Defaults.rainyDaysLookbackWindow,
        minRainyDaysForTransition: Int = Defaults.minRainyDaysForTransition
    ) {
        self.apiEndpoint = apiEndpoint
        self.units = units
        self.refreshIntervalMinutes = refreshIntervalMinutes
        self.cacheExpirationMinutes = cacheExpirationMinutes
        self.extremeColdThreshold = extremeColdThreshold
        self.extremeHeatThreshold = extremeHeatThreshold
        self.pleasantTempMin = pleasantTempMin
        self.pleasantTempMax = pleasantTempMax
        self.rainyDaysLookbackWindow = rainyDaysLookbackWindow
        self.minRainyDaysForTransition = minRainyDaysForTransition
    }

    // MARK: - URL Building

    /// Build OpenWeather API URL with all required parameters
    /// - Parameters:
    ///   - lat: Latitude
    ///   - lon: Longitude
    ///   - apiKey: OpenWeather API key
    /// - Returns: Complete URL with units param ALWAYS explicit
    func buildURL(lat: Double, lon: Double, apiKey: String) -> URL {
        var components = URLComponents(string: apiEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lon", value: String(lon)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: units)  // ALWAYS explicit
        ]
        return components.url!
    }
}

// MARK: - Shared Instance

extension WeatherConfig {
    /// Shared instance using defaults
    static let shared = WeatherConfig()
}
