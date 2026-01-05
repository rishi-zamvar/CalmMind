import Foundation
import CoreLocation

/// Protocol for weather service operations (for DI)
protocol WeatherServiceProtocol: Sendable {
    /// Fetch weather for coordinate (may use cache if fresh)
    func fetchWeather(for coordinate: CLLocationCoordinate2D) async throws -> Weather

    /// Get cached weather if available
    func getCachedWeather() -> Weather?

    /// Fetch weather if privacy mode allows (returns nil if privacy mode on)
    func fetchWeatherIfAllowed(for coordinate: CLLocationCoordinate2D) async -> Weather?
}

/// Protocol for weather URL session injection (for testing)
/// Separate from OpenAI's URLSessionProtocol to use simpler URL-based API
protocol WeatherURLSessionProtocol: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

/// Make URLSession conform to weather protocol
extension URLSession: WeatherURLSessionProtocol {}

/// Weather service errors
enum WeatherError: Error, Equatable {
    case networkError(String)
    case invalidAPIKey
    case missingAPIKey  // Explicit: API key not configured
    case locationUnavailable
    // NOTE: No privacyModeEnabled - privacy returns nil instead
}

/// OpenWeather API client with caching
/// Returns nil for privacy mode (does not throw)
final class WeatherService: WeatherServiceProtocol, @unchecked Sendable {

    // MARK: - Cache Keys

    enum CacheKeys {
        static let lastWeather = "weather_cache_data"
        static let lastWeatherAt = "weather_cache_at"
    }

    // MARK: - Properties

    private let urlSession: WeatherURLSessionProtocol
    private let defaults: UserDefaults
    private let userPreferences: UserPreferences
    private let config: WeatherConfig
    private let _apiKey: String?

    /// Whether this service has a valid API key configured
    /// Used by ServiceContainer to determine weatherAPIStatus
    var apiKey: String? { _apiKey }

    // MARK: - Initialization

    init(
        urlSession: WeatherURLSessionProtocol = URLSession.shared,
        defaults: UserDefaults = .standard,
        userPreferences: UserPreferences = .shared,
        config: WeatherConfig = .shared,
        apiKey: String?  // nil = service disabled, not ""
    ) {
        self.urlSession = urlSession
        self.defaults = defaults
        self.userPreferences = userPreferences
        self.config = config
        // Treat empty string as nil (explicit unavailable state)
        self._apiKey = apiKey?.isEmpty == true ? nil : apiKey
    }

    // MARK: - WeatherServiceProtocol

    func fetchWeather(for coordinate: CLLocationCoordinate2D) async throws -> Weather {
        // Explicit check for missing API key - fail fast
        guard let key = _apiKey else {
            throw WeatherError.missingAPIKey
        }

        // Check cache first
        if !shouldRefreshWeather() {
            if let cached = getCachedWeather() {
                return cached
            }
        }

        // Fetch fresh weather
        let url = config.buildURL(lat: coordinate.latitude, lon: coordinate.longitude, apiKey: key)

        do {
            let (data, response) = try await urlSession.data(from: url)

            // Check for API errors
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    break  // Success
                case 401:
                    throw WeatherError.invalidAPIKey
                default:
                    throw WeatherError.networkError("HTTP \(httpResponse.statusCode)")
                }
            }

            // Decode response
            let apiResponse = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
            let weather = apiResponse.toWeather()

            // Cache the result
            cacheWeather(weather)

            return weather
        } catch let error as WeatherError {
            throw error
        } catch {
            throw WeatherError.networkError(error.localizedDescription)
        }
    }

    func getCachedWeather() -> Weather? {
        guard let data = defaults.data(forKey: CacheKeys.lastWeather) else { return nil }
        return try? JSONDecoder().decode(Weather.self, from: data)
    }

    func fetchWeatherIfAllowed(for coordinate: CLLocationCoordinate2D) async -> Weather? {
        // Privacy mode returns nil, NOT throws
        guard !userPreferences.privacyModeEnabled else { return nil }

        do {
            return try await fetchWeather(for: coordinate)
        } catch {
            return getCachedWeather()  // Fall back to cache on error
        }
    }

    // MARK: - Cache Management

    private func shouldRefreshWeather() -> Bool {
        guard let lastAt = defaults.object(forKey: CacheKeys.lastWeatherAt) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastAt) > config.cacheExpirationSeconds
    }

    private func cacheWeather(_ weather: Weather) {
        guard let data = try? JSONEncoder().encode(weather) else { return }
        defaults.set(data, forKey: CacheKeys.lastWeather)
        defaults.set(Date(), forKey: CacheKeys.lastWeatherAt)
    }
}
