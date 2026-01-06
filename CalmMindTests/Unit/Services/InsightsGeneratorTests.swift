import XCTest
@testable import CalmMind

/// Tests for InsightsGenerator - config-driven generation with allowlist enforcement
/// Errors propagate (no silent swallowing) and provenance is tracked
final class InsightsGeneratorTests: XCTestCase {

    var sut: InsightsGenerator!
    var mockOpenAI: MockOpenAIService!
    var config: InsightsConfig!

    override func setUp() {
        super.setUp()
        mockOpenAI = MockOpenAIService()
        config = InsightsConfig()
        sut = InsightsGenerator(
            openAIService: mockOpenAI,
            config: config,
            parser: InsightsParser(config: config),
            allowlist: WellnessAllowlist()
        )
    }

    override func tearDown() {
        mockOpenAI = nil
        sut = nil
        config = nil
        super.tearDown()
    }

    // MARK: - Config-Driven Model Routing

    func test_generate_usesConfiguredModel() async throws {
        mockOpenAI.mockResponseContent = """
        PATTERNS:
        - Test pattern
        SUGGESTIONS:
        - Take a walk
        """

        _ = try await sut.generate(for: "Test entry")

        XCTAssertEqual(mockOpenAI.lastModel, config.model)
    }

    func test_generate_usesConfiguredMaxTokens() async throws {
        mockOpenAI.mockResponseContent = "PATTERNS:\n- Test\nSUGGESTIONS:\n- Take a walk"

        _ = try await sut.generate(for: "Test")

        XCTAssertEqual(mockOpenAI.lastMaxTokens, config.maxOutputTokens)
    }

    func test_generate_customConfig_usesCustomModel() async throws {
        let customConfig = InsightsConfig(model: "custom-model-name")
        let customSut = InsightsGenerator(
            openAIService: mockOpenAI,
            config: customConfig
        )
        mockOpenAI.mockResponseContent = "PATTERNS:\n- Test\nSUGGESTIONS:\n- Walk"

        _ = try await customSut.generate(for: "Test")

        XCTAssertEqual(mockOpenAI.lastModel, "custom-model-name")
    }

    // MARK: - Input Budget Enforcement

    func test_generate_longInput_isTruncated() async throws {
        mockOpenAI.mockResponseContent = "PATTERNS:\n- Test\nSUGGESTIONS:\n- Take a walk"
        let longInput = String(repeating: "word ", count: 10000)

        _ = try await sut.generate(for: longInput)

        // Verify input was truncated (check last message content length)
        let sentContent = mockOpenAI.lastMessages?.last?.content ?? ""
        let maxChars = config.maxInputTokens * config.charsPerToken
        XCTAssertLessThanOrEqual(sentContent.count, maxChars)
    }

    func test_generate_shortInput_notTruncated() async throws {
        mockOpenAI.mockResponseContent = "PATTERNS:\n- Test\nSUGGESTIONS:\n- Take a walk"
        let shortInput = "This is a short entry about my day."

        _ = try await sut.generate(for: shortInput)

        let sentContent = mockOpenAI.lastMessages?.last?.content ?? ""
        XCTAssertEqual(sentContent, shortInput)
    }

    // MARK: - Allowlist Enforcement

    func test_generate_disallowedSuggestion_isFiltered() async throws {
        mockOpenAI.mockResponseContent = """
        PATTERNS:
        - Stress noted
        SUGGESTIONS:
        - See a therapist immediately
        - Try breathing exercises
        """

        let result = try await sut.generate(for: "Test")

        // Only breathing should pass through (therapist is blocked)
        XCTAssertEqual(result.suggestions.count, 1)
        XCTAssertTrue(result.suggestions[0].lowercased().contains("breathing"))
    }

    func test_generate_allAllowedSuggestions_passThrough() async throws {
        mockOpenAI.mockResponseContent = """
        PATTERNS:
        - Good mood noted
        SUGGESTIONS:
        - Take a walk outside
        - Try 4-7-8 breathing
        """

        let result = try await sut.generate(for: "Test")

        XCTAssertEqual(result.suggestions.count, 2)
    }

    func test_generate_patterns_notFiltered() async throws {
        // Patterns are not filtered by allowlist (only suggestions are)
        mockOpenAI.mockResponseContent = """
        PATTERNS:
        - Doctor visit mentioned
        - Therapy session noted
        SUGGESTIONS:
        - Take a walk
        """

        let result = try await sut.generate(for: "Test")

        // Patterns can mention anything - they're observations, not advice
        XCTAssertEqual(result.patterns.count, 2)
    }

