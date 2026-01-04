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

    /// Creates a new journal entry with simplified parameters
    @discardableResult
    func createEntry(date: Date, text: String) -> JournalEntry? {
        let entry = JournalEntry(fullText: text, date: date)
        context.insert(entry)
        do {
            try context.save()
            return entry
        } catch {
            return nil
        }
    }

    /// Gets or creates today's journal entry
    func createOrFetchToday() -> JournalEntry? {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = fetchEntry(for: today) {
            return existing
        }
        return createEntry(date: today, text: "")
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

    /// Fetches an entry for a specific date (throwing)
    func fetchEntryThrowing(for date: Date) throws -> JournalEntry? {
        let dateKey = JournalEntry.formatDateKey(date)
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )
        return try context.fetch(descriptor).first
    }

    /// Fetches an entry for a specific date (non-throwing)
    func fetchEntry(for date: Date) -> JournalEntry? {
        try? fetchEntryThrowing(for: date)
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
