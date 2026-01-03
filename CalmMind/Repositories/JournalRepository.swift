import Foundation
import SwiftData

/// Repository for managing JournalEntry entities
final class JournalRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Create

    /// Creates a new journal entry for the specified date
    @discardableResult
    func createEntry(fullText: String, for date: Date) throws -> JournalEntry {
        let entry = JournalEntry(fullText: fullText, date: date)
        context.insert(entry)
        try context.save()
        return entry
    }

    // MARK: - Update

    /// Updates an existing entry's full text
    func update(_ entry: JournalEntry, fullText: String) throws {
        entry.fullText = fullText
        try context.save()
    }

    /// Updates an existing entry's summary
    func update(_ entry: JournalEntry, summary: String) throws {
        entry.summary = summary
        try context.save()
    }

    /// Updates an existing entry's mood score
    func update(_ entry: JournalEntry, moodScore: Int) throws {
        entry.moodScore = moodScore
        try context.save()
    }

    // MARK: - Fetch

    /// Fetches all entries ordered by date descending (most recent first)
    func fetchAllEntries() throws -> [JournalEntry] {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.entryDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetches an entry for a specific date
    func fetchEntry(for date: Date) throws -> JournalEntry? {
        let dateKey = JournalEntry.formatDateKey(date)
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )
        return try context.fetch(descriptor).first
    }

    /// Fetches entries that don't have a summary yet
    func fetchEntriesNeedingSummary() throws -> [JournalEntry] {
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.summary == nil },
            sortBy: [SortDescriptor(\.entryDate, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Delete

    /// Deletes an entry from the store
    func delete(_ entry: JournalEntry) throws {
        context.delete(entry)
        try context.save()
    }
}
