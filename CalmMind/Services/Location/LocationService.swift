import Foundation
import CoreLocation

/// Permission state for location access
/// Includes privacy mode as a distinct state
enum LocationPermissionState: Sendable {
    /// User has not been prompted yet
    case notDetermined
    /// User granted access (whenInUse or always)
    case authorized
    /// User denied or system restricted
    case denied
    /// Privacy mode is enabled (blocks location regardless of OS permission)
    case privacyMode
}

/// Protocol for location service operations (for DI)
protocol LocationServiceProtocol: Sendable {
    /// Request authorization if not already requested
    /// - Returns: true if permission was newly requested, false if already decided
    func requestPermissionIfNeeded() async -> Bool

    /// Get current location with throttling (returns cached if fresh)
    func getLocationThrottled() async -> CLLocationCoordinate2D?

    /// Get formatted location string (e.g., "San Francisco, CA")
    func getLocationString() async -> String?

    /// Current authorization status
    var authorizationStatus: CLAuthorizationStatus { get }

    /// True if user has denied or restricted location access
    var isDenied: Bool { get }

    /// Current permission state (includes privacy mode)
    var permissionState: LocationPermissionState { get }
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
/// Returns nil for denied/restricted/privacy mode (does not throw)
///
/// INVARIANT: Never prompts for permission on init or background.
/// Permission request ONLY via explicit user action (requestPermissionIfNeeded).
final class LocationService: NSObject, LocationServiceProtocol, CLLocationManagerDelegate {

    // MARK: - Cache Keys

    enum CacheKeys {
        static let lastLocationLat = "location_cache_lat"
        static let lastLocationLon = "location_cache_lon"
        static let lastLocationAt = "location_cache_at"
    }

    // MARK: - Properties

    private let locationManager: CLLocationManagerProtocol
    private let defaults: UserDefaults
    private let config: WeatherConfig
    private let userPreferences: UserPreferences

    private var locationContinuation: CheckedContinuation<CLLocation?, Error>?

    // MARK: - Initialization

    init(
        locationManager: CLLocationManagerProtocol? = nil,
        defaults: UserDefaults = .standard,
        config: WeatherConfig = .shared,
        userPreferences: UserPreferences = .shared
    ) {
        self.defaults = defaults
        self.config = config
        self.userPreferences = userPreferences

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

    var permissionState: LocationPermissionState {
        // Privacy mode takes precedence over OS permission
        if userPreferences.privacyModeEnabled { return .privacyMode }

        switch authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .authorizedWhenInUse, .authorizedAlways:
            return .authorized
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .notDetermined
        }
    }

    func requestPermissionIfNeeded() async -> Bool {
        // Privacy mode blocks permission request
        guard permissionState == .notDetermined else { return false }

        // Request authorization - always request if status is notDetermined
        // The OS will only show the prompt once, but we need to call this to trigger it
        locationManager.requestWhenInUseAuthorization()

        // Wait for authorization response (the OS prompt takes time)
        // Poll for up to 5 seconds for the status to change
        for _ in 0..<50 {
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
            if authorizationStatus != .notDetermined {
                break
            }
        }
        return true
    }

    // Keep old method for backwards compatibility (deprecated)
    @available(*, deprecated, renamed: "requestPermissionIfNeeded")
    func requestAuthorizationOnce() async {
        _ = await requestPermissionIfNeeded()
    }

    func getLocationThrottled() async -> CLLocationCoordinate2D? {
        // Privacy mode and denied both block location access
        guard permissionState == .authorized else { return nil }

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
        guard permissionState == .authorized else { return nil }

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
        // Return nil for denied/privacy mode (no throw)
        guard permissionState == .authorized else { return nil }

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

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Post notification when authorization changes so WeatherViewModel can reload
        NotificationCenter.default.post(name: .locationAuthorizationDidChange, object: nil)
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

        #if DEBUG
        print("📍 LocationManager init - status: \(manager.authorizationStatus.rawValue)")
        #endif
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
