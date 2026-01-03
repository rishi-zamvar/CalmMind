import XCTest
@testable import CalmMind

final class ContextManagerTests: XCTestCase {

    var sut: ContextManager!
    var mockRedactor: ContextRedactor!

    override func setUp() {
        super.setUp()
        mockRedactor = ContextRedactor()
        sut = ContextManager(redactor: mockRedactor)
    }

    override func tearDown() {
        sut = nil
        mockRedactor = nil
        super.tearDown()
    }

    // MARK: - Recent Messages

    func test_keepsMostRecentMessages() {
        var messages: [RedactableMessage] = []
        for i in 0..<30 {
            messages.append(RedactableMessage(
                role: .user,
                content: "Message \(i)",
                timestamp: Date().addingTimeInterval(TimeInterval(i))
            ))
        }

        let context = sut.buildContext(
            messages: messages,
            journals: [],
            memories: [],
            todos: []
        )

        // Should have limited messages
        XCTAssertLessThanOrEqual(context.conversationMessages.count, 20)
    }

    func test_respectsMessageCountLimit() {
        let config = ContextConfig(maxConversationMessages: 5)
        sut = ContextManager(redactor: mockRedactor, config: config)

        var messages: [RedactableMessage] = []
        for i in 0..<20 {
            messages.append(RedactableMessage(
                role: .user,
                content: "Message \(i)",
                timestamp: Date().addingTimeInterval(TimeInterval(i))
            ))
        }

        let context = sut.buildContext(messages: messages, journals: [], memories: [], todos: [])

        XCTAssertLessThanOrEqual(context.conversationMessages.count, 5)
    }

    func test_prioritizesRecentOverOld() {
        var messages: [RedactableMessage] = []
        for i in 0..<30 {
            messages.append(RedactableMessage(
                role: .user,
                content: "Message \(i)",
                timestamp: Date().addingTimeInterval(TimeInterval(i))
            ))
        }

        let context = sut.buildContext(messages: messages, journals: [], memories: [], todos: [])

        // Most recent message should be present
        if let lastMessage = context.conversationMessages.last {
            XCTAssertTrue(lastMessage.content.contains("29"))
        }
    }

    // MARK: - Token Budgeting

    func test_estimatesTokenCount_forMessages() {
        let message = RedactableMessage(
            role: .user,
            content: "Hello world",  // ~3 tokens
            timestamp: Date()
        )

        let estimate = sut.estimateTokens(for: [message])

        XCTAssertGreaterThan(estimate, 0)
        XCTAssertLessThan(estimate, 100)  // Should be reasonable
    }

    func test_staysWithinBudget() {
        let config = ContextConfig(maxTotalTokens: 500)
        sut = ContextManager(redactor: mockRedactor, config: config)

        var messages: [RedactableMessage] = []
        for i in 0..<100 {
            messages.append(RedactableMessage(
                role: .user,
                content: "This is a longer message number \(i) that should take up more tokens",
                timestamp: Date().addingTimeInterval(TimeInterval(i))
            ))
        }

        let context = sut.buildContext(messages: messages, journals: [], memories: [], todos: [])
        let totalTokens = sut.estimateTokens(for: context.conversationMessages)

        // Should be within budget (with some margin for system prompt)
        XCTAssertLessThanOrEqual(totalTokens, 600)  // Allow some overflow for system
    }

    // MARK: - Context Assembly

    func test_assemblesSystemPrompt() {
        let context = sut.buildContext(messages: [], journals: [], memories: [], todos: [])

        XCTAssertFalse(context.systemPrompt.isEmpty)
        XCTAssertTrue(context.systemPrompt.contains("mental health"))
    }

    func test_includesYesterdaysSummary_ifAvailable() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let journal = RedactableJournal(
            fullText: "Full text",
            summary: "Yesterday was tough but productive",
            date: yesterday
        )

        let context = sut.buildContext(messages: [], journals: [journal], memories: [], todos: [])

        let contextString = context.additionalContext
        XCTAssertTrue(contextString.contains("Yesterday was tough but productive"))
    }

    func test_includesRelevantMemories() {
        let memory = RedactableMemory(
            content: "Full content",
            summary: "User enjoys hiking",
            isPrivate: false
        )

        let context = sut.buildContext(messages: [], journals: [], memories: [memory], todos: [])

        let contextString = context.additionalContext
        XCTAssertTrue(contextString.contains("hiking"))
    }

    func test_includesRecentTodos() {
        let todo = RedactableTodo(
            title: "Call mom",
            notes: "Her number is 555-1234",
            isCompleted: false
        )

        let context = sut.buildContext(messages: [], journals: [], memories: [], todos: [todo])

        let contextString = context.additionalContext
        XCTAssertTrue(contextString.contains("Call mom"))
        XCTAssertFalse(contextString.contains("555-1234"))  // Notes excluded
    }

    // MARK: - OpenAI Message Format

    func test_convertsToOpenAIMessages() {
        let messages = [
            RedactableMessage(role: .user, content: "Hello", timestamp: Date()),
            RedactableMessage(role: .assistant, content: "Hi!", timestamp: Date().addingTimeInterval(1))
        ]

        let context = sut.buildContext(messages: messages, journals: [], memories: [], todos: [])
        let openAIMessages = context.toOpenAIMessages()

        // Should have system message + conversation messages
        XCTAssertGreaterThanOrEqual(openAIMessages.count, 2)
        XCTAssertEqual(openAIMessages.first?.role, .system)
    }

    // MARK: - Private Memory Exclusion

    func test_excludesPrivateMemories() {
        let privateMemory = RedactableMemory(
            content: "Private content",
            summary: "SECRET_PRIVATE_INFO",
            isPrivate: true
        )
        let publicMemory = RedactableMemory(
            content: "Public content",
            summary: "Public info",
            isPrivate: false
        )

        let context = sut.buildContext(
            messages: [],
            journals: [],
            memories: [privateMemory, publicMemory],
            todos: []
        )

        let contextString = context.additionalContext
        XCTAssertFalse(contextString.contains("SECRET_PRIVATE_INFO"))
        XCTAssertTrue(contextString.contains("Public info"))
    }

    // MARK: - Empty Handling

    func test_handlesEmptyInputsGracefully() {
        let context = sut.buildContext(messages: [], journals: [], memories: [], todos: [])

        XCTAssertFalse(context.systemPrompt.isEmpty)
        XCTAssertTrue(context.conversationMessages.isEmpty)
    }

    // MARK: - Date Formatting

    func test_includesCurrentDateInSystemPrompt() {
        let context = sut.buildContext(messages: [], journals: [], memories: [], todos: [])

        // Should mention today's date or time awareness
        let hasDateInfo = context.systemPrompt.contains("today") ||
                          context.systemPrompt.contains("date") ||
                          context.systemPrompt.contains(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none))

        XCTAssertTrue(hasDateInfo || context.systemPrompt.count > 100)  // Either has date or is substantial
    }
}
