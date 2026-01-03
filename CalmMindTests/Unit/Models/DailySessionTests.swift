import XCTest
import SwiftData
@testable import CalmMind

final class DailySessionTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: DailySession.self, ChatMessage.self, configurations: config)
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Creation

    func test_createSession_forDate() {
        let date = Date()
        let session = DailySession(date: date)

        XCTAssertNotNil(session.date)
    }

    func test_createSession_startsWithEmptyMessages() {
        let session = DailySession(date: Date())

        XCTAssertTrue(session.messages.isEmpty)
    }

    func test_sessionDate_usesCalendarDayNotExactTime() {
        let calendar = Calendar.current
        let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let evening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!

        let session1 = DailySession(date: morning)
        let session2 = DailySession(date: evening)

        // Both should have the same dateKey (calendar day)
        XCTAssertEqual(session1.dateKey, session2.dateKey)
    }

    // MARK: - Uniqueness

    func test_dateKey_formattedCorrectly() {
        let calendar = Calendar.current
        let components = DateComponents(year: 2025, month: 1, day: 15)
        let date = calendar.date(from: components)!

        let session = DailySession(date: date)

        XCTAssertEqual(session.dateKey, "2025-01-15")
    }

    // MARK: - Journal Status

    func test_isJournalGenerated_defaultsFalse() {
        let session = DailySession(date: Date())

        XCTAssertFalse(session.isJournalGenerated)
    }

    func test_canMarkJournalAsGenerated() {
        let session = DailySession(date: Date())

        session.isJournalGenerated = true

        XCTAssertTrue(session.isJournalGenerated)
    }

    // MARK: - Message Association

    func test_addMessage_toSession() throws {
        let session = DailySession(date: Date())
        let message = ChatMessage(content: "Hello", role: .user)

        session.messages.append(message)
        message.session = session

        context.insert(session)
        try context.save()

        XCTAssertEqual(session.messages.count, 1)
        XCTAssertEqual(session.messages.first?.content, "Hello")
    }

    func test_messageCount_returnsCorrectCount() throws {
        let session = DailySession(date: Date())
        session.messages.append(ChatMessage(content: "One", role: .user))
        session.messages.append(ChatMessage(content: "Two", role: .assistant))
        session.messages.append(ChatMessage(content: "Three", role: .user))

        XCTAssertEqual(session.messages.count, 3)
    }

    // MARK: - Persistence

    func test_session_persistsToSwiftData() throws {
        let session = DailySession(date: Date())
        context.insert(session)
        try context.save()

        let descriptor = FetchDescriptor<DailySession>()
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
    }
}
