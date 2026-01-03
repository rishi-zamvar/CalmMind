import XCTest
import SwiftData
@testable import CalmMind

final class SessionRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var sut: SessionRepository!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: DailySession.self, ChatMessage.self,
            configurations: config
        )
        context = ModelContext(container)
        sut = SessionRepository(context: context)
    }

    override func tearDown() {
        sut = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Get or Create

    func test_getOrCreateSession_createsIfNotExists() throws {
        let session = try sut.getOrCreateSession(for: Date())

        XCTAssertNotNil(session)
        XCTAssertEqual(session.dateKey, DailySession.todayKey)
    }

    func test_getOrCreateSession_returnsExistingIfExists() throws {
        let first = try sut.getOrCreateSession(for: Date())
        let second = try sut.getOrCreateSession(for: Date())

        XCTAssertEqual(first.id, second.id)
    }

    func test_getCurrentSession_usesLocalTimezone() throws {
        let session = try sut.getOrCreateSession(for: Date())

        // The dateKey should be formatted in local timezone
        let expectedKey = DailySession.formatDateKey(Date())
        XCTAssertEqual(session.dateKey, expectedKey)
    }

    // MARK: - Fetch

    func test_fetchSession_byDateKey() throws {
        let _ = try sut.getOrCreateSession(for: Date())

        let fetched = try sut.fetchSession(for: DailySession.todayKey)

        XCTAssertNotNil(fetched)
    }

    func test_fetchSession_returnsNilForMissingKey() throws {
        let fetched = try sut.fetchSession(for: "2020-01-01")

        XCTAssertNil(fetched)
    }

    // MARK: - Journal Status

    func test_markJournalGenerated_updatesSession() throws {
        let session = try sut.getOrCreateSession(for: Date())
        XCTAssertFalse(session.isJournalGenerated)

        try sut.markJournalGenerated(for: session)

        XCTAssertTrue(session.isJournalGenerated)
    }

    // MARK: - All Sessions

    func test_fetchAllSessions_orderedByDate() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let _ = try sut.getOrCreateSession(for: yesterday)
        let _ = try sut.getOrCreateSession(for: today)
        let _ = try sut.getOrCreateSession(for: twoDaysAgo)

        let sessions = try sut.fetchAllSessions()

        XCTAssertEqual(sessions.count, 3)
        // Should be ordered by date descending (most recent first)
        XCTAssertEqual(sessions[0].dateKey, DailySession.formatDateKey(today))
    }
}
