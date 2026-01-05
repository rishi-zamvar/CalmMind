import XCTest
@testable import CalmMind

/// Tests for WeatherContextProvider - discretionary AI weather mentions
/// TDD: These tests are written FIRST, implementation follows
final class WeatherContextProviderTests: XCTestCase {

    var config: WeatherConfig!

    override func setUp() {
        super.setUp()
        config = WeatherConfig()
    }

    override func tearDown() {
        config = nil
        super.tearDown()
    }

    // MARK: - Should Mention Weather

    func test_shouldMentionWeather_extreme_returnsTrue() {
        let extreme = createWeather(temp: 100, condition: .thunderstorm, location: "Test")

        let shouldMention = WeatherContextProvider.shouldMentionWeather(
            current: extreme,
            progression: nil,
            recentHistory: nil,
            config: config
        )

        XCTAssertTrue(shouldMention)
    }

    func test_shouldMentionWeather_extremeCold_returnsTrue() {
        let cold = createWeather(temp: 25, condition: .clear, location: "Test")

        let shouldMention = WeatherContextProvider.shouldMentionWeather(
            current: cold,
            progression: nil,
            recentHistory: nil,
            config: config
        )

        XCTAssertTrue(shouldMention)
    }

    func test_shouldMentionWeather_extremeHeat_returnsTrue() {
        let hot = createWeather(temp: 100, condition: .clear, location: "Test")

        let shouldMention = WeatherContextProvider.shouldMentionWeather(
            current: hot,
            progression: nil,
            recentHistory: nil,
            config: config
        )

        XCTAssertTrue(shouldMention)
    }

    func test_shouldMentionWeather_rain_returnsTrue() {
        let rain = createWeather(temp: 65, condition: .rain, location: "Test")

        let shouldMention = WeatherContextProvider.shouldMentionWeather(
            current: rain,
            progression: nil,
            recentHistory: nil,
            config: config
        )

        XCTAssertTrue(shouldMention)
    }

    func test_shouldMentionWeather_transition_returnsTrue() {
        let current = createWeather(temp: 72, condition: .clear, location: "Test")
        let progression = WeatherProgression(
            snapshots: [],
            dominantCondition: .rain,
            hadTransition: true,
            transitionDescription: "Rainy to clear"
        )

        let shouldMention = WeatherContextProvider.shouldMentionWeather(
            current: current,
            progression: progression,
            recentHistory: nil,
            config: config
        )

        XCTAssertTrue(shouldMention)
    }

    func test_shouldMentionWeather_normal_returnsFalse() {
        let normal = createWeather(temp: 72, condition: .clear, location: "Test")

        let shouldMention = WeatherContextProvider.shouldMentionWeather(
            current: normal,
            progression: nil,
            recentHistory: nil,
            config: config
        )

        XCTAssertFalse(shouldMention)
    }

    func test_shouldMentionWeather_pleasant_normalDay_returnsFalse() {
        // CONSERVATIVE: Pleasant weather on a normal day should NOT trigger mention
        let pleasant = createWeather(temp: 72, condition: .clear, location: "Test")

        let shouldMention = WeatherContextProvider.shouldMentionWeather(
            current: pleasant,
            progression: nil,
            recentHistory: nil,
            config: config
        )

        XCTAssertFalse(shouldMention)
    }

    func test_shouldMentionWeather_pleasant_afterRainyDays_returnsTrue() {
        // First clear day after multiple rainy days IS notable
        let clearToday = createWeather(temp: 72, condition: .clear, location: "Test")
        let recentRainy = [
            createWeather(temp: 60, condition: .rain, location: "Test"),
            createWeather(temp: 62, condition: .rain, location: "Test")
        ]

        let shouldMention = WeatherContextProvider.shouldMentionWeather(
            current: clearToday,
            progression: nil,
            recentHistory: recentRainy,
            config: config
        )

        XCTAssertTrue(shouldMention)
    }

    func test_shouldMentionWeather_cloudy_returnsFalse() {
        let cloudy = createWeather(temp: 68, condition: .clouds, location: "Test")

        let shouldMention = WeatherContextProvider.shouldMentionWeather(
            current: cloudy,
            progression: nil,
            recentHistory: nil,
            config: config
        )

        XCTAssertFalse(shouldMention)
    }

    func test_shouldMentionWeather_noWeather_returnsFalse() {
        let shouldMention = WeatherContextProvider.shouldMentionWeather(
            current: nil,
            progression: nil,
            recentHistory: nil,
            config: config
        )

        XCTAssertFalse(shouldMention)
    }

    // MARK: - Build Context

    func test_buildContext_naturalLanguage() {
        let weather = createWeather(temp: 100, condition: .thunderstorm, location: "Phoenix")
        let progression = WeatherProgression(
            snapshots: [],
            dominantCondition: .thunderstorm,
            hadTransition: false,
            transitionDescription: nil
        )

        let context = WeatherContextProvider.buildContext(
            current: weather,
            progression: progression,
            location: "Phoenix, AZ",
            recentHistory: nil,
            config: config
        )

        XCTAssertNotNil(context)
        XCTAssertTrue(context?.contains("100°F") ?? false)
        XCTAssertTrue(context?.contains("Phoenix") ?? false)
    }

    func test_buildContext_includesDiscretionInstruction() {
        let weather = createWeather(temp: 28, condition: .snow, location: "Test")

        let context = WeatherContextProvider.buildContext(
            current: weather,
            progression: nil,
            location: "Test",
            recentHistory: nil,
            config: config
        )

        // Context should include instruction to be discretionary
        XCTAssertTrue(context?.contains("directly relevant") ?? false)
    }

    func test_buildContext_normalWeather_returnsNil() {
        let normal = createWeather(temp: 72, condition: .clear, location: "Test")

        let context = WeatherContextProvider.buildContext(
            current: normal,
            progression: nil,
            location: "Test",
            recentHistory: nil,
            config: config
        )

        XCTAssertNil(context)
    }

    // MARK: - Config-Driven Thresholds

    func test_shouldMentionWeather_usesConfigThresholds() {
        // Custom config with different thresholds
        let customConfig = WeatherConfig(
            extremeColdThreshold: 50,  // Higher than default
            minRainyDaysForTransition: 5  // Higher than default
        )

        // 45°F is extreme with custom config but not with default
        let weather = createWeather(temp: 45, condition: .clear, location: "Test")

        let shouldMentionCustom = WeatherContextProvider.shouldMentionWeather(
            current: weather,
            progression: nil,
            recentHistory: nil,
            config: customConfig
        )

        let shouldMentionDefault = WeatherContextProvider.shouldMentionWeather(
            current: weather,
            progression: nil,
            recentHistory: nil,
            config: config
        )

        XCTAssertTrue(shouldMentionCustom)
        XCTAssertFalse(shouldMentionDefault)
    }

    // MARK: - Helpers

    private func createWeather(temp: Double, condition: WeatherCondition, location: String) -> Weather {
        Weather(
            temperature: temp,
            condition: condition,
            description: condition.displayName,
            humidity: 50,
            locationName: location,
            timestamp: Date()
        )
    }
}
