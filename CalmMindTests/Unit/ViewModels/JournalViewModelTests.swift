import XCTest
import SwiftData
@testable import CalmMind

@MainActor
final class JournalViewModelTests: XCTestCase {

    var sut: JournalViewModel!
    var container: ModelContainer!
    var journalRepo: JournalRepository!

    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: JournalEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        journalRepo = JournalRepository(context: container.mainContext)
        sut = JournalViewModel(journalRepository: journalRepo)
    }

    override func tearDown() {
        sut = nil
        journalRepo = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Loading Entries

    func test_loadEntries_loadsAllEntries() async throws {
        _ = try journalRepo.createEntry(fullText: "Entry 1", for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        _ = try journalRepo.createEntry(fullText: "Entry 2", for: yesterday)

        await sut.loadEntries()

        XCTAssertEqual(sut.entries.count, 2)
    }

    func test_loadEntries_orderedByDateDescending() async throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        _ = try journalRepo.createEntry(fullText: "Yesterday", for: yesterday)
        _ = try journalRepo.createEntry(fullText: "Today", for: Date())

        await sut.loadEntries()

        XCTAssertEqual(sut.entries.first?.fullText, "Today")
        XCTAssertEqual(sut.entries.last?.fullText, "Yesterday")
    }

    // MARK: - Entry for Today

    func test_todaysEntry_existsWhenCreated() async throws {
        _ = try journalRepo.createEntry(fullText: "Today's reflection", for: Date())

        await sut.loadEntries()

        XCTAssertNotNil(sut.todaysEntry)
        XCTAssertEqual(sut.todaysEntry?.fullText, "Today's reflection")
    }

    func test_todaysEntry_nilWhenNotCreated() async throws {
        await sut.loadEntries()

        XCTAssertNil(sut.todaysEntry)
    }

    // MARK: - Creating Entries

    func test_createEntry_createsForToday() async throws {
        await sut.createEntry(text: "New entry")

        let entry = try journalRepo.fetchEntry(for: Date())
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.fullText, "New entry")
    }

    func test_createEntry_updatesEntries() async throws {
        await sut.createEntry(text: "New entry")

        XCTAssertEqual(sut.entries.count, 1)
    }

    func test_createEntry_ignoresEmpty() async throws {
        await sut.createEntry(text: "")

        XCTAssertEqual(sut.entries.count, 0)
    }

    // MARK: - Updating Entries

    func test_updateEntry_updatesText() async throws {
        let entry = try journalRepo.createEntry(fullText: "Original", for: Date())
        await sut.loadEntries()

        await sut.updateEntry(entry, text: "Updated text")

        let updated = try journalRepo.fetchEntry(for: Date())
        XCTAssertEqual(updated?.fullText, "Updated text")
    }

    func test_updateEntry_preservesMoodScore() async throws {
        let entry = try journalRepo.createEntry(fullText: "Original", for: Date())
        try journalRepo.update(entry, moodScore: 7)
        await sut.loadEntries()

        await sut.updateEntry(entry, text: "Updated")

        let updated = try journalRepo.fetchEntry(for: Date())
        XCTAssertEqual(updated?.moodScore, 7)
    }

    // MARK: - Deleting Entries

    func test_deleteEntry_removesFromList() async throws {
        let entry = try journalRepo.createEntry(fullText: "To delete", for: Date())
        await sut.loadEntries()

        await sut.deleteEntry(entry)

        XCTAssertEqual(sut.entries.count, 0)
    }

    func test_deleteEntry_removesFromDatabase() async throws {
        let entry = try journalRepo.createEntry(fullText: "To delete", for: Date())
        await sut.loadEntries()

        await sut.deleteEntry(entry)

        let fetched = try journalRepo.fetchEntry(for: Date())
        XCTAssertNil(fetched)
    }

    // MARK: - Mood Score

    func test_setMoodScore_updatesEntry() async throws {
        let entry = try journalRepo.createEntry(fullText: "Entry", for: Date())
        await sut.loadEntries()

        await sut.setMoodScore(entry, score: 8)

        let updated = try journalRepo.fetchEntry(for: Date())
        XCTAssertEqual(updated?.moodScore, 8)
    }

    // MARK: - Computed Properties

    func test_hasEntries_true() async throws {
        _ = try journalRepo.createEntry(fullText: "Entry", for: Date())
        await sut.loadEntries()

        XCTAssertTrue(sut.hasEntries)
    }

    func test_hasEntries_false() async throws {
        await sut.loadEntries()

        XCTAssertFalse(sut.hasEntries)
    }

    func test_hasTodaysEntry_true() async throws {
        _ = try journalRepo.createEntry(fullText: "Today", for: Date())
        await sut.loadEntries()

        XCTAssertTrue(sut.hasTodaysEntry)
    }

    func test_hasTodaysEntry_false() async throws {
        await sut.loadEntries()

        XCTAssertFalse(sut.hasTodaysEntry)
    }
}
