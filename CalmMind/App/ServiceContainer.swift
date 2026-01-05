import Foundation
import CoreLocation
import SwiftData

/// Single source of truth for shared services
/// Invariant: ONE instance created at app startup, passed everywhere
/// Owns: modelContainer, all services
///
/// This container ensures:
/// - Same WeatherStore instance used by HomeView, AIOrchestrator, and JournalSynthesizer
/// - Same ModelContainer for all repositories
/// - Consistent calendar for timezone-aware day boundaries
///
/// @MainActor: This container is designed for UI-thread access.
/// WeatherStore requires @MainActor isolation, so we inherit that requirement.
@MainActor
@Observable
final class ServiceContainer: ObservableObject {

    // MARK: - Data Layer (unified)

    /// The single ModelContainer for all data access
    let modelContainer: ModelContainer

    // MARK: - Services (non-optional, always available)

    /// Weather history and cache - access from @MainActor context
    let weatherStore: WeatherStore

    /// Location service with user-initiated permission
    let locationService: LocationService

    /// Weather API client (may be disabled if API key missing)
    let weatherService: WeatherService

    /// Embedding service for semantic search
    let embeddingService: EmbeddingService

    /// User preferences (privacy mode, notifications, etc.)
    let userPreferences: UserPreferences

    // MARK: - Status (explicit states, not silent failures)

    /// Weather API availability status
    enum WeatherAPIStatus {
        /// API key present and service available
        case available
        /// No API key configured
        case missingKey
        /// Privacy mode blocks weather
        case privacyMode
        /// User has disabled weather in settings
        case disabled
    }

    /// Current weather API status
    var weatherAPIStatus: WeatherAPIStatus {
        if !userPreferences.weatherEnabled { return .disabled }
        if userPreferences.privacyModeEnabled { return .privacyMode }
        if weatherService.apiKey == nil { return .missingKey }
        return .available
    }

    // MARK: - Calendar (timezone-aware, DST-safe)

    /// Calendar for date calculations - respects user's timezone
    let calendar: Calendar

    // MARK: - Initialization

    /// Create the service container with all dependencies
    /// - Parameters:
    ///   - modelContainer: The SwiftData ModelContainer for persistence
    ///   - weatherAPIKey: OpenWeatherMap API key (nil = service disabled)
    ///   - userPreferences: User preferences instance
    ///   - calendar: Calendar for date calculations
    init(
        modelContainer: ModelContainer,
        weatherAPIKey: String? = KeychainSecretsStore.shared.getWeatherAPIKey(),
        userPreferences: UserPreferences = .shared,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.modelContainer = modelContainer
        self.userPreferences = userPreferences
        self.calendar = calendar

        // Create services ONCE
        self.weatherStore = WeatherStore()
        self.locationService = LocationService(userPreferences: userPreferences)
        self.embeddingService = EmbeddingService()

        // WeatherService accepts optional key - explicit unavailable state
        // Note: Uses WEATHER API key (OpenWeatherMap), not OpenAI key
        self.weatherService = WeatherService(
            userPreferences: userPreferences,
            apiKey: weatherAPIKey
        )
    }

    // MARK: - Day Boundary (timezone-aware, uses owned calendar)

    /// Get the start of day for a given date using the container's calendar
    /// - Parameter date: The date to get start of day for
    /// - Returns: Start of day in user's timezone
    func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Get yesterday's start of day in user's timezone
    /// - Returns: Start of yesterday
    func yesterdayStart() -> Date {
        let today = startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -1, to: today)!
    }

    /// Get the start of a specific day ago
    /// - Parameter daysAgo: Number of days ago (1 = yesterday)
    /// - Returns: Start of that day
    func startOfDay(daysAgo: Int) -> Date {
        let today = startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -daysAgo, to: today)!
    }
}
