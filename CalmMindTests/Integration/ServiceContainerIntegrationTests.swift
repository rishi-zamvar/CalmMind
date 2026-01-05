import XCTest
import SwiftData
import CoreLocation
@testable import CalmMind

/// Integration tests for ServiceContainer and its invariants
/// Tests verify the key architectural constraints from the Weather & Semantic Search integration
@MainActor
final class ServiceContainerIntegrationTests: XCTestCase {

    var container: ModelContainer!
    var userPreferences: UserPreferences!

    override func setUp() {
        super.setUp()

        container = try! ModelContainer(
            for: ChatMessage.self, DailySession.self, TodoItem.self, JournalEntry.self,
                 MemoryItem.self, Topic.self, Fact.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        userPreferences = UserPreferences(defaults: UserDefaults(suiteName: "test.\(UUID())")!)
    }

    override func tearDown() {
        userPreferences = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Single Source of Truth Tests

    func test_serviceContainer_sameWeatherStore_acrossAllConsumers() {
        let services = ServiceContainer(
            modelContainer: container,
            weatherAPIKey: "test-key",
            userPreferences: userPreferences
        )

        // WeatherStore should be the exact same instance
        let store1 = services.weatherStore
        let store2 = services.weatherStore

        XCTAssertTrue(store1 === store2, "WeatherStore must be same instance")
    }

    func test_serviceContainer_sameLocationService_acrossAllConsumers() {
        let services = ServiceContainer(
            modelContainer: container,
            weatherAPIKey: "test-key",
            userPreferences: userPreferences
        )

        // LocationService should be the exact same instance
        let loc1 = services.locationService
        let loc2 = services.locationService

        XCTAssertTrue(loc1 === loc2, "LocationService must be same instance")
    }

    func test_serviceContainer_sameModelContainer() {
        let services = ServiceContainer(
            modelContainer: container,
            weatherAPIKey: "test-key",
            userPreferences: userPreferences
        )

        XCTAssertTrue(services.modelContainer === container, "ModelContainer must be same instance")
    }

    // MARK: - Weather API Status Tests

    func test_weatherAPIStatus_available_whenKeyPresent() {
        let services = ServiceContainer(
            modelContainer: container,
            weatherAPIKey: "test-api-key",
            userPreferences: userPreferences
        )

        XCTAssertEqual(services.weatherAPIStatus, ServiceContainer.WeatherAPIStatus.available)
    }

    func test_weatherAPIStatus_missingKey_whenNil() {
        let services = ServiceContainer(
            modelContainer: container,
            weatherAPIKey: nil,
            userPreferences: userPreferences
        )

        XCTAssertEqual(services.weatherAPIStatus, ServiceContainer.WeatherAPIStatus.missingKey)
    }

    func test_weatherAPIStatus_privacyMode_blocksEvenWithKey() {
        userPreferences.privacyModeEnabled = true

        let services = ServiceContainer(
            modelContainer: container,
            weatherAPIKey: "test-api-key",
            userPreferences: userPreferences
        )

        XCTAssertEqual(services.weatherAPIStatus, ServiceContainer.WeatherAPIStatus.privacyMode)
    }

    // MARK: - Location Permission Tests

    func test_locationService_permissionState_privacyMode_blocksAccess() {
        userPreferences.privacyModeEnabled = true

        let services = ServiceContainer(
            modelContainer: container,
            weatherAPIKey: "test-key",
            userPreferences: userPreferences
        )

        XCTAssertEqual(services.locationService.permissionState, LocationPermissionState.privacyMode)
    }

    // MARK: - Timezone Handling Tests

    func test_startOfDay_usesContainerCalendar() {
        let testCalendar = Calendar(identifier: .gregorian)
        let services = ServiceContainer(
            modelContainer: container,
            weatherAPIKey: "test-key",
            userPreferences: userPreferences,
            calendar: testCalendar
        )

        let now = Date()
        let startOfDay = services.startOfDay(for: now)

        // Should use the container's calendar
        let expected = testCalendar.startOfDay(for: now)
        XCTAssertEqual(startOfDay, expected)
    }

    func test_yesterdayStart_isBeforeToday() {
        let services = ServiceContainer(
            modelContainer: container,
            weatherAPIKey: "test-key",
            userPreferences: userPreferences
        )

        let yesterday = services.yesterdayStart()
        let todayStart = services.startOfDay(for: Date())

        XCTAssertTrue(yesterday < todayStart)
    }

    // MARK: - Weather Service Optional Key Tests

    func test_weatherService_nilAPIKey_throwsMissingAPIKey() async throws {
        let services = ServiceContainer(
            modelContainer: container,
            weatherAPIKey: nil,
            userPreferences: userPreferences
        )

        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        do {
            _ = try await services.weatherService.fetchWeather(for: coordinate)
            XCTFail("Expected missingAPIKey error")
        } catch WeatherError.missingAPIKey {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_weatherService_emptyAPIKey_treatedAsNil() async {
        let services = ServiceContainer(
            modelContainer: container,
            weatherAPIKey: "",  // Empty string should be treated as nil
            userPreferences: userPreferences
        )

        XCTAssertEqual(services.weatherAPIStatus, ServiceContainer.WeatherAPIStatus.missingKey)
    }

    // MARK: - Privacy Mode End-to-End Tests

    func test_privacyMode_blocksWeatherContextInOrchestrator() {
        userPreferences.privacyModeEnabled = true

        let services = ServiceContainer(
            modelContainer: container,
            weatherAPIKey: "test-key",
            userPreferences: userPreferences
        )

        // When privacy mode is on, weatherAPIStatus should be .privacyMode
        XCTAssertEqual(services.weatherAPIStatus, ServiceContainer.WeatherAPIStatus.privacyMode)
    }

    func test_privacyMode_blocksSemanticContext() throws {
        userPreferences.privacyModeEnabled = true

        let topicRepo = TopicRepository(context: container.mainContext)

        // Create topics with embeddings
        for i in 1...10 {
            let topic = try topicRepo.create(name: "Person \(i)", type: .person)
            try topicRepo.updateEmbedding(for: topic, embedding: [0.1, 0.2, 0.3])
        }

        let gate = SemanticSearchGate(
            topicRepository: topicRepo,
            userPreferences: userPreferences
        )

        // Even with 10 topics (above threshold), privacy mode should block
        XCTAssertFalse(gate.shouldEnableContext())
    }

    func test_privacyMode_blocksLocationAccess() async {
        userPreferences.privacyModeEnabled = true

        let services = ServiceContainer(
            modelContainer: container,
            weatherAPIKey: "test-key",
            userPreferences: userPreferences
        )

        // Location should return nil when privacy mode is on
        let location = await services.locationService.getLocationThrottled()
        XCTAssertNil(location)
    }
}
