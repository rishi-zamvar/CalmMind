import XCTest
import SwiftData
@testable import CalmMind

final class ChatMessageTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: ChatMessage.self, DailySession.self, configurations: config)
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Creation

    func test_createUserMessage_setsCorrectRole() {
        let message = ChatMessage(content: "Hello", role: .user)

        XCTAssertEqual(message.role, .user)
    }

    func test_createAssistantMessage_setsCorrectRole() {
        let message = ChatMessage(content: "Hi there!", role: .assistant)

        XCTAssertEqual(message.role, .assistant)
    }

    func test_createSystemMessage_setsCorrectRole() {
        let message = ChatMessage(content: "System prompt", role: .system)

        XCTAssertEqual(message.role, .system)
    }

    func test_createMessage_generatesUniqueID() {
        let message1 = ChatMessage(content: "First", role: .user)
        let message2 = ChatMessage(content: "Second", role: .user)

        XCTAssertNotEqual(message1.id, message2.id)
    }

    func test_createMessage_setsCurrentTimestamp() {
        let before = Date()
        let message = ChatMessage(content: "Test", role: .user)
        let after = Date()

        XCTAssertGreaterThanOrEqual(message.timestamp, before)
        XCTAssertLessThanOrEqual(message.timestamp, after)
    }

    // MARK: - Context Injection

    func test_contextInjection_defaultsToFalse() {
        let message = ChatMessage(content: "Test", role: .user)

        XCTAssertFalse(message.isContextInjection)
    }

    func test_contextInjection_canBeSetTrue() {
        let message = ChatMessage(content: "Context", role: .system, isContextInjection: true)

        XCTAssertTrue(message.isContextInjection)
    }

    // MARK: - Persistence

    func test_message_persistsToSwiftData() throws {
        let message = ChatMessage(content: "Persisted", role: .user)
        context.insert(message)
        try context.save()

        let descriptor = FetchDescriptor<ChatMessage>()
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.content, "Persisted")
    }

    func test_messagesOrderedByTimestamp() throws {
        let message1 = ChatMessage(content: "First", role: .user)
        let message2 = ChatMessage(content: "Second", role: .assistant)
        let message3 = ChatMessage(content: "Third", role: .user)

        context.insert(message1)
        context.insert(message2)
        context.insert(message3)
        try context.save()

        var descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 3)
        XCTAssertEqual(fetched[0].content, "First")
        XCTAssertEqual(fetched[2].content, "Third")
    }

    // MARK: - Content

    func test_content_preservesText() {
        let longContent = String(repeating: "a", count: 1000)
        let message = ChatMessage(content: longContent, role: .user)

        XCTAssertEqual(message.content, longContent)
    }
}
