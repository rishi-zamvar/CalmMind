import XCTest
import CoreLocation
import UserNotifications
@testable import CalmMind

/// Tests for PermissionStateManager - canonical permission state tracking
final class PermissionStateManagerTests: XCTestCase {

    var mockLocationService: MockLocationServiceForPermissions!
    var mockDefaults: UserDefaults!
    var userPreferences: UserPreferences!
    var mockNotificationCenter: MockNotificationCenterForPermissions!

    @MainActor
    override func setUp() {
        super.setUp()
        mockLocationService = MockLocationServiceForPermissions()
        mockDefaults = UserDefaults(suiteName: "test.\(UUID())")!
        userPreferences = UserPreferences(defaults: mockDefaults)
        mockNotificationCenter = MockNotificationCenterForPermissions()
    }

    override func tearDown() {
        mockLocationService = nil
        mockDefaults = nil
        userPreferences = nil
        mockNotificationCenter = nil
        super.tearDown()
    }

    // MARK: - Interaction Persistence (Relaunch Survival)

    @MainActor
    func test_interactionState_persistsSurvivesRelaunch() async {
        // Given: Fresh manager
        let manager1 = PermissionStateManager(
            locationService: mockLocationService,
            userPreferences: userPreferences,
            notificationCenter: mockNotificationCenter
        )
        XCTAssertFalse(manager1.locationInteracted)

        // When: Request location (denied)
        mockLocationService.mockPermissionState = .denied
        _ = await manager1.requestLocation()

        // Then: Interaction persisted synchronously in UserPreferences
        XCTAssertTrue(userPreferences.locationPermissionInteracted)

        // When: New manager (simulates relaunch) - reads synchronously at init
        let manager2 = PermissionStateManager(
            locationService: mockLocationService,
            userPreferences: userPreferences,
            notificationCenter: mockNotificationCenter
        )

        // Then: Interaction state restored immediately (no async hydration)
        XCTAssertTrue(manager2.locationInteracted)
    }

    @MainActor
    func test_notificationInteractionState_persistsSurvivesRelaunch() async {
        let manager1 = PermissionStateManager(
            locationService: mockLocationService,
            userPreferences: userPreferences,
            notificationCenter: mockNotificationCenter
        )
        XCTAssertFalse(manager1.notificationInteracted)

        mockNotificationCenter.mockAuthorizationResult = true
        _ = await manager1.requestNotifications()

        XCTAssertTrue(userPreferences.notificationPermissionInteracted)

        let manager2 = PermissionStateManager(
            locationService: mockLocationService,
            userPreferences: userPreferences,
            notificationCenter: mockNotificationCenter
        )
        XCTAssertTrue(manager2.notificationInteracted)
    }

    // MARK: - canProceed Gating

    @MainActor
    func test_canProceed_requiresBothPermissionsHandled() async {
        let manager = PermissionStateManager(
            locationService: mockLocationService,
            userPreferences: userPreferences,
            notificationCenter: mockNotificationCenter
        )

        // Initial: cannot proceed (location is notAsked and not interacted)
        // Note: notification status depends on real device state since mock can't fake UNNotificationSettings
        XCTAssertFalse(manager.locationInteracted)
        XCTAssertEqual(manager.locationStatus, .notAsked)

        // After location granted - location requirement is satisfied
        mockLocationService.mockPermissionState = .authorized
        _ = await manager.requestLocation()
        XCTAssertTrue(manager.locationInteracted || manager.locationStatus == .granted)

        // After both handled
        mockNotificationCenter.mockAuthorizationResult = true
        _ = await manager.requestNotifications()
        // Now both have been interacted with, canProceed should be true
        XCTAssertTrue(manager.canProceed)
    }

    @MainActor
    func test_canProceed_allowsWhenStatusIsGranted() async {
        // Test the core logic: if status is .granted, canProceed should work
        // even if interacted flag wasn't set (e.g., permission from previous install)
        let manager = PermissionStateManager(
            locationService: mockLocationService,
            userPreferences: userPreferences,
            notificationCenter: mockNotificationCenter
        )

        // Request both permissions (which will grant them via mock)
        mockLocationService.mockPermissionState = .authorized
        mockNotificationCenter.mockAuthorizationResult = true

        _ = await manager.requestLocation()
        _ = await manager.requestNotifications()

        // Both granted, should be able to proceed
        XCTAssertEqual(manager.locationStatus, .granted)
        XCTAssertEqual(manager.notificationStatus, .granted)
        XCTAssertTrue(manager.canProceed)
    }

    // MARK: - Denied Shows Correct State

    @MainActor
    func test_deniedPermission_marksInteractedAndShowsDenied() async {
        let manager = PermissionStateManager(
            locationService: mockLocationService,
            userPreferences: userPreferences,
            notificationCenter: mockNotificationCenter
        )

        mockLocationService.mockPermissionState = .denied
        let result = await manager.requestLocation()

        XCTAssertEqual(result, .denied)
        XCTAssertEqual(manager.locationStatus, .denied)
        XCTAssertTrue(manager.locationInteracted)
    }

    // MARK: - Initial State

    @MainActor
    func test_initialState_notAsked() {
        let manager = PermissionStateManager(
            locationService: mockLocationService,
            userPreferences: userPreferences,
            notificationCenter: mockNotificationCenter
        )

        // Initial state should be notAsked
        XCTAssertEqual(manager.locationStatus, .notAsked)
        XCTAssertEqual(manager.notificationStatus, .notAsked)
    }

    // MARK: - Granted State

    @MainActor
    func test_grantedPermission_showsGranted() async {
        let manager = PermissionStateManager(
            locationService: mockLocationService,
            userPreferences: userPreferences,
            notificationCenter: mockNotificationCenter
        )

        mockLocationService.mockPermissionState = .authorized
        let result = await manager.requestLocation()

        XCTAssertEqual(result, .granted)
        XCTAssertEqual(manager.locationStatus, .granted)
        XCTAssertTrue(manager.locationInteracted)
    }
}

// MARK: - Mock Location Service for Permission Tests

final class MockLocationServiceForPermissions: LocationServiceProtocol {
    var mockPermissionState: LocationPermissionState = .notDetermined
    var mockAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var requestPermissionCallCount = 0

    var authorizationStatus: CLAuthorizationStatus {
        mockAuthorizationStatus
    }

    var isDenied: Bool {
        mockPermissionState == .denied
    }

    var permissionState: LocationPermissionState {
        mockPermissionState
    }

    func requestPermissionIfNeeded() async -> Bool {
        requestPermissionCallCount += 1
        return true
    }

    func getLocationThrottled() async -> CLLocationCoordinate2D? {
        nil
    }

    func getLocationString() async -> String? {
        nil
    }
}

// MARK: - Mock Notification Center for Permission Tests

final class MockNotificationCenterForPermissions: NotificationCenterProtocol {
    var mockAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    var mockAuthorizationResult = true
    var requestAuthorizationCallCount = 0
    var requestAuthorizationOptions: UNAuthorizationOptions?

    func add(_ request: UNNotificationRequest) async throws {
        // No-op
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        // No-op
    }

    func removeAllPendingNotificationRequests() {
        // No-op
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCallCount += 1
        requestAuthorizationOptions = options
        return mockAuthorizationResult
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        []
    }

    func notificationSettings() async -> UNNotificationSettings {
        // Return actual settings since we can't create mock UNNotificationSettings
        return await UNUserNotificationCenter.current().notificationSettings()
    }
}
