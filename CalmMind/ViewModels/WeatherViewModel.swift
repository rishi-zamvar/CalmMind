import Foundation
import CoreLocation
import Observation

/// Weather display state management
/// If hidden, WeatherCard returns EmptyView
@Observable
@MainActor
final class WeatherViewModel {

    // MARK: - State

    enum State: Equatable {
        case hidden        // Privacy mode, denied, or no data - card not shown
        case loading
        case loaded(Weather, locationString: String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.hidden, .hidden): return true
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

    // MARK: - Initialization

    init(
        locationService: LocationServiceProtocol,
        weatherService: WeatherServiceProtocol,
        userPreferences: UserPreferences = .shared
    ) {
        self.locationService = locationService
        self.weatherService = weatherService
        self.userPreferences = userPreferences
    }

    // MARK: - Load Weather

    func loadWeather() async {
        // Privacy mode → hidden
        guard !userPreferences.privacyModeEnabled else {
            state = .hidden
            return
        }

        // Location denied → hidden
        guard !locationService.isDenied else {
            state = .hidden
            return
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
}
