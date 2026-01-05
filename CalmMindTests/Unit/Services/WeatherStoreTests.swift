import XCTest
@testable import CalmMind

/// Tests for WeatherStore - weather history and progression tracking
/// TDD: These tests are written FIRST, implementation follows
/// @MainActor: Required because WeatherStore is @MainActor isolated
@MainActor
final class WeatherStoreTests: XCTestCase {

    var mockDefaults: UserDefaults!
    var config: WeatherConfig!
    var store: WeatherStore!

    override func setUp() {
        super.setUp()
        mockDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        config = WeatherConfig()
        store = WeatherStore(defaults: mockDefaults, config: config)
    }

    override func tearDown() {
        mockDefaults = nil
        config = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Recording Weather

    func test_recordWeather_persistsToUserDefaults() {
        let weather = createWeather(temp: 72, condition: .clear, location: "San Francisco")

        store.record(weather)

        // Should be able to retrieve it
        let history = store.getHistory(for: Date())
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.temperature ?? 0, 72, accuracy: 0.001)
    }

    func test_recordWeather_appendsToExistingHistory() {
        let weather1 = createWeather(temp: 70, condition: .clouds, location: "SF")
        let weather2 = createWeather(temp: 75, condition: .clear, location: "SF")

        store.record(weather1)
        store.record(weather2)

        let history = store.getHistory(for: Date())
        XCTAssertEqual(history.count, 2)
    }

    // MARK: - Get History

    func test_getWeatherHistory_returnsOrderedByTime() {
        // Record in reverse order
        var w1 = createWeather(temp: 70, condition: .clouds, location: "SF")
        w1 = Weather(
            temperature: w1.temperature,
            condition: w1.condition,
            description: w1.description,
            humidity: w1.humidity,
            locationName: w1.locationName,
            timestamp: Date(timeIntervalSinceNow: -3600)  // 1 hour ago
        )

        var w2 = createWeather(temp: 75, condition: .clear, location: "SF")
        w2 = Weather(
            temperature: w2.temperature,
            condition: w2.condition,
            description: w2.description,
            humidity: w2.humidity,
            locationName: w2.locationName,
            timestamp: Date()  // Now
        )

        store.record(w1)
        store.record(w2)

        let history = store.getHistory(for: Date())

        // Should be ordered chronologically (oldest first)
        XCTAssertEqual(history.first?.temperature ?? 0, 70, accuracy: 0.001)
        XCTAssertEqual(history.last?.temperature ?? 0, 75, accuracy: 0.001)
    }

    func test_getWeatherForDate_returnsMatching() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        let todayWeather = createWeather(temp: 72, condition: .clear, location: "SF", timestamp: today)
        let yesterdayWeather = createWeather(temp: 65, condition: .rain, location: "SF", timestamp: yesterday)

        store.record(todayWeather)
        store.record(yesterdayWeather)

        let todayHistory = store.getHistory(for: today)
        let yesterdayHistory = store.getHistory(for: yesterday)

