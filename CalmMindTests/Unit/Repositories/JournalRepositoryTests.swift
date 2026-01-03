import XCTest
import SwiftData
@testable import CalmMind

final class JournalRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var sut: JournalRepository!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: JournalEntry.self, configurations: config)
        context = ModelContext(container)
        sut = JournalRepository(context: context)
    }

    override func tearDown() {
        sut = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Create

    func test_createEntry_forDate() throws {
        let date = Date()
        let entry = try sut.createEntry(fullText: "Today was great.", for: date)

        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.fullText, "Today was great.")
        XCTAssertEqual(entry.dateKey, JournalEntry.formatDateKey(date))
    }

    // MARK: - Update

    func test_updateEntry_preservesCreatedDate() throws {
        let entry = try sut.createEntry(fullText: "Original", for: Date())
        let originalCreatedAt = entry.createdAt

        try sut.update(entry, fullText: "Updated content")

        XCTAssertEqual(entry.createdAt, originalCreatedAt)
        XCTAssertEqual(entry.fullText, "Updated content")
    }

    func test_updateEntry_setSummary() throws {
        let entry = try sut.createEntry(fullText: "Full text here", for: Date())

        try sut.update(entry, summary: "Brief summary")

        XCTAssertEqual(entry.summary, "Brief summary")
        XCTAssertEqual(entry.fullText, "Full text here")
    }

    func test_updateEntry_setMoodScore() throws {
        let entry = try sut.createEntry(fullText: "Test", for: Date())

        try sut.update(entry, moodScore: 7)

        XCTAssertEqual(entry.moodScore, 7)
    }

    // MARK: - Fetch

    func test_fetchAllEntries_orderedByDateDesc() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let _ = try sut.createEntry(fullText: "Two days ago", for: twoDaysAgo)
        let _ = try sut.createEntry(fullText: "Today", for: today)
        let _ = try sut.createEntry(fullText: "Yesterday", for: yesterday)

        let entries = try sut.fetchAllEntries()

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].fullText, "Today")
        XCTAssertEqual(entries[2].fullText, "Two days ago")
    }

    func test_fetchEntry_forSpecificDate() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let _ = try sut.createEntry(fullText: "Today entry", for: today)
        let _ = try sut.createEntry(fullText: "Yesterday entry", for: yesterday)

        let entry = try sut.fetchEntry(for: yesterday)

        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.fullText, "Yesterday entry")
    }

    func test_fetchEntry_returnsNilForMissingDate() throws {
        let calendar = Calendar.current
        let today = Date()
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!

        let _ = try sut.createEntry(fullText: "Today", for: today)

        let entry = try sut.fetchEntry(for: lastWeek)

        XCTAssertNil(entry)
    }

    // MARK: - Delete

    func test_deleteEntry_removesFromStore() throws {
        let entry = try sut.createEntry(fullText: "Delete me", for: Date())

        try sut.delete(entry)

        let entries = try sut.fetchAllEntries()
        XCTAssertEqual(entries.count, 0)
    }

    // MARK: - Entries Needing Summary

    func test_fetchEntriesNeedingSummary() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let entry1 = try sut.createEntry(fullText: "No summary 1", for: today)
        let entry2 = try sut.createEntry(fullText: "Has summary", for: yesterday)
        let entry3 = try sut.createEntry(fullText: "No summary 2", for: twoDaysAgo)

        try sut.update(entry2, summary: "Brief")

        let needingSummary = try sut.fetchEntriesNeedingSummary()

        XCTAssertEqual(needingSummary.count, 2)
        XCTAssertTrue(needingSummary.contains { $0.id == entry1.id })
        XCTAssertTrue(needingSummary.contains { $0.id == entry3.id })
    }
}
