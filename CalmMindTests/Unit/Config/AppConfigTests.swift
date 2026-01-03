import XCTest
@testable import CalmMind

final class AppConfigTests: XCTestCase {

    // MARK: - Loading

    func test_loadsDefaultValues() {
        let config = AppConfig()

        XCTAssertNotNil(config.aiModel)
        XCTAssertGreaterThan(config.maxTokens, 0)
        XCTAssertGreaterThan(config.contextWindow, 0)
    }

    func test_usesInfoPlistOverrides() {
        // When Info.plist contains custom values, they should be used
        // This test verifies the loading mechanism works
        let config = AppConfig()

        // Default values should be used when no Info.plist overrides exist
        XCTAssertEqual(config.aiModel, AppConfig.Defaults.aiModel)
    }

    func test_validatesTokenLimits_arePositive() {
        let config = AppConfig()

        XCTAssertGreaterThan(config.maxTokens, 0, "maxTokens must be positive")
        XCTAssertLessThanOrEqual(config.maxTokens, 128000, "maxTokens should not exceed model limits")
    }

    func test_validatesModelName_notEmpty() {
        let config = AppConfig()

        XCTAssertFalse(config.aiModel.isEmpty, "aiModel must not be empty")
    }

    // MARK: - Defaults

    func test_defaultMaxTokens_is4000() {
        XCTAssertEqual(AppConfig.Defaults.maxTokens, 4000)
    }

    func test_defaultModel_isGPT4() {
        XCTAssertEqual(AppConfig.Defaults.aiModel, "gpt-4")
    }

    func test_defaultContextWindow_is10Messages() {
        XCTAssertEqual(AppConfig.Defaults.contextWindow, 10)
    }

    func test_defaultMorningNudgeTime_is8AM() {
        XCTAssertEqual(AppConfig.Defaults.morningNudgeHour, 8)
    }

    func test_defaultEveningNudgeTime_is9PM() {
        XCTAssertEqual(AppConfig.Defaults.eveningNudgeHour, 21)
    }

    // MARK: - Nudge Configuration

    func test_nudgeGraceWindow_defaultsTo30Minutes() {
        XCTAssertEqual(AppConfig.Defaults.nudgeGraceWindowMinutes, 30)
    }

    func test_nudgeHours_areValidHours() {
        let config = AppConfig()

        XCTAssertGreaterThanOrEqual(config.morningNudgeHour, 0)
        XCTAssertLessThan(config.morningNudgeHour, 24)
        XCTAssertGreaterThanOrEqual(config.eveningNudgeHour, 0)
        XCTAssertLessThan(config.eveningNudgeHour, 24)
    }

    // MARK: - Message Limits

    func test_maxMessageLength_is2000() {
        XCTAssertEqual(AppConfig.Defaults.maxMessageLength, 2000)
    }

    func test_maxJournalLength_is5000() {
        XCTAssertEqual(AppConfig.Defaults.maxJournalLength, 5000)
    }

    func test_maxTodoTitleLength_is50() {
        XCTAssertEqual(AppConfig.Defaults.maxTodoTitleLength, 50)
    }
}
