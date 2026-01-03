import XCTest
import SwiftData
@testable import CalmMind

final class JournalEntryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: JournalEntry.self, configurations: config)
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Creation

    func test_createEntry_withFullText() {
        let entry = JournalEntry(fullText: "Today was a good day.")

        XCTAssertEqual(entry.fullText, "Today was a good day.")
    }

    func test_createEntry_setsCreatedDate() {
        let before = Date()
        let entry = JournalEntry(fullText: "Test")
        let after = Date()

        XCTAssertGreaterThanOrEqual(entry.createdAt, before)
        XCTAssertLessThanOrEqual(entry.createdAt, after)
    }

    func test_createEntry_summaryDefaultsToNil() {
        let entry = JournalEntry(fullText: "Test")

        XCTAssertNil(entry.summary)
    }

    func test_createEntry_moodScoreDefaultsToNil() {
        let entry = JournalEntry(fullText: "Test")

        XCTAssertNil(entry.moodScore)
    }

    // MARK: - Date Key

    func test_dateKey_formattedCorrectly() {
        let calendar = Calendar.current
        let components = DateComponents(year: 2025, month: 3, day: 20)
        let date = calendar.date(from: components)!

        let entry = JournalEntry(fullText: "Test", date: date)

        XCTAssertEqual(entry.dateKey, "2025-03-20")
    }

    // MARK: - Summary

    func test_canSetSummaryText() {
        let entry = JournalEntry(fullText: "Long journal entry text...")

        entry.summary = "Brief summary"

        XCTAssertEqual(entry.summary, "Brief summary")
    }

    func test_fullTextUnchangedWhenSummarySet() {
        let fullText = "This is the full journal entry."
        let entry = JournalEntry(fullText: fullText)

        entry.summary = "Summary"

        XCTAssertEqual(entry.fullText, fullText)
    }

    // MARK: - Mood

    func test_moodScore_acceptsRange1to10() {
        let entry = JournalEntry(fullText: "Test")

        entry.moodScore = 7

        XCTAssertEqual(entry.moodScore, 7)
    }

    func test_moodScore_canBeSetToExtremes() {
        let entry1 = JournalEntry(fullText: "Test")
        let entry2 = JournalEntry(fullText: "Test")

        entry1.moodScore = 1
        entry2.moodScore = 10

        XCTAssertEqual(entry1.moodScore, 1)
        XCTAssertEqual(entry2.moodScore, 10)
    }

    // MARK: - Update

    func test_canUpdateExistingEntry() throws {
        let entry = JournalEntry(fullText: "Original")
        context.insert(entry)
        try context.save()

        entry.fullText = "Updated content"
        try context.save()

        let descriptor = FetchDescriptor<JournalEntry>()
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.first?.fullText, "Updated content")
    }

    // MARK: - Persistence

    func test_entry_persistsToSwiftData() throws {
        let entry = JournalEntry(fullText: "Persisted entry")
        context.insert(entry)
        try context.save()

        let descriptor = FetchDescriptor<JournalEntry>()
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.fullText, "Persisted entry")
    }

    // MARK: - Queries

    func test_fetchEntriesByDateRange() throws {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!

        let entry1 = JournalEntry(fullText: "Today", date: today)
        let entry2 = JournalEntry(fullText: "Yesterday", date: yesterday)
        let entry3 = JournalEntry(fullText: "Last week", date: lastWeek)

        context.insert(entry1)
        context.insert(entry2)
        context.insert(entry3)
        try context.save()

        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.entryDate >= twoDaysAgo }
        )
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 2)
    }
}
