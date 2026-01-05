import XCTest
import CoreLocation
@testable import CalmMind

/// Tests for WeatherService - OpenWeather API client with caching
/// TDD: These tests are written FIRST, implementation follows
final class WeatherServiceTests: XCTestCase {

    var mockURLSession: MockWeatherURLSession!
    var mockDefaults: UserDefaults!
    var mockUserPreferences: UserPreferences!
    var config: WeatherConfig!
    var weatherService: WeatherService!

    override func setUp() {
        super.setUp()
        mockURLSession = MockWeatherURLSession()
        mockDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        mockUserPreferences = UserPreferences(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        mockUserPreferences.privacyModeEnabled = false
        config = WeatherConfig()
        weatherService = WeatherService(
            urlSession: mockURLSession,
            defaults: mockDefaults,
            userPreferences: mockUserPreferences,
            config: config,
            apiKey: "test-api-key"
        )
    }

    override func tearDown() {
        mockURLSession = nil
        mockDefaults = nil
        mockUserPreferences = nil
        config = nil
        weatherService = nil
        super.tearDown()
    }

    // MARK: - Fetch Weather

    func test_fetchWeather_decodesResponse() async throws {
        let jsonResponse = """
        {
            "main": {"temp": 72.5, "humidity": 65},
            "weather": [{"main": "Clear", "description": "clear sky"}],
            "name": "San Francisco"
        }
        """.data(using: .utf8)!
        mockURLSession.mockData = jsonResponse
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.openweathermap.org")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let weather = try await weatherService.fetchWeather(for: coordinate)

        XCTAssertEqual(weather.temperature, 72.5, accuracy: 0.001)
        XCTAssertEqual(weather.condition, .clear)
        XCTAssertEqual(weather.locationName, "San Francisco")
    }

    func test_fetchWeather_cachesResult() async throws {
        let jsonResponse = """
        {
            "main": {"temp": 72.5, "humidity": 65},
            "weather": [{"main": "Clear", "description": "clear sky"}],
            "name": "San Francisco"
        }
        """.data(using: .utf8)!
        mockURLSession.mockData = jsonResponse
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.openweathermap.org")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        _ = try await weatherService.fetchWeather(for: coordinate)

        // Weather should be cached
        let cached = weatherService.getCachedWeather()
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.temperature ?? 0, 72.5, accuracy: 0.001)
    }

    func test_fetchWeather_returnsCached_ifFresh() async throws {
        // First call to populate cache
        let jsonResponse = """
        {
            "main": {"temp": 72.5, "humidity": 65},
            "weather": [{"main": "Clear", "description": "clear sky"}],
            "name": "San Francisco"
        }
        """.data(using: .utf8)!
        mockURLSession.mockData = jsonResponse
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.openweathermap.org")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        _ = try await weatherService.fetchWeather(for: coordinate)
        let firstCallCount = mockURLSession.dataCallCount

        // Second call should use cache
        _ = try await weatherService.fetchWeather(for: coordinate)

        XCTAssertEqual(mockURLSession.dataCallCount, firstCallCount)
    }

    func test_fetchWeather_refreshes_ifStale() async throws {
        // Use a very short cache expiration for testing
        let shortConfig = WeatherConfig(cacheExpirationMinutes: 0)  // 0 = always refresh
        let service = WeatherService(
            urlSession: mockURLSession,
            defaults: mockDefaults,
            userPreferences: mockUserPreferences,
            config: shortConfig,
            apiKey: "test-api-key"
        )

        let jsonResponse = """
        {
            "main": {"temp": 72.5, "humidity": 65},
            "weather": [{"main": "Clear", "description": "clear sky"}],
            "name": "San Francisco"
        }
        """.data(using: .utf8)!
        mockURLSession.mockData = jsonResponse
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.openweathermap.org")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        _ = try await service.fetchWeather(for: coordinate)
        let firstCallCount = mockURLSession.dataCallCount

        // Second call should refresh because cache expired immediately
        _ = try await service.fetchWeather(for: coordinate)

        XCTAssertGreaterThan(mockURLSession.dataCallCount, firstCallCount)
    }

