import XCTest
@testable import CalmMind

final class AutoJournalingSettingsTests: XCTestCase {

    var sut: UserPreferences!
    var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "com.calmmind.test.autojournaling")!
        testDefaults.removePersistentDomain(forName: "com.calmmind.test.autojournaling")
        sut = UserPreferences(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "com.calmmind.test.autojournaling")
        sut = nil
        testDefaults = nil
        super.tearDown()
    }

    // MARK: - Opt-In Tests (Consent Required)

    func test_autoJournalingEnabled_defaultsToFalse() {
        // CRITICAL: Must be opt-in (default OFF) for consent
        XCTAssertFalse(sut.autoJournalingEnabled)
    }

    func test_autoJournalingEnabled_canBeEnabled() {
        sut.autoJournalingEnabled = true

        XCTAssertTrue(sut.autoJournalingEnabled)
    }

    func test_autoJournalingEnabled_canBeDisabled() {
        sut.autoJournalingEnabled = true
        sut.autoJournalingEnabled = false

        XCTAssertFalse(sut.autoJournalingEnabled)
    }

    func test_autoJournalingEnabled_persistsAcrossSessions() {
        sut.autoJournalingEnabled = true

        // Create new instance with same defaults
        let newSut = UserPreferences(defaults: testDefaults)

        XCTAssertTrue(newSut.autoJournalingEnabled)
    }

    // MARK: - Reset Tests

    func test_resetToDefaults_disablesAutoJournaling() {
        sut.autoJournalingEnabled = true

        sut.resetToDefaults()

        XCTAssertFalse(sut.autoJournalingEnabled)
    }

    // MARK: - Contrast with autoCreateTodos

    func test_autoCreateTodos_defaultsToTrue() {
        // autoCreateTodos is opt-OUT (default ON) - different from journaling
        XCTAssertTrue(sut.autoCreateTodos)
    }

    func test_consentDifference_journalingOptInTodosOptOut() {
        // Verify intentional difference in consent models
        XCTAssertFalse(sut.autoJournalingEnabled, "Journaling must require opt-in")
        XCTAssertTrue(sut.autoCreateTodos, "Todos can be opt-out")
    }
}
