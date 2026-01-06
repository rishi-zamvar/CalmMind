import Foundation
import CoreLocation
import Observation
import Combine

/// Weather display state management
/// If hidden, WeatherCard returns EmptyView
@Observable
@MainActor
final class WeatherViewModel {

    // MARK: - State

    enum State: Equatable {
        case hidden          // Privacy mode or no data - card not shown
        case needsPermission // Location not determined - show enable button
        case denied          // Location denied - show enable button with Settings redirect
        case loading
        case loaded(Weather, locationString: String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.hidden, .hidden): return true
            case (.needsPermission, .needsPermission): return true
            case (.denied, .denied): return true
            case (.loading, .loading): return true
            case (.loaded(let w1, let l1), .loaded(let w2, let l2)):
                return w1.temperature == w2.temperature &&
                       w1.condition == w2.condition &&
                       l1 == l2
            default: return false
            }
        }
    }

    private(set) var state: State = .hidden

    // MARK: - Dependencies

    private let locationService: LocationServiceProtocol
    private let weatherService: WeatherServiceProtocol
    private let userPreferences: UserPreferences
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        locationService: LocationServiceProtocol,
        weatherService: WeatherServiceProtocol,
        userPreferences: UserPreferences = .shared
    ) {
        self.locationService = locationService
        self.weatherService = weatherService
        self.userPreferences = userPreferences

        // Observe location authorization changes
        NotificationCenter.default
            .publisher(for: .locationAuthorizationDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadWeather()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load Weather

    func loadWeather() async {
        // Weather disabled in settings → hidden
        guard userPreferences.weatherEnabled else {
            state = .hidden
            return
        }

        // Privacy mode → hidden
        guard !userPreferences.privacyModeEnabled else {
            state = .hidden
            return
        }

        // Check permission state
        let permissionState = locationService.permissionState

        #if DEBUG
        print("🌤️ loadWeather - permissionState: \(permissionState), authStatus: \(locationService.authorizationStatus.rawValue)")
        #endif

        switch permissionState {
        case .privacyMode:
            state = .hidden
            return
        case .denied:
            // Show enable button with Settings redirect
            state = .denied
            return
        case .notDetermined:
            // Show enable button - don't request permission automatically
            state = .needsPermission
            return
        case .authorized:
            break  // Continue to load weather
        }

        state = .loading

        // Get location
        guard let coordinate = await locationService.getLocationThrottled() else {
            state = .hidden
            return
        }

        // Get weather
        let weather = await weatherService.fetchWeatherIfAllowed(for: coordinate)
            ?? weatherService.getCachedWeather()

        guard let weather = weather else {
            state = .hidden
            return
        }

        // Get location string
        let locationString = await locationService.getLocationString() ?? weather.locationName

        state = .loaded(weather, locationString: locationString)
    }

    // MARK: - Permission Request (user-initiated)

    /// Request location permission - ONLY call from explicit user action
    func requestLocationPermission() async {
        guard locationService.permissionState == .notDetermined else { return }

        _ = await locationService.requestPermissionIfNeeded()

        // Reload weather after permission granted
        await loadWeather()
    }

    // MARK: - Refresh (user-initiated)

    /// Force refresh weather - bypasses cache, user-initiated action
    func refreshWeather() async {
        // Privacy mode or weather disabled → hidden
        guard userPreferences.weatherEnabled, !userPreferences.privacyModeEnabled else {
            state = .hidden
            return
        }

        // Must be authorized to refresh
        guard locationService.permissionState == .authorized else {
            return
        }

        state = .loading

        // Get fresh location
        guard let coordinate = await locationService.getLocationThrottled() else {
            state = .hidden
            return
        }

        // Force fetch weather (bypass cache)
        do {
            let weather = try await weatherService.fetchWeather(for: coordinate)
            let locationString = await locationService.getLocationString() ?? weather.locationName
            state = .loaded(weather, locationString: locationString)
        } catch {
            // On error, try cached weather or hide
            if let cached = weatherService.getCachedWeather() {
                let locationString = await locationService.getLocationString() ?? cached.locationName
                state = .loaded(cached, locationString: locationString)
            } else {
                state = .hidden
            }
        }
    }
}
