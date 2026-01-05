import XCTest
@testable import CalmMind

/// Tests for Weather model - config-driven temperature classifications
/// TDD: These tests are written FIRST, implementation follows
final class WeatherTests: XCTestCase {

    // MARK: - Decoding from OpenWeather API JSON

    func test_weather_decodesFromOpenWeatherJSON() throws {
        // Real OpenWeather API response format
        let json = """
        {
            "main": {
                "temp": 58.5,
                "humidity": 72
            },
            "weather": [
                {
                    "main": "Clear",
                    "description": "clear sky"
                }
            ],
            "name": "San Francisco"
        }
        """.data(using: .utf8)!

        let weather = try JSONDecoder().decode(OpenWeatherResponse.self, from: json).toWeather()

        XCTAssertEqual(weather.temperature, 58.5, accuracy: 0.001)
        XCTAssertEqual(weather.humidity, 72)
        XCTAssertEqual(weather.condition, .clear)
        XCTAssertEqual(weather.description, "clear sky")
        XCTAssertEqual(weather.locationName, "San Francisco")
    }

    func test_weather_decodesFromOpenWeatherJSON_imperial() throws {
        // Verify temperature is Fahrenheit (no conversion needed with units=imperial)
        let json = """
        {
            "main": {
                "temp": 95.0,
                "humidity": 30
            },
            "weather": [
                {
                    "main": "Clear",
                    "description": "hot"
                }
            ],
            "name": "Phoenix"
        }
        """.data(using: .utf8)!

        let weather = try JSONDecoder().decode(OpenWeatherResponse.self, from: json).toWeather()

        // 95°F should be exactly 95 - no Kelvin conversion
        XCTAssertEqual(weather.temperature, 95.0, accuracy: 0.001)
    }

    // MARK: - Weather Condition Mapping

    func test_weatherCondition_mapsCorrectly() {
        XCTAssertEqual(WeatherCondition(apiMain: "Clear"), .clear)
        XCTAssertEqual(WeatherCondition(apiMain: "Clouds"), .clouds)
        XCTAssertEqual(WeatherCondition(apiMain: "Rain"), .rain)
        XCTAssertEqual(WeatherCondition(apiMain: "Drizzle"), .drizzle)
        XCTAssertEqual(WeatherCondition(apiMain: "Thunderstorm"), .thunderstorm)
        XCTAssertEqual(WeatherCondition(apiMain: "Snow"), .snow)
        XCTAssertEqual(WeatherCondition(apiMain: "Mist"), .mist)
        XCTAssertEqual(WeatherCondition(apiMain: "Fog"), .fog)
    }

    func test_weatherCondition_unknownDefaultsToClouds() {
        // Unknown conditions default to clouds (safest neutral)
        XCTAssertEqual(WeatherCondition(apiMain: "Haze"), .mist)  // Maps to mist
        XCTAssertEqual(WeatherCondition(apiMain: "Unknown"), .clouds)  // Falls back
    }

    func test_weatherCondition_caseInsensitive() {
        XCTAssertEqual(WeatherCondition(apiMain: "CLEAR"), .clear)
        XCTAssertEqual(WeatherCondition(apiMain: "rain"), .rain)
        XCTAssertEqual(WeatherCondition(apiMain: "ThUnDeRsToRm"), .thunderstorm)
    }

    // MARK: - Temperature Classifications (Config-Driven)

    func test_weather_temperatureInFahrenheit() {
        let weather = Weather(
            temperature: 72.0,
            condition: .clear,
            description: "clear sky",
            humidity: 50,
            locationName: "Test City",
            timestamp: Date()
        )

        // Temperature should be stored as-is (Fahrenheit)
        XCTAssertEqual(weather.temperature, 72.0, accuracy: 0.001)
    }

    // MARK: - Extreme Weather Detection (Config-Driven)

    func test_isExtreme_conditionBased_rain() {
        let weather = Weather(
            temperature: 70.0,  // Pleasant temp
            condition: .rain,   // But rainy!
            description: "rain",
            humidity: 90,
            locationName: "Seattle",
            timestamp: Date()
        )

        XCTAssertTrue(weather.isExtreme())
    }

    func test_isExtreme_conditionBased_thunderstorm() {
        let weather = Weather(
            temperature: 75.0,
            condition: .thunderstorm,
            description: "thunderstorm",
            humidity: 80,
            locationName: "Test",
            timestamp: Date()
        )

        XCTAssertTrue(weather.isExtreme())
    }

