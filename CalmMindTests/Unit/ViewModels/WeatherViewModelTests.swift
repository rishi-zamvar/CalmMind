import XCTest
import CoreLocation
@testable import CalmMind

/// Tests for WeatherViewModel - weather display state management
/// TDD: These tests are written FIRST, implementation follows
@MainActor
final class WeatherViewModelTests: XCTestCase {

    var mockLocationService: MockViewModelLocationService!
    var mockWeatherService: MockViewModelWeatherService!
    var mockUserPreferences: UserPreferences!
    var viewModel: WeatherViewModel!

    override func setUp() {
        super.setUp()
        mockLocationService = MockViewModelLocationService()
        mockWeatherService = MockViewModelWeatherService()
        mockUserPreferences = UserPreferences(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        mockUserPreferences.privacyModeEnabled = false

        viewModel = WeatherViewModel(
            locationService: mockLocationService,
            weatherService: mockWeatherService,
            userPreferences: mockUserPreferences
        )
    }

    override func tearDown() {
        mockLocationService = nil
        mockWeatherService = nil
        mockUserPreferences = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Load Weather

    func test_loadWeather_fetchesLocationThenWeather() async {
        mockLocationService.mockCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        mockLocationService.mockLocationString = "San Francisco, CA"
        mockWeatherService.mockWeather = createWeather(temp: 72, condition: .clear, location: "San Francisco")

        await viewModel.loadWeather()

        XCTAssertTrue(mockLocationService.getLocationThrottledCalled)
        XCTAssertTrue(mockWeatherService.fetchWeatherIfAllowedCalled)
    }

    func test_loadWeather_updatesState() async {
        mockLocationService.mockCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        mockLocationService.mockLocationString = "San Francisco, CA"
        mockWeatherService.mockWeather = createWeather(temp: 72, condition: .clear, location: "San Francisco")

        await viewModel.loadWeather()

        if case .loaded(let weather, let locationString) = viewModel.state {
            XCTAssertEqual(weather.temperature, 72, accuracy: 0.001)
            XCTAssertEqual(locationString, "San Francisco, CA")
        } else {
            XCTFail("Expected loaded state")
        }
    }

    // MARK: - Hidden States

    func test_loadWeather_locationDenied_showsDenied() async {
        mockLocationService.mockIsDenied = true

        await viewModel.loadWeather()

        // Denied shows .denied state (Settings redirect available)
        XCTAssertEqual(viewModel.state, .denied)
    }

    func test_loadWeather_privacyMode_showsHidden() async {
        mockUserPreferences.privacyModeEnabled = true
        mockLocationService.mockCoordinate = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)

        await viewModel.loadWeather()

        XCTAssertEqual(viewModel.state, .hidden)
    }

    func test_loadWeather_noLocation_showsHidden() async {
        mockLocationService.mockCoordinate = nil

        await viewModel.loadWeather()

        XCTAssertEqual(viewModel.state, .hidden)
    }

    func test_loadWeather_noWeather_showsHidden() async {
        mockLocationService.mockCoordinate = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        mockWeatherService.mockWeather = nil

        await viewModel.loadWeather()

        XCTAssertEqual(viewModel.state, .hidden)
    }

    // MARK: - Fallback to Cached

    func test_loadWeather_networkError_showsCached() async {
        mockLocationService.mockCoordinate = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        mockLocationService.mockLocationString = "San Francisco, CA"
        mockWeatherService.mockWeather = nil
        mockWeatherService.mockCachedWeather = createWeather(temp: 70, condition: .clouds, location: "SF")

        await viewModel.loadWeather()

        if case .loaded(let weather, _) = viewModel.state {
            XCTAssertEqual(weather.temperature, 70, accuracy: 0.001)
        } else {
            XCTFail("Expected loaded state with cached weather")
        }
    }

    // MARK: - Location String

    func test_locationString_formatsCorrectly() async {
        mockLocationService.mockCoordinate = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        mockLocationService.mockLocationString = "San Francisco, CA"
        mockWeatherService.mockWeather = createWeather(temp: 72, condition: .clear, location: "SF")

        await viewModel.loadWeather()

        if case .loaded(_, let locationString) = viewModel.state {
            XCTAssertEqual(locationString, "San Francisco, CA")
        } else {
            XCTFail("Expected loaded state")
        }
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

// MARK: - Mock Location Service

final class MockViewModelLocationService: LocationServiceProtocol, @unchecked Sendable {
    var mockCoordinate: CLLocationCoordinate2D?
    var mockLocationString: String?
    var mockIsDenied = false
    var getLocationThrottledCalled = false
    var requestPermissionIfNeededCalled = false

    var authorizationStatus: CLAuthorizationStatus { mockIsDenied ? .denied : .authorizedWhenInUse }
    var isDenied: Bool { mockIsDenied }

    var permissionState: LocationPermissionState {
        mockIsDenied ? .denied : .authorized
    }

    func requestAuthorizationOnce() async {}

    func requestPermissionIfNeeded() async -> Bool {
        requestPermissionIfNeededCalled = true
        return true
    }

    func getLocationThrottled() async -> CLLocationCoordinate2D? {
        getLocationThrottledCalled = true
        return mockCoordinate
    }

    func getLocationString() async -> String? {
        return mockLocationString
    }
}

// MARK: - Mock Weather Service

final class MockViewModelWeatherService: WeatherServiceProtocol, @unchecked Sendable {
    var mockWeather: Weather?
    var mockCachedWeather: Weather?
    var fetchWeatherIfAllowedCalled = false

    func fetchWeather(for coordinate: CLLocationCoordinate2D) async throws -> Weather {
        if let weather = mockWeather {
            return weather
        }
        throw WeatherError.networkError("Mock error")
    }

    func getCachedWeather() -> Weather? {
        return mockCachedWeather ?? mockWeather
    }

    func fetchWeatherIfAllowed(for coordinate: CLLocationCoordinate2D) async -> Weather? {
        fetchWeatherIfAllowedCalled = true
        return mockWeather
    }
}
