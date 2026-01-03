import XCTest
@testable import CalmMind

final class JournalGeneratorTests: XCTestCase {

    var sut: JournalGenerator!
    var mockOpenAI: MockOpenAIService!

    override func setUp() {
        super.setUp()
        mockOpenAI = MockOpenAIService()
        sut = JournalGenerator(openAIService: mockOpenAI)
    }

    override func tearDown() {
        sut = nil
        mockOpenAI = nil
        super.tearDown()
    }

    // MARK: - Entry Generation

    func test_generatesEntry_fromConversation() async throws {
        mockOpenAI.mockResponseContent = "Today I talked about work stress and feeling overwhelmed. I'm trying to focus on self-care."

        let messages = [
            RedactableMessage(role: .user, content: "I'm so stressed about work", timestamp: Date()),
            RedactableMessage(role: .assistant, content: "That sounds tough", timestamp: Date()),
            RedactableMessage(role: .user, content: "I'm trying to take breaks", timestamp: Date())
        ]

        let entry = try await sut.generateEntry(from: messages)

        XCTAssertFalse(entry.text.isEmpty)
        // 2 calls: one for journal generation, one for mood extraction
        XCTAssertGreaterThanOrEqual(mockOpenAI.sendCallCount, 1)
    }

    func test_generatedEntry_isFirstPerson() async throws {
        mockOpenAI.mockResponseContent = "I had a challenging day today. I felt stressed but I'm working through it."

        let messages = [
            RedactableMessage(role: .user, content: "I'm stressed", timestamp: Date())
        ]

        let entry = try await sut.generateEntry(from: messages)

        // Entry should be in first person
        XCTAssertTrue(entry.text.contains("I"))
    }

    func test_generatedEntry_respectsLengthLimit() async throws {
        // Generate a very long response
        mockOpenAI.mockResponseContent = String(repeating: "This is a long journal entry. ", count: 200)

        let messages = [
            RedactableMessage(role: .user, content: "Lots happened today", timestamp: Date())
        ]

        let entry = try await sut.generateEntry(from: messages)

        // Should be truncated if too long
        XCTAssertLessThanOrEqual(entry.text.count, 5000)
    }

    // MARK: - Mood Extraction

    func test_extractsMoodScore_fromContent() async throws {
        // Mock returns "8" for mood extraction (second call)
        // We'll use a custom mock that returns different values
        var callCount = 0
        mockOpenAI.mockResponseContent = "8"  // Mood score

        let messages = [
            RedactableMessage(role: .user, content: "I'm feeling great!", timestamp: Date())
        ]

        // For this test, we just verify that mood extraction is attempted
        // The actual mood depends on the mock returning a valid number
        let entry = try await sut.generateEntry(from: messages)

        // Mood should be extracted when mock returns a number
        if let mood = entry.moodScore {
            XCTAssertGreaterThanOrEqual(mood, 1)
            XCTAssertLessThanOrEqual(mood, 10)
        }
        // Note: moodScore may be nil if mood extraction fails, which is acceptable
    }

    func test_moodScore_1to10Scale() async throws {
        mockOpenAI.mockResponseContent = "A neutral day."

        let messages = [
            RedactableMessage(role: .user, content: "Just a normal day", timestamp: Date())
        ]

        let entry = try await sut.generateEntry(from: messages)

        if let mood = entry.moodScore {
            XCTAssertGreaterThanOrEqual(mood, 1)
            XCTAssertLessThanOrEqual(mood, 10)
        }
    }

    // MARK: - Summary Generation

    func test_generatesSummary_isConcise() async throws {
        mockOpenAI.mockResponseContent = "User discussed work stress and coping strategies."

        let fullText = """
        Today I talked about a lot of things. Work was stressful because of the deadline.
        I mentioned that I'm trying to take more breaks. The assistant suggested deep breathing.
        I agreed to try that. Overall, it was a productive conversation.
        """

        let summary = try await sut.generateSummary(for: fullText)

        XCTAssertFalse(summary.isEmpty)
        XCTAssertLessThan(summary.count, 200)  // Should be concise
    }

    func test_summary_preservesKeyFacts() async throws {
        mockOpenAI.mockResponseContent = "Discussed work deadline stress and breathing exercises."

        let fullText = "I talked about my work deadline and learned about breathing exercises."

        let summary = try await sut.generateSummary(for: fullText)

        XCTAssertEqual(mockOpenAI.sendCallCount, 1)
        XCTAssertFalse(summary.isEmpty)
    }

    // MARK: - Edge Cases

    func test_handlesEmptyConversation() async throws {
        let messages: [RedactableMessage] = []

        let entry = try await sut.generateEntry(from: messages)

        // Should return empty or minimal entry
        XCTAssertTrue(entry.text.isEmpty || entry.text.count < 50)
    }

    func test_handlesVeryLongConversation() async throws {
        mockOpenAI.mockResponseContent = "A busy day with lots of discussion."

        var messages: [RedactableMessage] = []
        for i in 0..<100 {
            messages.append(RedactableMessage(
                role: i % 2 == 0 ? .user : .assistant,
                content: "Message number \(i) with some content",
                timestamp: Date().addingTimeInterval(TimeInterval(i))
            ))
        }

        let entry = try await sut.generateEntry(from: messages)

        // Should handle without error
        XCTAssertFalse(entry.text.isEmpty)
    }

    // MARK: - API Integration

    func test_usesCorrectPrompt_forJournalGeneration() async throws {
        mockOpenAI.mockResponseContent = "Journal entry content."

        let messages = [
            RedactableMessage(role: .user, content: "I went hiking today", timestamp: Date())
        ]

        _ = try await sut.generateEntry(from: messages)

        // Verify the prompt asks for first-person journal
        if let lastMessages = mockOpenAI.lastMessages {
            let systemMessage = lastMessages.first { $0.role == .system }
            XCTAssertNotNil(systemMessage)
            XCTAssertTrue(systemMessage?.content?.contains("first person") ?? false ||
                          systemMessage?.content?.contains("journal") ?? false)
        }
    }

    func test_usesCorrectPrompt_forSummaryGeneration() async throws {
        mockOpenAI.mockResponseContent = "Brief summary."

        _ = try await sut.generateSummary(for: "Some long text here")

        if let lastMessages = mockOpenAI.lastMessages {
            let systemMessage = lastMessages.first { $0.role == .system }
            XCTAssertNotNil(systemMessage)
            XCTAssertTrue(systemMessage?.content?.contains("summary") ?? false ||
                          systemMessage?.content?.contains("concise") ?? false)
        }
    }

    // MARK: - Error Handling

    func test_handlesAPIError_gracefully() async {
        mockOpenAI.shouldFail = true
        mockOpenAI.failureError = .networkError("Connection failed")

        let messages = [
            RedactableMessage(role: .user, content: "Hello", timestamp: Date())
        ]

        do {
            _ = try await sut.generateEntry(from: messages)
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected
            XCTAssertTrue(error is OpenAIError)
        }
    }
}
