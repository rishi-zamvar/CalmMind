import Foundation
import SwiftData
import Observation

/// ViewModel for the journal interface
@MainActor
@Observable
final class JournalViewModel {

    // MARK: - Published State

    /// All journal entries ordered by date descending
    private(set) var entries: [JournalEntry] = []

    /// Whether an operation is in progress
    private(set) var isLoading: Bool = false

    /// Error message if any
    private(set) var errorMessage: String?

    /// Whether to show error
    var showError: Bool = false

    // MARK: - Computed Properties

    /// Whether there are any entries
    var hasEntries: Bool {
        !entries.isEmpty
    }

    /// Today's entry if it exists
    var todaysEntry: JournalEntry? {
        let todayKey = JournalEntry.formatDateKey(Date())
        return entries.first { JournalEntry.formatDateKey($0.entryDate) == todayKey }
    }

    /// Whether today has an entry
    var hasTodaysEntry: Bool {
        todaysEntry != nil
    }

    /// Entries grouped by month
    var entriesByMonth: [(month: String, entries: [JournalEntry])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: entries) { entry in
            formatter.string(from: entry.entryDate)
        }

        return grouped
            .sorted { lhs, rhs in
                (entries.first { formatter.string(from: $0.entryDate) == lhs.key }?.entryDate ?? Date()) >
                (entries.first { formatter.string(from: $0.entryDate) == rhs.key }?.entryDate ?? Date())
            }
            .map { (month: $0.key, entries: $0.value) }
    }

    // MARK: - Dependencies

    private let journalRepository: JournalRepository

    // MARK: - Initialization

    init(journalRepository: JournalRepository) {
        self.journalRepository = journalRepository
    }

    // MARK: - Loading

    /// Load all entries from the repository
    func loadEntries() async {
        do {
            entries = try journalRepository.fetchAllEntries()
        } catch {
            errorMessage = "Failed to load entries: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Creating

    /// Create a new entry for today
    func createEntry(text: String) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            return
        }

        do {
            _ = try journalRepository.createEntry(fullText: trimmedText, for: Date())
            await loadEntries()
        } catch {
            errorMessage = "Failed to create entry: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Updating

    /// Update an entry's text
    func updateEntry(_ entry: JournalEntry, text: String) async {
        do {
            try journalRepository.update(entry, fullText: text)
            await loadEntries()
        } catch {
            errorMessage = "Failed to update entry: \(error.localizedDescription)"
            showError = true
        }
    }

    /// Set mood score for an entry
    func setMoodScore(_ entry: JournalEntry, score: Int) async {
        do {
            try journalRepository.update(entry, moodScore: score)
            await loadEntries()
        } catch {
            errorMessage = "Failed to set mood: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Deleting

    /// Delete an entry
    func deleteEntry(_ entry: JournalEntry) async {
        do {
            try journalRepository.delete(entry)
            await loadEntries()
        } catch {
            errorMessage = "Failed to delete entry: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Error Handling

    /// Dismiss the current error
    func dismissError() {
        showError = false
        errorMessage = nil
    }
}