    // MARK: - Provenance

    func test_generate_storesProvenance() async throws {
        mockOpenAI.mockResponseContent = "PATTERNS:\n- Test\nSUGGESTIONS:\n- Take a walk"

        let result = try await sut.generate(for: "My journal entry")

        XCTAssertEqual(result.providerModel, config.model)
        XCTAssertNotNil(result.generatedAt)
        XCTAssertFalse(result.inputHash.isEmpty)
    }

    func test_generate_inputHashMatchesInput() async throws {
        mockOpenAI.mockResponseContent = "PATTERNS:\n- Test\nSUGGESTIONS:\n- Take a walk"
        let input = "My journal entry"

        let result = try await sut.generate(for: input)

        // Hash should be computed from input (truncated if needed)
        let expectedHash = JournalInsights.computeInputHash(input)
        XCTAssertEqual(result.inputHash, expectedHash)
    }

    func test_generate_truncatedInput_hashMatchesTruncated() async throws {
        let smallConfig = InsightsConfig(maxInputTokens: 10, charsPerToken: 4) // 40 chars
        let smallSut = InsightsGenerator(
            openAIService: mockOpenAI,
            config: smallConfig
        )
        mockOpenAI.mockResponseContent = "PATTERNS:\n- Test\nSUGGESTIONS:\n- Walk"

        let longInput = String(repeating: "x", count: 100) // Will be truncated to 40
        let result = try await smallSut.generate(for: longInput)

        // Hash should match truncated input, not original
        let truncatedInput = smallConfig.truncateToTokenBudget(longInput)
        let expectedHash = JournalInsights.computeInputHash(truncatedInput)
        XCTAssertEqual(result.inputHash, expectedHash)
    }

    // MARK: - Error Handling (No Silent Swallowing)

    func test_generate_networkError_throws() async {
        mockOpenAI.shouldFail = true
        mockOpenAI.failureError = .networkError("Connection failed")

        do {
            _ = try await sut.generate(for: "Test")
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected - error propagates, not silently swallowed
            XCTAssertTrue(error is OpenAIError)
        }
    }

    func test_generate_apiError_throws() async {
        mockOpenAI.shouldFail = true
        mockOpenAI.failureError = .httpError(statusCode: 500, message: "Server error")

        do {
            _ = try await sut.generate(for: "Test")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is OpenAIError)
        }
    }

    func test_generate_rateLimitError_throws() async {
        mockOpenAI.shouldFail = true
        mockOpenAI.failureError = .rateLimited(retryAfter: 30)

        do {
            _ = try await sut.generate(for: "Test")
            XCTFail("Expected error to be thrown")
        } catch let error as OpenAIError {
            if case .rateLimited = error {
                // Expected
            } else {
                XCTFail("Expected rate limit error")
            }
        } catch {
            XCTFail("Expected OpenAIError")
        }
    }

    // MARK: - Empty/Edge Cases

    func test_generate_emptyResponse_returnsEmptyInsights() async throws {
        mockOpenAI.mockResponseContent = ""

        let result = try await sut.generate(for: "Test")

        XCTAssertTrue(result.patterns.isEmpty)
        XCTAssertTrue(result.suggestions.isEmpty)
    }

    func test_generate_malformedResponse_returnsEmptyInsights() async throws {
        mockOpenAI.mockResponseContent = "This is not formatted correctly at all."

        let result = try await sut.generate(for: "Test")

        XCTAssertTrue(result.patterns.isEmpty)
        XCTAssertTrue(result.suggestions.isEmpty)
    }

    func test_generate_onlyPatterns_returnsEmptySuggestions() async throws {
        mockOpenAI.mockResponseContent = """
        PATTERNS:
        - Pattern observed
        """

        let result = try await sut.generate(for: "Test")

        XCTAssertEqual(result.patterns.count, 1)
        XCTAssertTrue(result.suggestions.isEmpty)
    }

    // MARK: - System Prompt Sent

    func test_generate_sendsSystemPrompt() async throws {
        mockOpenAI.mockResponseContent = "PATTERNS:\n- Test\nSUGGESTIONS:\n- Walk"

        _ = try await sut.generate(for: "Test")

        // Should have at least 2 messages: system + user
        XCTAssertNotNil(mockOpenAI.lastMessages)
        XCTAssertGreaterThanOrEqual(mockOpenAI.lastMessages?.count ?? 0, 2)

        // First message should be system prompt
        let systemMessage = mockOpenAI.lastMessages?.first
        XCTAssertEqual(systemMessage?.role, .system)
    }
}
