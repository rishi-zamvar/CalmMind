import XCTest
import SwiftData
@testable import CalmMind

@MainActor
final class JournalToolsTests: XCTestCase {

    var sut: JournalTools!
    var container: ModelContainer!
    var journalRepo: JournalRepository!
    var sessionRepo: SessionRepository!

    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: JournalEntry.self, DailySession.self, ChatMessage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        journalRepo = JournalRepository(context: container.mainContext)
        sessionRepo = SessionRepository(context: container.mainContext)
        sut = JournalTools(journalRepository: journalRepo, sessionRepository: sessionRepo)
    }

    override func tearDown() {
        sut = nil
        journalRepo = nil
        sessionRepo = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Create Draft

    func test_createDraft_createsEntry() throws {
        // Setup: create a session with messages
        let session = try sessionRepo.getOrCreate(for: Date())

        let result = try sut.createDraft(for: session.id)

        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.journalId)
    }

    func test_createDraft_setsDateFromSession() throws {
        let session = try sessionRepo.getOrCreate(for: Date())
        let result = try sut.createDraft(for: session.id)

        XCTAssertTrue(result.success)

        if let entry = try journalRepo.fetchEntry(for: Date()) {
            // Entry date should match session date
            let calendar = Calendar.current
            XCTAssertTrue(calendar.isDateInToday(entry.entryDate))
        }
    }

    func test_createDraft_returnsErrorForMissingSession() throws {
        let fakeId = UUID()
        let result = try sut.createDraft(for: fakeId)

        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }

    // MARK: - Update Entry

    func test_updateEntry_byId() throws {
        // Setup: create a draft
        let session = try sessionRepo.getOrCreate(for: Date())
        let createResult = try sut.createDraft(for: session.id)

        guard let journalId = createResult.journalId, let uuid = UUID(uuidString: journalId) else {
            XCTFail("Failed to create draft")
            return
        }

        // Update the entry
        let result = try sut.updateEntry(id: uuid, text: "Updated journal text")

        XCTAssertTrue(result.success)

        // Verify the update
        if let entry = try journalRepo.fetchEntry(for: Date()) {
            XCTAssertEqual(entry.fullText, "Updated journal text")
        }
    }

    func test_updateEntry_preservesCreatedDate() throws {
        // Setup
        let session = try sessionRepo.getOrCreate(for: Date())
        let createResult = try sut.createDraft(for: session.id)

        guard let journalId = createResult.journalId, let uuid = UUID(uuidString: journalId),
              let originalEntry = try journalRepo.fetchEntry(for: Date()) else {
            XCTFail("Failed to create draft")
            return
        }

        let originalCreatedAt = originalEntry.createdAt

        // Wait a moment then update
        _ = try sut.updateEntry(id: uuid, text: "Updated text")

        if let updatedEntry = try journalRepo.fetchEntry(for: Date()) {
            XCTAssertEqual(updatedEntry.createdAt, originalCreatedAt)
        }
    }

    func test_updateEntry_returnsErrorForMissingEntry() throws {
        let fakeId = UUID()
        let result = try sut.updateEntry(id: fakeId, text: "Some text")

        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }

    // MARK: - Get Entry

    func test_getEntry_forToday() throws {
        // Setup
        let session = try sessionRepo.getOrCreate(for: Date())
        _ = try sut.createDraft(for: session.id)

        let result = try sut.getEntry(for: Date())

        XCTAssertNotNil(result)
    }

    func test_getEntry_returnsNilIfNotExists() throws {
        let result = try sut.getEntry(for: Date())
        XCTAssertNil(result)
    }
}