    func test_fetchWeather_networkError_throws() async {
        mockURLSession.mockError = NSError(domain: "test", code: -1, userInfo: nil)

        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        do {
            // Force refresh by clearing cache
            mockDefaults.removeObject(forKey: WeatherService.CacheKeys.lastWeather)
            mockDefaults.removeObject(forKey: WeatherService.CacheKeys.lastWeatherAt)

            _ = try await weatherService.fetchWeather(for: coordinate)
            XCTFail("Expected network error")
        } catch let error as WeatherError {
            // Check it's a network error (message may vary by platform)
            if case .networkError(let message) = error {
                XCTAssertTrue(message.contains("test error -1"))
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        } catch {
            XCTFail("Expected WeatherError, got \(error)")
        }
    }

    // MARK: - Privacy Mode

    func test_fetchWeatherIfAllowed_privacyMode_returnsNil() async {
        // Enable privacy mode - should return nil, NOT throw
        mockUserPreferences.privacyModeEnabled = true

        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let weather = await weatherService.fetchWeatherIfAllowed(for: coordinate)

        XCTAssertNil(weather)
    }

    func test_fetchWeatherIfAllowed_normalMode_returnsWeather() async {
        mockUserPreferences.privacyModeEnabled = false

        let jsonResponse = """
        {
            "main": {"temp": 72.5, "humidity": 65},
            "weather": [{"main": "Clear", "description": "clear sky"}],
            "name": "San Francisco"
        }
        """.data(using: .utf8)!
        mockURLSession.mockData = jsonResponse
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.openweathermap.org")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let weather = await weatherService.fetchWeatherIfAllowed(for: coordinate)

        XCTAssertNotNil(weather)
    }

    // MARK: - API Key Validation

    func test_fetchWeather_invalidAPIKey_throws() async {
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.openweathermap.org")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        mockURLSession.mockData = Data()

        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        do {
            // Force refresh
            mockDefaults.removeObject(forKey: WeatherService.CacheKeys.lastWeather)
            mockDefaults.removeObject(forKey: WeatherService.CacheKeys.lastWeatherAt)

            _ = try await weatherService.fetchWeather(for: coordinate)
            XCTFail("Expected invalid API key error")
        } catch {
            XCTAssertEqual(error as? WeatherError, .invalidAPIKey)
        }
    }

    // MARK: - Cache Keys

    func test_cacheKeys_correct() {
        XCTAssertEqual(WeatherService.CacheKeys.lastWeather, "weather_cache_data")
        XCTAssertEqual(WeatherService.CacheKeys.lastWeatherAt, "weather_cache_at")
    }

    // MARK: - URL Building

    func test_fetchWeather_usesConfigURL() async throws {
        let jsonResponse = """
        {
            "main": {"temp": 72.5, "humidity": 65},
            "weather": [{"main": "Clear", "description": "clear sky"}],
            "name": "Test"
        }
        """.data(using: .utf8)!
        mockURLSession.mockData = jsonResponse
        mockURLSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.openweathermap.org")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        _ = try await weatherService.fetchWeather(for: coordinate)

        // Verify URL was built correctly with units param
        let requestURL = mockURLSession.lastRequestURL?.absoluteString ?? ""
        XCTAssertTrue(requestURL.contains("units=imperial"))
        XCTAssertTrue(requestURL.contains("lat=37.7749"))
        XCTAssertTrue(requestURL.contains("lon=-122.4194"))
        XCTAssertTrue(requestURL.contains("appid=test-api-key"))
    }
}

// MARK: - Mock URL Session

final class MockWeatherURLSession: WeatherURLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var dataCallCount = 0
    var lastRequestURL: URL?

    func data(from url: URL) async throws -> (Data, URLResponse) {
        dataCallCount += 1
        lastRequestURL = url

        if let error = mockError {
            throw error
        }

        guard let data = mockData, let response = mockResponse else {
            throw NSError(domain: "test", code: -1, userInfo: nil)
        }

        return (data, response)
    }
}
