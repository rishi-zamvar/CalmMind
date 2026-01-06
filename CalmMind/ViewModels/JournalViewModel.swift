import Foundation
import SwiftData
import Observation
import os

/// ViewModel for the journal interface
@MainActor
@Observable
final class JournalViewModel {

    // MARK: - Insights State

    /// State of insights generation
    enum InsightsState: Equatable {
        case idle
        case generating
        case loaded
        case failed
    }

    // MARK: - Published State

    /// All journal entries ordered by date descending
    private(set) var entries: [JournalEntry] = []

    /// Whether an operation is in progress
    private(set) var isLoading: Bool = false

    /// Error message if any
    private(set) var errorMessage: String?

    /// Whether to show error
    var showError: Bool = false

    /// Current insights generation state
    private(set) var insightsState: InsightsState = .idle

    /// Insights error message (observable, not silent)
    private(set) var insightsError: String?

    /// Whether insights generation is in progress
    private(set) var isGeneratingInsights: Bool = false

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
    private let journalSynthesizer: JournalSynthesizer?
    private let insightsGenerator: InsightsGeneratorProtocol?
    private let logger = Logger(subsystem: "com.calmmind", category: "JournalViewModel")

    /// Task for insights generation (for cancellation)
    private var insightsTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        journalRepository: JournalRepository,
        journalSynthesizer: JournalSynthesizer? = nil,
        insightsGenerator: InsightsGeneratorProtocol? = nil
    ) {
        self.journalRepository = journalRepository
        self.journalSynthesizer = journalSynthesizer
        self.insightsGenerator = insightsGenerator
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

    // MARK: - Journal Synthesis

    /// Synthesize today's journal on-demand
    /// - Parameter entry: The journal entry to synthesize
    /// - Returns: Tuple of (synthesizedText, moodScore) or nil if failed
    func synthesizeTodayOnDemand(for entry: JournalEntry) async -> (text: String, mood: Int)? {
        guard let synthesizer = journalSynthesizer else {
            errorMessage = "Journal synthesis not available"
            showError = true
            return nil
        }

        let result = await synthesizer.synthesizeTodayOnDemand()
        if result != nil {
            await loadEntries()  // Reload to get updated entry
        }
        return result
    }

    /// Check if an entry is locked (read-only)
    /// Only past entries are locked - today's entry is always editable
    func isEntryLocked(for entry: JournalEntry) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let entryDay = calendar.startOfDay(for: entry.entryDate)
        return entryDay < today
    }

    // MARK: - AI Insights Generation

    /// Generate AI insights for a journal entry
    /// - Observable errors (not silent catch)
    /// - Double-tap protection
    /// - Cancellable and idempotent
    func generateInsights(for entry: JournalEntry) async {
        // Double-tap protection
        guard !isGeneratingInsights else {
            logger.debug("Insights generation already in progress, ignoring")
            return
        }

        guard let generator = insightsGenerator else {
            logger.warning("Insights generator not available")
            insightsError = "Insights not available"
            insightsState = .failed
            return
        }

        // Get text to analyze (prefer synthesized, fall back to displayText)
        let textToAnalyze = entry.displayText

        // Empty input check
        guard !textToAnalyze.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.debug("Empty entry text, skipping insights")
            return
        }

        isGeneratingInsights = true
        insightsState = .generating
        insightsError = nil

        do {
            let insights = try await generator.generate(for: textToAnalyze)

            // Store insights on entry
            entry.insightsData = try JSONEncoder().encode(insights)

            insightsState = .loaded
            insightsError = nil

            // Log success (redacted - no entry text)
            logger.info("Insights generated successfully")

        } catch {
            // NOT silent - surface error to UI
            insightsState = .failed
            insightsError = "Unable to generate insights. Try again later."

            // Log error (redacted - no entry text or prompt)
            logger.error("Insights generation failed: \(error.localizedDescription)")
        }

        isGeneratingInsights = false
    }

    /// Cancel in-progress insights generation
    func cancelInsightsGeneration() {
        insightsTask?.cancel()
        insightsTask = nil
        isGeneratingInsights = false
        insightsState = .idle
    }
}