    func test_isExtreme_conditionBased_snow() {
        let weather = Weather(
            temperature: 30.0,
            condition: .snow,
            description: "snow",
            humidity: 80,
            locationName: "Test",
            timestamp: Date()
        )

        XCTAssertTrue(weather.isExtreme())
    }

    func test_isExtreme_temperatureBased_extremeCold() {
        let config = WeatherConfig(extremeColdThreshold: 32)
        let weather = Weather(
            temperature: 28.0,  // Below 32°F
            condition: .clear,
            description: "cold",
            humidity: 40,
            locationName: "Test",
            timestamp: Date()
        )

        XCTAssertTrue(weather.isExtreme(config: config))
    }

    func test_isExtreme_temperatureBased_extremeHeat() {
        let config = WeatherConfig(extremeHeatThreshold: 95)
        let weather = Weather(
            temperature: 100.0,  // Above 95°F
            condition: .clear,
            description: "hot",
            humidity: 20,
            locationName: "Test",
            timestamp: Date()
        )

        XCTAssertTrue(weather.isExtreme(config: config))
    }

    func test_isExtreme_normalWeather_false() {
        let config = WeatherConfig()  // Default thresholds
        let weather = Weather(
            temperature: 72.0,  // Normal temp
            condition: .clear,  // Clear sky
            description: "pleasant",
            humidity: 50,
            locationName: "Test",
            timestamp: Date()
        )

        XCTAssertFalse(weather.isExtreme(config: config))
    }

    func test_isExtreme_usesConfigThresholds() {
        // Custom config with different thresholds
        let config = WeatherConfig(
            extremeColdThreshold: 50,  // Higher threshold
            extremeHeatThreshold: 80   // Lower threshold
        )
        let weather = Weather(
            temperature: 45.0,  // Normal by default, but cold by custom config
            condition: .clear,
            description: "chilly",
            humidity: 50,
            locationName: "Test",
            timestamp: Date()
        )

        XCTAssertTrue(weather.isExtreme(config: config))  // 45 < 50 (custom cold)
    }

    // MARK: - Pleasant Weather Detection (Config-Driven)

    func test_isPleasant_clearAndInRange() {
        let config = WeatherConfig(pleasantTempMin: 60, pleasantTempMax: 80)
        let weather = Weather(
            temperature: 72.0,  // Within 60-80
            condition: .clear,   // Clear sky
            description: "sunny",
            humidity: 50,
            locationName: "Test",
            timestamp: Date()
        )

        XCTAssertTrue(weather.isPleasant(config: config))
    }

    func test_isPleasant_cloudyWeather_false() {
        let config = WeatherConfig()
        let weather = Weather(
            temperature: 72.0,  // Good temp
            condition: .clouds, // But cloudy
            description: "cloudy",
            humidity: 50,
            locationName: "Test",
            timestamp: Date()
        )

        XCTAssertFalse(weather.isPleasant(config: config))
    }

    func test_isPleasant_outOfTempRange_false() {
        let config = WeatherConfig(pleasantTempMin: 60, pleasantTempMax: 80)
        let weather = Weather(
            temperature: 55.0,  // Below min
            condition: .clear,
            description: "cool",
            humidity: 50,
            locationName: "Test",
            timestamp: Date()
        )

        XCTAssertFalse(weather.isPleasant(config: config))
    }

    func test_isPleasant_usesConfigThresholds() {
        let config = WeatherConfig(pleasantTempMin: 70, pleasantTempMax: 75)
        let weather = Weather(
            temperature: 65.0,  // Would be pleasant by default, but not custom
            condition: .clear,
            description: "nice",
            humidity: 50,
            locationName: "Test",
            timestamp: Date()
        )

        XCTAssertFalse(weather.isPleasant(config: config))
    }

    // MARK: - Display Formatting

    func test_displayString_format() {
        let weather = Weather(
            temperature: 58.0,
            condition: .clear,
            description: "sunny",
            humidity: 50,
            locationName: "San Francisco",
            timestamp: Date()
        )

        // Format: "58°F, Sunny"
        XCTAssertEqual(weather.displayString, "58°F, Sunny")
    }

    func test_compactLine_format() {
        let weather = Weather(
            temperature: 58.0,
            condition: .rain,
            description: "light rain",
            humidity: 80,
            locationName: "San Francisco",
            timestamp: Date()
        )

        // Format: "San Francisco · 58°F 🌧️"
        XCTAssertEqual(weather.compactLine, "San Francisco · 58°F 🌧️")
    }

    // MARK: - Condition Properties