        XCTAssertEqual(todayHistory.count, 1)
        XCTAssertEqual(yesterdayHistory.count, 1)
        XCTAssertEqual(todayHistory.first?.condition, .clear)
        XCTAssertEqual(yesterdayHistory.first?.condition, .rain)
    }

    // MARK: - Weather Progression

    func test_weatherProgression_detectsTransition_rainToSunny() {
        let morning = createWeather(temp: 65, condition: .rain, location: "SF",
                                     timestamp: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!)
        let afternoon = createWeather(temp: 75, condition: .clear, location: "SF",
                                       timestamp: Date())

        store.record(morning)
        store.record(afternoon)

        let progression = store.getProgression(for: Date())

        XCTAssertTrue(progression.hadTransition)
        XCTAssertNotNil(progression.transitionDescription)
    }

    func test_weatherProgression_noTransition_stableWeather() {
        let morning = createWeather(temp: 70, condition: .clear, location: "SF",
                                     timestamp: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!)
        let afternoon = createWeather(temp: 75, condition: .clear, location: "SF",
                                       timestamp: Date())

        store.record(morning)
        store.record(afternoon)

        let progression = store.getProgression(for: Date())

        XCTAssertFalse(progression.hadTransition)
    }

    func test_weatherProgression_dominantCondition() {
        // Record more rain than sun
        store.record(createWeather(temp: 65, condition: .rain, location: "SF",
                                    timestamp: Calendar.current.date(byAdding: .hour, value: -6, to: Date())!))
        store.record(createWeather(temp: 66, condition: .rain, location: "SF",
                                    timestamp: Calendar.current.date(byAdding: .hour, value: -4, to: Date())!))
        store.record(createWeather(temp: 70, condition: .clear, location: "SF",
                                    timestamp: Date()))

        let progression = store.getProgression(for: Date())

        XCTAssertEqual(progression.dominantCondition, .rain)
    }

    // MARK: - Lookback Window (Config-Driven)

    func test_getRecentDays_usesConfigLookbackWindow() {
        let customConfig = WeatherConfig(rainyDaysLookbackWindow: 2)
        let customStore = WeatherStore(defaults: mockDefaults, config: customConfig)

        // Record weather for 3 days
        for daysAgo in 0..<3 {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
            customStore.record(createWeather(temp: 70, condition: .clear, location: "SF", timestamp: date))
        }

        let recent = customStore.getRecentDays()

        // Should only return 2 days (lookbackWindow = 2)
        XCTAssertEqual(recent.count, 2)
    }

    // MARK: - Cache Management

    func test_lastLocation_persistsCoordinate() {
        store.cacheLocation(latitude: 37.7749, longitude: -122.4194)

        let cached = store.getCachedLocation()

        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.latitude ?? 0, 37.7749, accuracy: 0.001)
        XCTAssertEqual(cached?.longitude ?? 0, -122.4194, accuracy: 0.001)
    }

    func test_lastWeather_persistsWeather() {
        let weather = createWeather(temp: 72, condition: .clear, location: "SF")

        store.cacheWeather(weather)

        let cached = store.getCachedWeather()

        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.temperature ?? 0, 72, accuracy: 0.001)
    }

    // MARK: - Refresh Logic (Config-Driven)

    func test_shouldRefreshLocation_falseIfFresh() {
        store.cacheLocation(latitude: 37.7749, longitude: -122.4194)

        XCTAssertFalse(store.shouldRefreshLocation())
    }

    func test_shouldRefreshLocation_trueIfStale() {
        // Use a very short refresh interval
        let shortConfig = WeatherConfig(refreshIntervalMinutes: 0)
        let shortStore = WeatherStore(defaults: mockDefaults, config: shortConfig)

        shortStore.cacheLocation(latitude: 37.7749, longitude: -122.4194)

        // With 0 minute refresh, should always be stale
        XCTAssertTrue(shortStore.shouldRefreshLocation())
    }

    func test_shouldRefreshLocation_trueIfNeverCached() {
        XCTAssertTrue(store.shouldRefreshLocation())
    }

    func test_shouldRefreshWeather_falseIfFresh() {
        let weather = createWeather(temp: 72, condition: .clear, location: "SF")
        store.cacheWeather(weather)

        XCTAssertFalse(store.shouldRefreshWeather())
    }

    func test_shouldRefreshWeather_trueIfStale() {
        let shortConfig = WeatherConfig(refreshIntervalMinutes: 0)
        let shortStore = WeatherStore(defaults: mockDefaults, config: shortConfig)

        shortStore.cacheWeather(createWeather(temp: 72, condition: .clear, location: "SF"))

        XCTAssertTrue(shortStore.shouldRefreshWeather())
    }

    // MARK: - Helpers

    private func createWeather(temp: Double, condition: WeatherCondition, location: String, timestamp: Date = Date()) -> Weather {
        Weather(
            temperature: temp,
            condition: condition,
            description: condition.displayName,
            humidity: 50,
            locationName: location,
            timestamp: timestamp
        )
    }
}
