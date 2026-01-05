import XCTest
import CoreLocation
import MapKit
@testable import CalmMind

/// Tests for LocationService - CoreLocation wrapper with throttling
/// TDD: These tests are written FIRST, implementation follows
final class LocationServiceTests: XCTestCase {

    var mockLocationManager: MockCLLocationManager!
    var mockDefaults: UserDefaults!
    var config: WeatherConfig!
    var locationService: LocationService!

    override func setUp() {
        super.setUp()
        mockLocationManager = MockCLLocationManager()
        mockDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        config = WeatherConfig()
        locationService = LocationService(
            locationManager: mockLocationManager,
            defaults: mockDefaults,
            config: config
        )
    }

    override func tearDown() {
        mockLocationManager = nil
        mockDefaults = nil
        config = nil
        locationService = nil
        super.tearDown()
    }

    // MARK: - Authorization

    func test_requestAuthorization_callsLocationManager() async {
        await locationService.requestAuthorizationOnce()

        XCTAssertTrue(mockLocationManager.requestWhenInUseAuthorizationCalled)
    }

    func test_requestAuthorization_onlyCalledOnce() async {
        // First call
        await locationService.requestAuthorizationOnce()
        mockLocationManager.requestWhenInUseAuthorizationCalled = false

        // Second call should not prompt again
        await locationService.requestAuthorizationOnce()

        XCTAssertFalse(mockLocationManager.requestWhenInUseAuthorizationCalled)
    }

    func test_authorizationStatus_reflectsManager() {
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse

        XCTAssertEqual(locationService.authorizationStatus, .authorizedWhenInUse)
    }

    func test_isDenied_trueWhenDenied() {
        mockLocationManager.mockAuthorizationStatus = .denied

        XCTAssertTrue(locationService.isDenied)
    }

    func test_isDenied_trueWhenRestricted() {
        mockLocationManager.mockAuthorizationStatus = .restricted

        XCTAssertTrue(locationService.isDenied)
    }

    func test_isDenied_falseWhenAuthorized() {
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse

        XCTAssertFalse(locationService.isDenied)
    }

    // MARK: - Get Current Location

    func test_getCurrentLocation_returnsCoordinate() async throws {
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        mockLocationManager.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)

        let coordinate = try await locationService.getCurrentLocation()