    func test_weatherCondition_isExtreme() {
        XCTAssertTrue(WeatherCondition.rain.isExtreme)
        XCTAssertTrue(WeatherCondition.thunderstorm.isExtreme)
        XCTAssertTrue(WeatherCondition.snow.isExtreme)

        XCTAssertFalse(WeatherCondition.clear.isExtreme)
        XCTAssertFalse(WeatherCondition.clouds.isExtreme)
        XCTAssertFalse(WeatherCondition.drizzle.isExtreme)
        XCTAssertFalse(WeatherCondition.mist.isExtreme)
        XCTAssertFalse(WeatherCondition.fog.isExtreme)
    }

    func test_weatherCondition_isPleasant() {
        XCTAssertTrue(WeatherCondition.clear.isPleasant)

        XCTAssertFalse(WeatherCondition.clouds.isPleasant)
        XCTAssertFalse(WeatherCondition.rain.isPleasant)
        XCTAssertFalse(WeatherCondition.drizzle.isPleasant)
        XCTAssertFalse(WeatherCondition.thunderstorm.isPleasant)
        XCTAssertFalse(WeatherCondition.snow.isPleasant)
        XCTAssertFalse(WeatherCondition.mist.isPleasant)
        XCTAssertFalse(WeatherCondition.fog.isPleasant)
    }

    func test_weatherCondition_displayName() {
        XCTAssertEqual(WeatherCondition.clear.displayName, "Sunny")
        XCTAssertEqual(WeatherCondition.clouds.displayName, "Cloudy")
        XCTAssertEqual(WeatherCondition.rain.displayName, "Rainy")
        XCTAssertEqual(WeatherCondition.drizzle.displayName, "Drizzle")
        XCTAssertEqual(WeatherCondition.thunderstorm.displayName, "Stormy")
        XCTAssertEqual(WeatherCondition.snow.displayName, "Snowy")
        XCTAssertEqual(WeatherCondition.mist.displayName, "Misty")
        XCTAssertEqual(WeatherCondition.fog.displayName, "Foggy")
    }

    func test_weatherCondition_emoji() {
        XCTAssertEqual(WeatherCondition.clear.emoji, "☀️")
        XCTAssertEqual(WeatherCondition.clouds.emoji, "☁️")
        XCTAssertEqual(WeatherCondition.rain.emoji, "🌧️")
        XCTAssertEqual(WeatherCondition.drizzle.emoji, "🌦️")
        XCTAssertEqual(WeatherCondition.thunderstorm.emoji, "⛈️")
        XCTAssertEqual(WeatherCondition.snow.emoji, "❄️")
        XCTAssertEqual(WeatherCondition.mist.emoji, "🌫️")
        XCTAssertEqual(WeatherCondition.fog.emoji, "🌫️")
    }

    // MARK: - Sendable Conformance

    func test_weather_isSendable() {
        // Compile-time check - this test passes if it compiles
        let weather = Weather(
            temperature: 72.0,
            condition: .clear,
            description: "test",
            humidity: 50,
            locationName: "Test",
            timestamp: Date()
        )

        Task {
            let _ = weather  // Can be used across actor boundaries
        }

        XCTAssertTrue(true)  // Compiles = passes
    }

    // MARK: - Equatable Conformance

    func test_weather_isEquatable() {
        let timestamp = Date()
        let weather1 = Weather(
            temperature: 72.0,
            condition: .clear,
            description: "sunny",
            humidity: 50,
            locationName: "Test",
            timestamp: timestamp
        )
        let weather2 = Weather(
            temperature: 72.0,
            condition: .clear,
            description: "sunny",
            humidity: 50,
            locationName: "Test",
            timestamp: timestamp
        )

        XCTAssertEqual(weather1, weather2)
    }

    // MARK: - Temperature Boundary Tests (Partition Table)
    // Config thresholds: extremeCold=32, mildCold=45, mildHeat=85, extremeHeat=95
    //
    // Partition table:
    // | Range       | Category      | isExtreme | isMildlyUncomfortable |
    // |-------------|---------------|-----------|------------------------|
    // | temp <= 32  | Extreme cold  | true      | false                  |
    // | 32 < temp < 45 | Mild cold  | false     | true                   |
    // | 45 <= temp < 85 | Comfortable | false   | false                  |
    // | 85 <= temp < 95 | Mild hot   | false     | true                   |
    // | temp >= 95  | Extreme hot   | true      | false                  |

    func test_isExtreme_32F_returnsTrue() {
        let config = WeatherConfig()
        let weather = makeWeather(temperature: 32.0)

        XCTAssertTrue(weather.isExtreme(config: config), "32°F should be extreme cold")
    }

