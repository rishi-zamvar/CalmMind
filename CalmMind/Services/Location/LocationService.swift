import Foundation
import CoreLocation

/// Protocol for location service operations (for DI)
protocol LocationServiceProtocol: Sendable {
    /// Request authorization if not already requested
    func requestAuthorizationOnce() async

    /// Get current location with throttling (returns cached if fresh)
    func getLocationThrottled() async -> CLLocationCoordinate2D?

    /// Get formatted location string (e.g., "San Francisco, CA")
    func getLocationString() async -> String?

    /// Current authorization status
    var authorizationStatus: CLAuthorizationStatus { get }

    /// True if user has denied or restricted location access
    var isDenied: Bool { get }
}

/// Protocol for CLLocationManager injection (for testing)
protocol CLLocationManagerProtocol: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func requestLocation()
    func reverseGeocode(_ location: CLLocation) async -> CLPlacemark?
}

/// Location service errors
enum LocationError: Error, Equatable {
    case timeout
    case unknown
    // NOTE: No denied/restricted cases - those return nil instead
}

/// CoreLocation wrapper with throttling and caching
/// Returns nil for denied/restricted (does not throw)
final class LocationService: NSObject, LocationServiceProtocol, CLLocationManagerDelegate {

    // MARK: - Cache Keys

    enum CacheKeys {
        static let lastLocationLat = "location_cache_lat"
        static let lastLocationLon = "location_cache_lon"
        static let lastLocationAt = "location_cache_at"
        static let hasRequestedAuthorization = "location_auth_requested"
    }

    // MARK: - Properties

    private let locationManager: CLLocationManagerProtocol
    private let defaults: UserDefaults
    private let config: WeatherConfig

    private var locationContinuation: CheckedContinuation<CLLocation?, Error>?

    // MARK: - Initialization

    init(
        locationManager: CLLocationManagerProtocol? = nil,
        defaults: UserDefaults = .standard,
        config: WeatherConfig = .shared
    ) {
        self.defaults = defaults
        self.config = config

        if let manager = locationManager {
            self.locationManager = manager
        } else {
            let realManager = RealCLLocationManager()
            self.locationManager = realManager
        }

        super.init()

        self.locationManager.delegate = self
    }

    // MARK: - LocationServiceProtocol

    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    var isDenied: Bool {
        let status = authorizationStatus
        return status == .denied || status == .restricted
    }

    func requestAuthorizationOnce() async {
        // Don't prompt if already denied or already requested
        guard !isDenied else { return }
        guard !defaults.bool(forKey: CacheKeys.hasRequestedAuthorization) else { return }

        defaults.set(true, forKey: CacheKeys.hasRequestedAuthorization)
        locationManager.requestWhenInUseAuthorization()

        // Wait briefly for authorization response
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
    }

    func getLocationThrottled() async -> CLLocationCoordinate2D? {
        // Check if denied first
        guard !isDenied else { return nil }

        // Check cache
        if !shouldRefreshLocation() {
            if let cached = getCachedLocation() {
                return cached
            }
        }

        // Fetch fresh location
        do {
            let coordinate = try await getCurrentLocation()
            if let coord = coordinate {
                cacheLocation(coord)
            }
            return coordinate
        } catch {
            return getCachedLocation()  // Fall back to cache on error
        }
    }

    func getLocationString() async -> String? {
        guard !isDenied else { return nil }

        guard let coordinate = await getLocationThrottled() else { return nil }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        guard let placemark = await locationManager.reverseGeocode(location) else { return nil }

        let city = placemark.locality ?? ""
        let state = placemark.administrativeArea ?? ""

        if city.isEmpty && state.isEmpty {
            return nil
        } else if city.isEmpty {
            return state
        } else if state.isEmpty {
            return city
        } else {
            return "\(city), \(state)"
        }
    }

    // MARK: - Internal Location Fetch

    func getCurrentLocation() async throws -> CLLocationCoordinate2D? {
        // Return nil for denied (no throw)
        guard !isDenied else { return nil }

        let location: CLLocation? = try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            locationManager.requestLocation()

            // Timeout after 10 seconds
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if self.locationContinuation != nil {
                    self.locationContinuation?.resume(throwing: LocationError.timeout)
                    self.locationContinuation = nil
                }
            }
        }
        return location?.coordinate
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: LocationError.unknown)
        locationContinuation = nil
    }

    // MARK: - Cache Management

    private func shouldRefreshLocation() -> Bool {
        guard let lastAt = defaults.object(forKey: CacheKeys.lastLocationAt) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastAt) > config.refreshIntervalSeconds
    }

    private func getCachedLocation() -> CLLocationCoordinate2D? {
        guard defaults.object(forKey: CacheKeys.lastLocationLat) != nil else { return nil }
        let lat = defaults.double(forKey: CacheKeys.lastLocationLat)
        let lon = defaults.double(forKey: CacheKeys.lastLocationLon)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func cacheLocation(_ coordinate: CLLocationCoordinate2D) {
        defaults.set(coordinate.latitude, forKey: CacheKeys.lastLocationLat)
        defaults.set(coordinate.longitude, forKey: CacheKeys.lastLocationLon)
        defaults.set(Date(), forKey: CacheKeys.lastLocationAt)
    }
}

// MARK: - Real CLLocationManager Wrapper

private final class RealCLLocationManager: NSObject, CLLocationManagerProtocol, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    weak var delegate: CLLocationManagerDelegate? {
        get { manager.delegate }
        set { manager.delegate = newValue }
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.requestLocation()
    }

    func reverseGeocode(_ location: CLLocation) async -> CLPlacemark? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            return placemarks.first
        } catch {
            return nil
        }
    }
}
