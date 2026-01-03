import XCTest
@testable import CalmMind

final class UserPreferencesTests: XCTestCase {

    var sut: UserPreferences!
    var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Use a separate suite for testing
        testDefaults = UserDefaults(suiteName: "com.calmmind.tests")!
        testDefaults.removePersistentDomain(forName: "com.calmmind.tests")
        sut = UserPreferences(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "com.calmmind.tests")
        testDefaults = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Morning Notifications

    func test_morningNotificationsEnabled_defaultsTrue() {
        XCTAssertTrue(sut.morningNotificationsEnabled)
    }

    func test_morningNotificationsEnabled_canBeDisabled() {
        sut.morningNotificationsEnabled = false

        XCTAssertFalse(sut.morningNotificationsEnabled)
    }

    // MARK: - Evening Notifications

    func test_eveningNotificationsEnabled_defaultsTrue() {
        XCTAssertTrue(sut.eveningNotificationsEnabled)
    }

    func test_eveningNotificationsEnabled_canBeDisabled() {
        sut.eveningNotificationsEnabled = false

        XCTAssertFalse(sut.eveningNotificationsEnabled)
    }

    // MARK: - Privacy Mode

    func test_privacyMode_defaultsFalse() {
        XCTAssertFalse(sut.privacyModeEnabled)
    }

    func test_privacyMode_canBeEnabled() {
        sut.privacyModeEnabled = true

        XCTAssertTrue(sut.privacyModeEnabled)
    }

    // MARK: - Toggle

    func test_canTogglePreferences() {
        // Start with defaults
        XCTAssertTrue(sut.morningNotificationsEnabled)
        XCTAssertFalse(sut.privacyModeEnabled)

        // Toggle
        sut.morningNotificationsEnabled.toggle()
        sut.privacyModeEnabled.toggle()

        // Verify
        XCTAssertFalse(sut.morningNotificationsEnabled)
        XCTAssertTrue(sut.privacyModeEnabled)
    }

    // MARK: - Persistence

    func test_preferencesPersistAcrossInstances() {
        sut.morningNotificationsEnabled = false
        sut.privacyModeEnabled = true

        // Create new instance with same defaults
        let newInstance = UserPreferences(defaults: testDefaults)

        XCTAssertFalse(newInstance.morningNotificationsEnabled)
        XCTAssertTrue(newInstance.privacyModeEnabled)
    }

    // MARK: - Notification Privacy Mode

    func test_notificationPrivacyMode_defaultsToDetailed() {
        XCTAssertEqual(sut.notificationPrivacyMode, .detailed)
    }

    func test_notificationPrivacyMode_canSetToMinimal() {
        sut.notificationPrivacyMode = .minimal

        XCTAssertEqual(sut.notificationPrivacyMode, .minimal)
    }

    func test_notificationPrivacyMode_persistsAcrossInstances() {
        sut.notificationPrivacyMode = .minimal

        let newInstance = UserPreferences(defaults: testDefaults)

        XCTAssertEqual(newInstance.notificationPrivacyMode, .minimal)
    }

    // MARK: - Onboarding

    func test_hasCompletedOnboarding_defaultsFalse() {
        XCTAssertFalse(sut.hasCompletedOnboarding)
    }

    func test_hasCompletedOnboarding_canBeSet() {
        sut.hasCompletedOnboarding = true

        XCTAssertTrue(sut.hasCompletedOnboarding)
    }

    // MARK: - Nudge Tracking

    func test_lastNudgeMorningAt_defaultsToNil() {
        XCTAssertNil(sut.lastNudgeMorningAt)
    }

    func test_lastNudgeMorningAt_canBeSet() {
        let date = Date()
        sut.lastNudgeMorningAt = date

        let retrieved = sut.lastNudgeMorningAt
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved!.timeIntervalSince1970,
                       date.timeIntervalSince1970,
                       accuracy: 1)
    }

    func test_lastNudgeEveningAt_defaultsToNil() {
        XCTAssertNil(sut.lastNudgeEveningAt)
    }

    func test_lastNudgeEveningAt_canBeSet() {
        let date = Date()
        sut.lastNudgeEveningAt = date

        let retrieved = sut.lastNudgeEveningAt
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved!.timeIntervalSince1970,
                       date.timeIntervalSince1970,
                       accuracy: 1)
    }
}