    func test_isMildlyUncomfortable_32F_returnsFalse() {
        let config = WeatherConfig()
        let weather = makeWeather(temperature: 32.0)

        XCTAssertFalse(weather.isMildlyUncomfortable(config: config), "32°F is extreme, not mild")
    }

    func test_isExtreme_33F_returnsFalse() {
        let config = WeatherConfig()
        let weather = makeWeather(temperature: 33.0)

        XCTAssertFalse(weather.isExtreme(config: config), "33°F is above extreme cold threshold")
    }

    func test_isMildlyUncomfortable_33F_returnsTrue() {
        let config = WeatherConfig()
        let weather = makeWeather(temperature: 33.0)

        XCTAssertTrue(weather.isMildlyUncomfortable(config: config), "33°F should be mildly cold")
    }

    func test_isMildlyUncomfortable_44F_returnsTrue() {
        let config = WeatherConfig()
        let weather = makeWeather(temperature: 44.0)

        XCTAssertTrue(weather.isMildlyUncomfortable(config: config), "44°F should be mildly cold")
    }

    func test_isMildlyUncomfortable_45F_returnsFalse() {
        let config = WeatherConfig()
        let weather = makeWeather(temperature: 45.0)

        XCTAssertFalse(weather.isMildlyUncomfortable(config: config), "45°F is comfortable")
    }

    func test_isMildlyUncomfortable_70F_returnsFalse() {
        let config = WeatherConfig()
        let weather = makeWeather(temperature: 70.0)

        XCTAssertFalse(weather.isMildlyUncomfortable(config: config), "70°F is comfortable")
    }

    func test_isMildlyUncomfortable_84F_returnsFalse() {
        let config = WeatherConfig()
        let weather = makeWeather(temperature: 84.0)

        XCTAssertFalse(weather.isMildlyUncomfortable(config: config), "84°F is still comfortable")
    }

    func test_isMildlyUncomfortable_85F_returnsTrue() {
        let config = WeatherConfig()
        let weather = makeWeather(temperature: 85.0)

        XCTAssertTrue(weather.isMildlyUncomfortable(config: config), "85°F should be mildly hot")
    }

    func test_isMildlyUncomfortable_94F_returnsTrue() {
        let config = WeatherConfig()
        let weather = makeWeather(temperature: 94.0)

        XCTAssertTrue(weather.isMildlyUncomfortable(config: config), "94°F should be mildly hot")
    }

    func test_isExtreme_95F_returnsTrue() {
        let config = WeatherConfig()
        let weather = makeWeather(temperature: 95.0)

        XCTAssertTrue(weather.isExtreme(config: config), "95°F should be extreme heat")
    }

    func test_isMildlyUncomfortable_95F_returnsFalse() {
        let config = WeatherConfig()
        let weather = makeWeather(temperature: 95.0)

        XCTAssertFalse(weather.isMildlyUncomfortable(config: config), "95°F is extreme, not mild")
    }

    func test_extremeAndMild_noOverlap() {
        // Verify partition table: no temperature can be BOTH extreme AND mildly uncomfortable
        let config = WeatherConfig()

        for temp in stride(from: 0.0, through: 120.0, by: 1.0) {
            let weather = makeWeather(temperature: temp)
            let isExtreme = weather.isExtreme(config: config)
            let isMild = weather.isMildlyUncomfortable(config: config)

            XCTAssertFalse(isExtreme && isMild,
                "\(temp)°F cannot be both extreme AND mildly uncomfortable")
        }
    }

    func test_formattedTemperature_accessibilityLabel() {
        let weather = makeWeather(temperature: 72.0)

        XCTAssertEqual(weather.formattedTemperature, "72 degrees Fahrenheit")
    }

    // MARK: - Helpers

    private func makeWeather(
        temperature: Double,
        condition: WeatherCondition = .clear
    ) -> Weather {
        Weather(
            temperature: temperature,
            condition: condition,
            description: "test",
            humidity: 50,
            locationName: "Test",
            timestamp: Date()
        )
    }

    // MARK: - Codable Conformance

    func test_weather_roundTrips() throws {
        let original = Weather(
            temperature: 72.5,
            condition: .rain,
            description: "light rain",
            humidity: 85,
            locationName: "Seattle",
            timestamp: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Weather.self, from: data)

        XCTAssertEqual(decoded.temperature, original.temperature, accuracy: 0.001)
        XCTAssertEqual(decoded.condition, original.condition)
        XCTAssertEqual(decoded.description, original.description)
        XCTAssertEqual(decoded.humidity, original.humidity)
        XCTAssertEqual(decoded.locationName, original.locationName)
    }
}
