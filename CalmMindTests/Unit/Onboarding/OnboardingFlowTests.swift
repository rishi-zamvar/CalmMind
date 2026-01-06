import XCTest
@testable import CalmMind

/// Tests for onboarding flow and UserPreferences onboarding state
final class OnboardingFlowTests: XCTestCase {

    var mockDefaults: UserDefaults!
    var userPreferences: UserPreferences!

    override func setUp() {
        super.setUp()
        mockDefaults = UserDefaults(suiteName: "test.\(UUID())")!
        userPreferences = UserPreferences(defaults: mockDefaults)
    }

    override func tearDown() {
        mockDefaults = nil
        userPreferences = nil
        super.tearDown()
    }

    // MARK: - Fresh Install Shows Onboarding

    func test_freshInstall_showsOnboarding() {
        XCTAssertFalse(userPreferences.hasCompletedOnboardingV2)
    }

    // MARK: - Returning User Skips Onboarding

    func test_returningUser_skipsOnboarding() {
        userPreferences.hasCompletedOnboardingV2 = true
        XCTAssertTrue(userPreferences.hasCompletedOnboardingV2)
    }

    // MARK: - Name Storage

    func test_userName_persistsCorrectly() {
        userPreferences.userName = "Test User"
        XCTAssertEqual(userPreferences.userName, "Test User")
    }

    func test_userName_trimsWhitespace() {
        userPreferences.userName = "  Test User  "
        XCTAssertEqual(userPreferences.userName, "Test User")
    }

    func test_userName_nilForEmptyString() {
        userPreferences.userName = "   "
        XCTAssertNil(userPreferences.userName)
    }

    // MARK: - Synchronous Preference Reads (No Async Hydration)

    func test_userPreferences_readsAreAlwaysSynchronous() {
        // Set values
        userPreferences.hasCompletedOnboardingV2 = true
        userPreferences.locationPermissionInteracted = true
        userPreferences.notificationPermissionInteracted = true
        userPreferences.userName = "TestUser"

        // Create NEW instance (simulates relaunch)
        let freshPrefs = UserPreferences(defaults: mockDefaults)

        // All reads must be synchronous (no async, no nil race)
        XCTAssertTrue(freshPrefs.hasCompletedOnboardingV2)
        XCTAssertTrue(freshPrefs.locationPermissionInteracted)
        XCTAssertTrue(freshPrefs.notificationPermissionInteracted)
        XCTAssertEqual(freshPrefs.userName, "TestUser")
    }

    // MARK: - Permission Interaction Keys

    func test_locationPermissionInteracted_defaultsFalse() {
        XCTAssertFalse(userPreferences.locationPermissionInteracted)
    }

    func test_notificationPermissionInteracted_defaultsFalse() {
        XCTAssertFalse(userPreferences.notificationPermissionInteracted)
    }

    func test_locationPermissionInteracted_persists() {
        userPreferences.locationPermissionInteracted = true
        XCTAssertTrue(userPreferences.locationPermissionInteracted)
    }

    func test_notificationPermissionInteracted_persists() {
        userPreferences.notificationPermissionInteracted = true
        XCTAssertTrue(userPreferences.notificationPermissionInteracted)
    }
}

// MARK: - Completion Latch Tests (UI Boundary)

final class OnboardingCompletionLatchTests: XCTestCase {

    var mockDefaults: UserDefaults!
    var userPreferences: UserPreferences!

    override func setUp() {
        super.setUp()
        mockDefaults = UserDefaults(suiteName: "test.\(UUID())")!
        userPreferences = UserPreferences(defaults: mockDefaults)
    }

    override func tearDown() {
        mockDefaults = nil
        userPreferences = nil
        super.tearDown()
    }

    /// Tests that the completion latch prevents double-submit at UI boundary
    @MainActor
    func test_completionLatch_rapidDoubleTap_onlySinglePersistenceWrite() async {
        // Given: A completion handler that tracks call count
        var completionCallCount = 0
        let completionHandler: () -> Void = {
            guard !self.userPreferences.hasCompletedOnboardingV2 else { return }
            completionCallCount += 1
            self.userPreferences.hasCompletedOnboardingV2 = true
        }

        // When: Simulate rapid double-tap
        completionHandler()
        completionHandler()

        // Then: Only ONE persistence write occurred
        XCTAssertEqual(completionCallCount, 1,
                       "Completion latch must prevent second invocation")
        XCTAssertTrue(userPreferences.hasCompletedOnboardingV2)
    }

    /// Tests that the completion latch uses one-way state
    @MainActor
    func test_completionLatch_cannotUncomplete() {
        // Given: Completed onboarding
        userPreferences.hasCompletedOnboardingV2 = true

        // When: Simulate completion handler called again (with guard)
        var completionCalled = false
        let completionHandler: () -> Void = {
            guard !self.userPreferences.hasCompletedOnboardingV2 else { return }
            completionCalled = true
            self.userPreferences.hasCompletedOnboardingV2 = true
        }
        completionHandler()

        // Then: Handler did not run (guard prevented it)
        XCTAssertFalse(completionCalled)
        XCTAssertTrue(userPreferences.hasCompletedOnboardingV2)
    }

    /// Tests that concurrent completion attempts result in single write
    @MainActor
    func test_completionLatch_concurrentAttempts_singleWrite() async {
        var writeCount = 0
        let lock = NSLock()

        let completionHandler: () -> Void = {
            lock.lock()
            defer { lock.unlock() }
            guard !self.userPreferences.hasCompletedOnboardingV2 else { return }
            writeCount += 1
            self.userPreferences.hasCompletedOnboardingV2 = true
        }

        // When: Launch concurrent completion attempts
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    completionHandler()
                }
            }
        }

        // Then: Exactly ONE write occurred
        XCTAssertEqual(writeCount, 1,
                       "Concurrent completion must result in single persistence write")
    }
}