        XCTAssertNotNil(coordinate)
        XCTAssertEqual(coordinate?.latitude ?? 0, 37.7749, accuracy: 0.001)
        XCTAssertEqual(coordinate?.longitude ?? 0, -122.4194, accuracy: 0.001)
    }

    func test_getCurrentLocation_denied_returnsNil() async throws {
        // Denied should return nil, NOT throw
        mockLocationManager.mockAuthorizationStatus = .denied

        let coordinate = try await locationService.getCurrentLocation()

        XCTAssertNil(coordinate)
    }

    func test_getCurrentLocation_restricted_returnsNil() async throws {
        // Restricted should return nil, NOT throw
        mockLocationManager.mockAuthorizationStatus = .restricted

        let coordinate = try await locationService.getCurrentLocation()

        XCTAssertNil(coordinate)
    }

    func test_getCurrentLocation_timeout_throwsError() async {
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        mockLocationManager.shouldTimeout = true

        do {
            _ = try await locationService.getCurrentLocation()
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? LocationError, .timeout)
        }
    }

    // MARK: - Location String

    func test_locationString_formatsCorrectly() async {
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        mockLocationManager.mockLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockLocationManager.mockCity = "San Francisco"
        mockLocationManager.mockState = "CA"

        let locationString = await locationService.getLocationString()

        XCTAssertEqual(locationString, "San Francisco, CA")
    }

    func test_locationString_denied_returnsNil() async {
        mockLocationManager.mockAuthorizationStatus = .denied

        let locationString = await locationService.getLocationString()

        XCTAssertNil(locationString)
    }

    // MARK: - Throttling

    func test_getLocationThrottled_returnsCached_ifFresh() async throws {
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        mockLocationManager.mockLocation = CLLocation(latitude: 37.0, longitude: -122.0)

        // First call - should get location
        _ = try await locationService.getLocationThrottled()
        let firstCallCount = mockLocationManager.requestLocationCallCount

        // Second call within refresh interval - should use cache
        _ = try await locationService.getLocationThrottled()

        XCTAssertEqual(mockLocationManager.requestLocationCallCount, firstCallCount)
    }

    func test_getLocationThrottled_refreshes_ifStale() async throws {
        // Use a very short refresh interval for testing
        let shortConfig = WeatherConfig(refreshIntervalMinutes: 0)  // 0 = always refresh
        let service = LocationService(
            locationManager: mockLocationManager,
            defaults: mockDefaults,
            config: shortConfig
        )
        mockLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        mockLocationManager.mockLocation = CLLocation(latitude: 37.0, longitude: -122.0)

        // First call
        _ = try await service.getLocationThrottled()
        let firstCallCount = mockLocationManager.requestLocationCallCount

        // Second call - should refresh because interval is 0
        _ = try await service.getLocationThrottled()

        XCTAssertGreaterThan(mockLocationManager.requestLocationCallCount, firstCallCount)
    }

    func test_getLocationThrottled_denied_returnsNil() async {
        mockLocationManager.mockAuthorizationStatus = .denied

        let coordinate = await locationService.getLocationThrottled()

        XCTAssertNil(coordinate)
    }

    // MARK: - Never Re-Prompt If Denied

    func test_locationDenied_neverPromptsAgain() async {
        mockLocationManager.mockAuthorizationStatus = .denied

        // Even if we call requestAuthorizationOnce, it should not prompt
        await locationService.requestAuthorizationOnce()

        // CLLocationManager won't prompt again if already denied
        // The service should check status first
        XCTAssertFalse(mockLocationManager.requestWhenInUseAuthorizationCalled)
    }

    // MARK: - Cache Keys (Exact Keys Test)

    func test_cacheKeys_correct() {
        // Verify the exact keys used for UserDefaults caching
        XCTAssertEqual(LocationService.CacheKeys.lastLocationLat, "location_cache_lat")
        XCTAssertEqual(LocationService.CacheKeys.lastLocationLon, "location_cache_lon")
        XCTAssertEqual(LocationService.CacheKeys.lastLocationAt, "location_cache_at")
        XCTAssertEqual(LocationService.CacheKeys.hasRequestedAuthorization, "location_auth_requested")
    }
}

// MARK: - Mock CLLocationManager

final class MockCLLocationManager: CLLocationManagerProtocol {
    var delegate: CLLocationManagerDelegate?
    var mockAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var requestWhenInUseAuthorizationCalled = false
    var requestLocationCallCount = 0
    var mockLocation: CLLocation?
    var mockCity: String = ""
    var mockState: String = ""
    var shouldTimeout = false

    var authorizationStatus: CLAuthorizationStatus {
        mockAuthorizationStatus
    }

    func requestWhenInUseAuthorization() {
        requestWhenInUseAuthorizationCalled = true
    }

    func requestLocation() {
        requestLocationCallCount += 1
        if shouldTimeout {
            // Don't call delegate - simulates timeout
            return
        }
        if let location = mockLocation {
            delegate?.locationManager?(CLLocationManager(), didUpdateLocations: [location])
        }
    }

    func reverseGeocode(_ location: CLLocation) async -> CLPlacemark? {
        // Create a real CLPlacemark using MKPlacemark
        guard !mockCity.isEmpty || !mockState.isEmpty else { return nil }
        return MockPlacemarkWrapper(city: mockCity, state: mockState)
    }
}

// MARK: - Mock Placemark Wrapper

/// A wrapper that provides city/state without subclassing CLPlacemark
final class MockPlacemarkWrapper: CLPlacemark {
    private let _locality: String
    private let _administrativeArea: String

    init(city: String, state: String) {
        _locality = city
        _administrativeArea = state
        // Create a minimal CLPlacemark from MKPlacemark
        let coord = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let mkPlacemark = MKPlacemark(coordinate: coord)
        super.init(placemark: mkPlacemark)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override var locality: String? { _locality }
    override var administrativeArea: String? { _administrativeArea }
}
