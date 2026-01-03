import XCTest
import SwiftData
@testable import CalmMind

final class MessageRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var sut: MessageRepository!
    var session: DailySession!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: DailySession.self, ChatMessage.self,
            configurations: config
        )
        context = ModelContext(container)
        sut = MessageRepository(context: context)

        // Create a session for tests
        session = DailySession(date: Date())
        context.insert(session)
        try! context.save()
    }

    override func tearDown() {
        sut = nil
        session = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Save

    func test_saveMessage_persistsToStore() throws {
        let message = ChatMessage(content: "Hello", role: .user)

        try sut.save(message, to: session)

        XCTAssertEqual(session.messages.count, 1)
        XCTAssertEqual(session.messages.first?.content, "Hello")
    }

    func test_saveMessage_isAtomic() throws {
        // Message should be fully saved or not at all
        let message = ChatMessage(content: "Test", role: .user)

        try sut.save(message, to: session)

        let descriptor = FetchDescriptor<ChatMessage>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
    }

    // MARK: - Fetch

    func test_fetchMessagesForSession_returnsOrdered() throws {
        let msg1 = ChatMessage(content: "First", role: .user)
        let msg2 = ChatMessage(content: "Second", role: .assistant)
        let msg3 = ChatMessage(content: "Third", role: .user)

        try sut.save(msg1, to: session)
        try sut.save(msg2, to: session)
        try sut.save(msg3, to: session)

        let messages = try sut.fetchMessages(for: session)

        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0].content, "First")
        XCTAssertEqual(messages[2].content, "Third")
    }

    // MARK: - Delete

    func test_deleteMessage_removesFromStore() throws {
        let message = ChatMessage(content: "Delete me", role: .user)
        try sut.save(message, to: session)

        try sut.delete(message)

        let messages = try sut.fetchMessages(for: session)
        XCTAssertEqual(messages.count, 0)
    }

    // MARK: - Count

    func test_countMessages_forSession() throws {
        try sut.save(ChatMessage(content: "1", role: .user), to: session)
        try sut.save(ChatMessage(content: "2", role: .assistant), to: session)
        try sut.save(ChatMessage(content: "3", role: .user), to: session)

        let count = try sut.countMessages(for: session)

        XCTAssertEqual(count, 3)
    }

    // MARK: - Recent Messages

    func test_fetchRecentMessages_limitsCount() throws {
        for i in 1...10 {
            try sut.save(ChatMessage(content: "Message \(i)", role: .user), to: session)
        }

        let recent = try sut.fetchRecentMessages(for: session, limit: 5)

        XCTAssertEqual(recent.count, 5)
        // Should be most recent messages
        XCTAssertEqual(recent.last?.content, "Message 10")
    }
}
