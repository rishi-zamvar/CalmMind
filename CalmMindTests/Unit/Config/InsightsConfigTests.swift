import XCTest
@testable import CalmMind

/// Tests for InsightsConfig - config-driven AI insights settings
/// All values centralized, no hardcoded model names in business logic
final class InsightsConfigTests: XCTestCase {

    // MARK: - Default Values

    func test_defaults_modelIsConfigurable() {
        let config = InsightsConfig()
        XCTAssertFalse(config.model.isEmpty, "Model must have default value")
        // Model comes from config, not hardcoded in business logic
        XCTAssertEqual(config.model, InsightsConfig.Defaults.model)
    }

    func test_defaults_maxInputTokens_hasReasonableLimit() {
        let config = InsightsConfig()
        XCTAssertGreaterThan(config.maxInputTokens, 0)
        XCTAssertLessThanOrEqual(config.maxInputTokens, 4000, "Input should be bounded")
    }

    func test_defaults_maxOutputTokens_hasReasonableLimit() {
        let config = InsightsConfig()
        XCTAssertGreaterThan(config.maxOutputTokens, 0)
        XCTAssertLessThanOrEqual(config.maxOutputTokens, 500, "Output should be bounded")
    }

    func test_defaults_timeoutSeconds_isBounded() {
        let config = InsightsConfig()
        XCTAssertGreaterThanOrEqual(config.timeoutSeconds, 10)
        XCTAssertLessThanOrEqual(config.timeoutSeconds, 60)
    }

    func test_defaults_maxRetries_isCapped() {
        let config = InsightsConfig()
        XCTAssertGreaterThanOrEqual(config.maxRetries, 0)
        XCTAssertLessThanOrEqual(config.maxRetries, 3)
    }

    func test_defaults_maxPatterns() {
        let config = InsightsConfig()
        XCTAssertEqual(config.maxPatterns, 2)
    }

    func test_defaults_maxSuggestions() {
        let config = InsightsConfig()
        XCTAssertEqual(config.maxSuggestions, 2)
    }

    func test_defaults_maxItemLength() {
        let config = InsightsConfig()
        XCTAssertEqual(config.maxItemLength, 100)
    }

    func test_defaults_charsPerToken() {
        let config = InsightsConfig()
        XCTAssertEqual(config.charsPerToken, 4)
    }

    // MARK: - Shared Instance

    func test_shared_returnsSameInstance() {
        let instance1 = InsightsConfig.shared
        let instance2 = InsightsConfig.shared
        XCTAssertEqual(instance1.model, instance2.model)
        XCTAssertEqual(instance1.maxInputTokens, instance2.maxInputTokens)
    }

    // MARK: - Direct Initialization (for testing)

    func test_directInit_overridesDefaults() {
        let config = InsightsConfig(
            model: "custom-model",
            maxInputTokens: 1000,
            maxOutputTokens: 200,
            timeoutSeconds: 45,
            maxRetries: 1,
            maxPatterns: 3,
            maxSuggestions: 3,
            maxItemLength: 80,
            charsPerToken: 3
        )

        XCTAssertEqual(config.model, "custom-model")
        XCTAssertEqual(config.maxInputTokens, 1000)
        XCTAssertEqual(config.maxOutputTokens, 200)
        XCTAssertEqual(config.timeoutSeconds, 45)
        XCTAssertEqual(config.maxRetries, 1)
        XCTAssertEqual(config.maxPatterns, 3)
        XCTAssertEqual(config.maxSuggestions, 3)
        XCTAssertEqual(config.maxItemLength, 80)
        XCTAssertEqual(config.charsPerToken, 3)
    }

    func test_directInit_partialOverride() {
        let config = InsightsConfig(model: "test-model")

        XCTAssertEqual(config.model, "test-model")
        XCTAssertEqual(config.maxInputTokens, InsightsConfig.Defaults.maxInputTokens)
        XCTAssertEqual(config.maxOutputTokens, InsightsConfig.Defaults.maxOutputTokens)
    }

    // MARK: - Defaults Enum Access

    func test_defaultsEnum_accessible() {
        XCTAssertEqual(InsightsConfig.Defaults.model, "gpt-4o-mini")
        XCTAssertEqual(InsightsConfig.Defaults.maxInputTokens, 2000)
        XCTAssertEqual(InsightsConfig.Defaults.maxOutputTokens, 300)
        XCTAssertEqual(InsightsConfig.Defaults.timeoutSeconds, 30)
        XCTAssertEqual(InsightsConfig.Defaults.maxRetries, 2)
        XCTAssertEqual(InsightsConfig.Defaults.maxPatterns, 2)
        XCTAssertEqual(InsightsConfig.Defaults.maxSuggestions, 2)
        XCTAssertEqual(InsightsConfig.Defaults.maxItemLength, 100)
        XCTAssertEqual(InsightsConfig.Defaults.charsPerToken, 4)
    }

    // MARK: - Bundle Initialization (for Info.plist override)

    func test_bundleInit_fallsBackToDefaults_whenNoInfoPlist() {
        let emptyBundle = Bundle(for: type(of: self))
        let config = InsightsConfig(bundle: emptyBundle)

        // Should use defaults when plist values not present
        XCTAssertEqual(config.model, InsightsConfig.Defaults.model)
        XCTAssertEqual(config.maxInputTokens, InsightsConfig.Defaults.maxInputTokens)
    }

    // MARK: - Token Budget Enforcement

    func test_truncateToTokenBudget_shortInput_unchanged() {
        let config = InsightsConfig()
        let shortInput = "Hello world"
        let truncated = config.truncateToTokenBudget(shortInput)
        XCTAssertEqual(truncated, shortInput)
    }

    func test_truncateToTokenBudget_longInput_truncated() {
        let config = InsightsConfig(maxInputTokens: 100, charsPerToken: 4)
        let longInput = String(repeating: "word ", count: 200) // 1000 chars
        let truncated = config.truncateToTokenBudget(longInput)

        // maxInputTokens * charsPerToken = 100 * 4 = 400 chars
        XCTAssertEqual(truncated.count, 400)
    }

    func test_truncateToTokenBudget_enforcesMaxChars() {
        let config = InsightsConfig()
        let longInput = String(repeating: "x", count: 50000)
        let truncated = config.truncateToTokenBudget(longInput)

        let maxChars = config.maxInputTokens * config.charsPerToken
        XCTAssertLessThanOrEqual(truncated.count, maxChars)
    }

    func test_truncateToTokenBudget_preservesPrefix() {
        let config = InsightsConfig(maxInputTokens: 10, charsPerToken: 4) // 40 chars
        let input = "The quick brown fox jumps over the lazy dog and more text"
        let truncated = config.truncateToTokenBudget(input)

        XCTAssertTrue(input.hasPrefix(truncated))
    }
}
