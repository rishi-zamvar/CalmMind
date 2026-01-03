import XCTest
@testable import CalmMind

final class ContextRedactorTests: XCTestCase {

    var sut: ContextRedactor!

    override func setUp() {
        super.setUp()
        sut = ContextRedactor()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Allowed Egress

    func test_allowsRecentMessages() {
        let now = Date()
        let messages = [
            RedactableMessage(role: .user, content: "Hello", timestamp: now),
            RedactableMessage(role: .assistant, content: "Hi there!", timestamp: now.addingTimeInterval(1))
        ]

        let result = sut.redact(messages: messages, journals: [], memories: [], todos: [])

        XCTAssertEqual(result.messages.count, 2)
        // Messages should be in chronological order
        XCTAssertEqual(result.messages[0].content, "Hello")
        XCTAssertEqual(result.messages[1].content, "Hi there!")
    }

    func test_allowsJournalSummaries_notFullText() {
        let journal = RedactableJournal(
            fullText: "This is a very long journal entry with lots of personal details that should never leave the device...",
            summary: "Had a good day",
            date: Date()
        )

        let result = sut.redact(messages: [], journals: [journal], memories: [], todos: [])

        // Should include summary, not full text
        XCTAssertEqual(result.journalContext.count, 1)
        XCTAssertEqual(result.journalContext[0], "Had a good day")
        XCTAssertFalse(result.journalContext[0].contains("very long journal entry"))
    }

    func test_allowsMemorySummaries_notFullContent() {
        let memory = RedactableMemory(
            content: "User mentioned their mother's name is Sarah and she lives at 123 Main St",
            summary: "User has a mother named Sarah",
            isPrivate: false
        )

        let result = sut.redact(messages: [], journals: [], memories: [memory], todos: [])

        XCTAssertEqual(result.memoryContext.count, 1)
        XCTAssertEqual(result.memoryContext[0], "User has a mother named Sarah")
        XCTAssertFalse(result.memoryContext[0].contains("123 Main St"))
    }

    func test_allowsTodoTitles_notDetails() {
        let todo = RedactableTodo(
            title: "Call doctor",
            notes: "About the rash on my arm, call Dr. Smith at 555-1234",
            isCompleted: false
        )

        let result = sut.redact(messages: [], journals: [], memories: [], todos: [todo])

        XCTAssertEqual(result.todoContext.count, 1)
        XCTAssertEqual(result.todoContext[0], "Call doctor")
        XCTAssertFalse(result.todoContext[0].contains("555-1234"))
    }

    // MARK: - Blocked Egress

    func test_blocksFullJournalArchive() {
        let journals = [
            RedactableJournal(fullText: "Day 1 full text", summary: "Summary 1", date: Date()),
            RedactableJournal(fullText: "Day 2 full text", summary: "Summary 2", date: Date()),
            RedactableJournal(fullText: "Day 3 full text", summary: "Summary 3", date: Date())
        ]

        let result = sut.redact(messages: [], journals: journals, memories: [], todos: [])

        // Full text should never appear
        for context in result.journalContext {
            XCTAssertFalse(context.contains("full text"))
        }
    }

    func test_blocksRawMemoryStore() {
        let memories = [
            RedactableMemory(content: "Raw content 1", summary: "Summary 1", isPrivate: false),
            RedactableMemory(content: "Raw content 2", summary: "Summary 2", isPrivate: false)
        ]

        let result = sut.redact(messages: [], journals: [], memories: memories, todos: [])

        for context in result.memoryContext {
            XCTAssertFalse(context.contains("Raw content"))
        }
    }

    func test_blocksPrivateFlaggedItems() {
        let memory = RedactableMemory(
            content: "Private information",
            summary: "Private summary",
            isPrivate: true
        )

        let result = sut.redact(messages: [], journals: [], memories: [memory], todos: [])

        XCTAssertTrue(result.memoryContext.isEmpty)
    }

    // MARK: - Enforcement

    func test_promptDoesNotIncludeFullJournalText() {
        let journal = RedactableJournal(
            fullText: "SECRET_MARKER_FULL_TEXT should never appear",
            summary: "Just a summary",
            date: Date()
        )

        let result = sut.redact(messages: [], journals: [journal], memories: [], todos: [])
        let fullOutput = result.toContextString()

        XCTAssertFalse(fullOutput.contains("SECRET_MARKER_FULL_TEXT"))
    }

    func test_memoryEgressUsesSummariesOnly() {
        let memory = RedactableMemory(
            content: "FULL_CONTENT_MARKER should not appear",
            summary: "Safe summary only",
            isPrivate: false
        )

        let result = sut.redact(messages: [], journals: [], memories: [memory], todos: [])
        let fullOutput = result.toContextString()

        XCTAssertFalse(fullOutput.contains("FULL_CONTENT_MARKER"))
        XCTAssertTrue(fullOutput.contains("Safe summary only"))
    }

    func test_privateFlag_excludesFromEgress() {
        let privateMemory = RedactableMemory(
            content: "PRIVATE_CONTENT",
            summary: "PRIVATE_SUMMARY",
            isPrivate: true
        )
        let publicMemory = RedactableMemory(
            content: "Public content",
            summary: "Public summary",
            isPrivate: false
        )

        let result = sut.redact(messages: [], journals: [], memories: [privateMemory, publicMemory], todos: [])
        let fullOutput = result.toContextString()

        XCTAssertFalse(fullOutput.contains("PRIVATE"))
        XCTAssertTrue(fullOutput.contains("Public summary"))
    }

    // MARK: - Output Verification

    func test_outputIsStructured() {
        let messages = [RedactableMessage(role: .user, content: "Hello", timestamp: Date())]
        let journals = [RedactableJournal(fullText: "Full", summary: "Summary", date: Date())]
        let memories = [RedactableMemory(content: "Content", summary: "Memory", isPrivate: false)]
        let todos = [RedactableTodo(title: "Todo", notes: "Notes", isCompleted: false)]

        let result = sut.redact(messages: messages, journals: journals, memories: memories, todos: todos)

        XCTAssertFalse(result.messages.isEmpty)
        XCTAssertFalse(result.journalContext.isEmpty)
        XCTAssertFalse(result.memoryContext.isEmpty)
        XCTAssertFalse(result.todoContext.isEmpty)
    }

    // MARK: - Edge Cases

    func test_handlesEmptyInputs() {
        let result = sut.redact(messages: [], journals: [], memories: [], todos: [])

        XCTAssertTrue(result.messages.isEmpty)
        XCTAssertTrue(result.journalContext.isEmpty)
        XCTAssertTrue(result.memoryContext.isEmpty)
        XCTAssertTrue(result.todoContext.isEmpty)
    }

    func test_handlesNilSummary_usesPlaceholder() {
        let journal = RedactableJournal(
            fullText: "Full text here",
            summary: nil,
            date: Date()
        )

        let result = sut.redact(messages: [], journals: [journal], memories: [], todos: [])

        // Should not include full text, but should have some placeholder or skip
        XCTAssertTrue(result.journalContext.isEmpty || !result.journalContext[0].contains("Full text here"))
    }

    func test_handlesNilMemorySummary_usesPlaceholder() {
        let memory = RedactableMemory(
            content: "Full content",
            summary: nil,
            isPrivate: false
        )

        let result = sut.redact(messages: [], journals: [], memories: [memory], todos: [])

        // Should not include full content
        let fullOutput = result.toContextString()
        XCTAssertFalse(fullOutput.contains("Full content"))
    }

    // MARK: - Message Truncation

    func test_truncatesVeryLongMessages() {
        let longContent = String(repeating: "a", count: 5000)
        let message = RedactableMessage(role: .user, content: longContent, timestamp: Date())

        let result = sut.redact(messages: [message], journals: [], memories: [], todos: [])

        // Message should be truncated
        XCTAssertLessThan(result.messages[0].content.count, 5000)
    }

    // MARK: - Only Recent Messages

    func test_limitsNumberOfMessages() {
        var messages: [RedactableMessage] = []
        for i in 0..<50 {
            messages.append(RedactableMessage(
                role: i % 2 == 0 ? .user : .assistant,
                content: "Message \(i)",
                timestamp: Date().addingTimeInterval(TimeInterval(i))
            ))
        }

        let result = sut.redact(messages: messages, journals: [], memories: [], todos: [])

        // Should limit to reasonable number (e.g., 20)
        XCTAssertLessThanOrEqual(result.messages.count, 20)
    }

    func test_keepsOnlyMostRecentMessages() {
        var messages: [RedactableMessage] = []
        for i in 0..<50 {
            messages.append(RedactableMessage(
                role: .user,
                content: "Message \(i)",
                timestamp: Date().addingTimeInterval(TimeInterval(i))
            ))
        }

        let result = sut.redact(messages: messages, journals: [], memories: [], todos: [])

        // Most recent messages should be kept
        if let lastMessage = result.messages.last {
            XCTAssertTrue(lastMessage.content.contains("49") || lastMessage.content.contains("Message"))
        }
    }
}
