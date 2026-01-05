import XCTest
@testable import CalmMind

/// Tests for WeatherConfig - all tunable weather values centralized
/// TDD: These tests are written FIRST, implementation follows
final class WeatherConfigTests: XCTestCase {

    // MARK: - API Defaults

    func test_defaults_apiEndpoint() {
        let config = WeatherConfig()
        XCTAssertEqual(config.apiEndpoint, "https://api.openweathermap.org/data/2.5/weather")
    }

    func test_defaults_units_imperial() {
        // PINNED: Fahrenheit only
        let config = WeatherConfig()
        XCTAssertEqual(config.units, "imperial")
    }

    // MARK: - Throttling Defaults

    func test_defaults_refreshIntervalMinutes() {
        let config = WeatherConfig()
        XCTAssertEqual(config.refreshIntervalMinutes, 30)
    }

    func test_defaults_cacheExpirationMinutes() {
        let config = WeatherConfig()
        XCTAssertEqual(config.cacheExpirationMinutes, 60)
    }

    // MARK: - Temperature Thresholds

    func test_defaults_extremeColdThreshold() {
        let config = WeatherConfig()
        XCTAssertEqual(config.extremeColdThreshold, 32, accuracy: 0.001)  // °F
    }

    func test_defaults_extremeHeatThreshold() {
        let config = WeatherConfig()
        XCTAssertEqual(config.extremeHeatThreshold, 95, accuracy: 0.001)  // °F
    }

    func test_defaults_pleasantTempMin() {
        let config = WeatherConfig()
        XCTAssertEqual(config.pleasantTempMin, 60, accuracy: 0.001)  // °F
    }

    func test_defaults_pleasantTempMax() {
        let config = WeatherConfig()
        XCTAssertEqual(config.pleasantTempMax, 80, accuracy: 0.001)  // °F
    }

    // MARK: - Weather Transition Thresholds

    func test_defaults_rainyDaysLookbackWindow() {
        let config = WeatherConfig()
        XCTAssertEqual(config.rainyDaysLookbackWindow, 3)
    }

    func test_defaults_minRainyDaysForTransition() {
        let config = WeatherConfig()
        XCTAssertEqual(config.minRainyDaysForTransition, 2)
    }

    // MARK: - URL Building

    func test_buildURL_includesAllParams() {
        let config = WeatherConfig()
        let url = config.buildURL(lat: 37.7749, lon: -122.4194, apiKey: "test-key")

        XCTAssertNotNil(url)
        let urlString = url.absoluteString
        XCTAssertTrue(urlString.contains("lat=37.7749"))
        XCTAssertTrue(urlString.contains("lon=-122.4194"))
        XCTAssertTrue(urlString.contains("appid=test-key"))
    }

    func test_buildURL_includesUnitsParam_always() {
        // CRITICAL: units param must ALWAYS be explicit
        let config = WeatherConfig()
        let url = config.buildURL(lat: 0, lon: 0, apiKey: "key")

        let urlString = url.absoluteString
        XCTAssertTrue(urlString.contains("units=imperial"))
    }

    func test_buildURL_usesConfigEndpoint() {
        let customConfig = WeatherConfig(apiEndpoint: "https://custom.api.com/weather")
        let url = customConfig.buildURL(lat: 0, lon: 0, apiKey: "key")

        XCTAssertTrue(url.absoluteString.starts(with: "https://custom.api.com/weather"))
    }

    // MARK: - Shared Instance

    func test_shared_returnsSameInstance() {
        let instance1 = WeatherConfig.shared
        let instance2 = WeatherConfig.shared
        // Static let is same reference
        XCTAssertEqual(instance1.apiEndpoint, instance2.apiEndpoint)
        XCTAssertEqual(instance1.refreshIntervalMinutes, instance2.refreshIntervalMinutes)
    }

    // MARK: - Direct Initialization (Injectable for Testing)

    func test_directInit_overridesAllDefaults() {
        let config = WeatherConfig(
            apiEndpoint: "https://custom.api.com",
            units: "metric",  // For testing only - production is imperial
            refreshIntervalMinutes: 15,
            cacheExpirationMinutes: 30,
            extremeColdThreshold: 40,
            extremeHeatThreshold: 100,
            pleasantTempMin: 65,
            pleasantTempMax: 75,
            rainyDaysLookbackWindow: 5,
            minRainyDaysForTransition: 3
        )

        XCTAssertEqual(config.apiEndpoint, "https://custom.api.com")
        XCTAssertEqual(config.units, "metric")
        XCTAssertEqual(config.refreshIntervalMinutes, 15)
        XCTAssertEqual(config.cacheExpirationMinutes, 30)
        XCTAssertEqual(config.extremeColdThreshold, 40, accuracy: 0.001)
        XCTAssertEqual(config.extremeHeatThreshold, 100, accuracy: 0.001)
        XCTAssertEqual(config.pleasantTempMin, 65, accuracy: 0.001)
        XCTAssertEqual(config.pleasantTempMax, 75, accuracy: 0.001)
        XCTAssertEqual(config.rainyDaysLookbackWindow, 5)
        XCTAssertEqual(config.minRainyDaysForTransition, 3)
    }

    func test_directInit_partialOverride_usesDefaultsForRest() {
        let config = WeatherConfig(
            refreshIntervalMinutes: 60
            // All others use defaults
        )

        XCTAssertEqual(config.refreshIntervalMinutes, 60)
        XCTAssertEqual(config.apiEndpoint, WeatherConfig.Defaults.apiEndpoint)
        XCTAssertEqual(config.units, WeatherConfig.Defaults.units)
        XCTAssertEqual(config.extremeColdThreshold, WeatherConfig.Defaults.extremeColdThreshold, accuracy: 0.001)
    }

    // MARK: - Defaults Enum Access

    func test_defaultsEnum_accessible() {
        // Verify Defaults enum is accessible for reference in implementation code
        XCTAssertEqual(WeatherConfig.Defaults.apiEndpoint, "https://api.openweathermap.org/data/2.5/weather")
        XCTAssertEqual(WeatherConfig.Defaults.units, "imperial")
        XCTAssertEqual(WeatherConfig.Defaults.refreshIntervalMinutes, 30)
        XCTAssertEqual(WeatherConfig.Defaults.cacheExpirationMinutes, 60)
        XCTAssertEqual(WeatherConfig.Defaults.extremeColdThreshold, 32, accuracy: 0.001)
        XCTAssertEqual(WeatherConfig.Defaults.extremeHeatThreshold, 95, accuracy: 0.001)
        XCTAssertEqual(WeatherConfig.Defaults.pleasantTempMin, 60, accuracy: 0.001)
        XCTAssertEqual(WeatherConfig.Defaults.pleasantTempMax, 80, accuracy: 0.001)
        XCTAssertEqual(WeatherConfig.Defaults.rainyDaysLookbackWindow, 3)
        XCTAssertEqual(WeatherConfig.Defaults.minRainyDaysForTransition, 2)
    }

    // MARK: - Refresh Interval Calculations

    func test_refreshIntervalSeconds_computed() {
        let config = WeatherConfig(refreshIntervalMinutes: 30)
        XCTAssertEqual(config.refreshIntervalSeconds, 30 * 60)
    }

    func test_cacheExpirationSeconds_computed() {
        let config = WeatherConfig(cacheExpirationMinutes: 60)
        XCTAssertEqual(config.cacheExpirationSeconds, 60 * 60)
    }
}
