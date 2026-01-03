import Foundation

// MARK: - Errors

enum JournalToolError: Error, LocalizedError {
    case contentEmpty
    case contentTooLarge(limit: Int)
    case repositoryError(underlying: Error)
    case excerptNotInMessage(excerpt: String)

    var errorDescription: String? {
        switch self {
        case .contentEmpty:
            return "Journal content cannot be empty"
        case .contentTooLarge(let limit):
            return "Journal content exceeds maximum size of \(limit) bytes"
        case .repositoryError(let error):
            return "Journal save failed: \(error.localizedDescription)"
        case .excerptNotInMessage(let excerpt):
            return "Excerpt '\(excerpt)' not found in user message"
        }
    }
}

// MARK: - Results

/// Result of a journal tool operation
struct JournalToolResult: Sendable {
    let success: Bool
    let journalId: String?
    let error: String?
    let message: String?
    let wasAppended: Bool

    static func success(id: String? = nil, message: String? = nil, wasAppended: Bool = false) -> JournalToolResult {
        JournalToolResult(success: true, journalId: id, error: nil, message: message, wasAppended: wasAppended)
    }

    static func failure(_ error: String) -> JournalToolResult {
        JournalToolResult(success: false, journalId: nil, error: error, message: nil, wasAppended: false)
    }
}

/// Summary of a journal entry for tool responses
struct JournalSummary: Sendable {
    let id: String
    let entryDate: Date
    let summary: String?
    let moodScore: Int?
    let hasFullText: Bool
}

// MARK: - Validation

/// Validates journal content against user message
/// V1 Decision: Verbatim-only journaling - excerpts must be substrings
struct JournalContentValidator {
    /// SINGLE NORMALIZATION FUNCTION - documented and conservative
    /// Only normalizes whitespace and Unicode, NOT punctuation
    ///
    /// CONSERVATIVE NORMALIZATION ONLY:
    /// - Case folding (lowercased)
    /// - Unicode normalization (NFC)
    /// - Whitespace collapse (multiple spaces -> single space)
    /// - NO punctuation changes
    /// - NO word reordering
    /// - NO synonym replacement
    /// - NO entity inference
    static func normalizeForComparison(_ text: String) -> String {
        text
            .lowercased()
            .precomposedStringWithCanonicalMapping  // Unicode normalization (NFC)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")  // Collapse whitespace to single space
    }

    /// Validate that all excerpts appear in the user message
    /// - Parameters:
    ///   - excerpts: Verbatim quotes from user message
    ///   - userMessage: The original user message
    /// - Throws: JournalToolError.excerptNotInMessage if validation fails
    static func validate(excerpts: [String], userMessage: String) throws {
        let normalizedMessage = normalizeForComparison(userMessage)

        for excerpt in excerpts {
            let normalizedExcerpt = normalizeForComparison(excerpt)

            // STRICT: normalized excerpt must be substring of normalized message
            guard normalizedMessage.contains(normalizedExcerpt) else {
                throw JournalToolError.excerptNotInMessage(excerpt: excerpt)
            }
        }
    }
}

// MARK: - JournalTools

/// Tools for managing journal entries via AI function calls
/// INVARIANT: This class ONLY writes to today. There is no date parameter.
/// Past journals are read-only by design - no API exists to write to them.
final class JournalTools {

    // MARK: - Constants

    /// Maximum content size to prevent runaway writes (~10KB per write)
    private static let maxContentSizeBytes = 10_000

    // MARK: - Dependencies

    private let journalRepository: JournalRepository
    private let sessionRepository: SessionRepository
    private let clock: any DateClock

    // MARK: - Initialization

    init(
        journalRepository: JournalRepository,
        sessionRepository: SessionRepository,
        clock: any DateClock = SystemClock()
    ) {
        self.journalRepository = journalRepository
        self.sessionRepository = sessionRepository
        self.clock = clock
    }

    // MARK: - Write to Today's Journal

    /// Write to today's journal ONLY. This is enforced at the code level.
    /// - Parameters:
    ///   - content: The content to write (from user's first-person perspective)
    ///   - append: If true (default), append to existing. If false, replace.
    /// - Returns: JournalToolResult with success/failure info
    func writeToTodaysJournal(content: String, append: Bool = true) throws -> JournalToolResult {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate content is not empty
        guard !trimmedContent.isEmpty else {
            throw JournalToolError.contentEmpty
        }

        // Validate content size
        guard trimmedContent.utf8.count <= Self.maxContentSizeBytes else {
            throw JournalToolError.contentTooLarge(limit: Self.maxContentSizeBytes)
        }

        // Use clock for today's date (testable)
        let today = clock.now

        do {
            // Get or create today's entry
            let entry: JournalEntry
            if let existing = try journalRepository.fetchEntry(for: today) {
                entry = existing
            } else {
                entry = try journalRepository.createEntry(fullText: "", for: today)
            }

            // Build new text
            let existingText = entry.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            let newText: String
            let wasAppended: Bool

            if append && !existingText.isEmpty {
                newText = existingText + "\n\n" + trimmedContent
                wasAppended = true
            } else {
                newText = trimmedContent
                wasAppended = false
            }

            try journalRepository.update(entry, fullText: newText)

            return JournalToolResult.success(
                id: entry.id.uuidString,
                message: wasAppended ? "Added to today's journal" : "Started today's journal",
                wasAppended: wasAppended
            )
        } catch let error as JournalToolError {
            throw error
        } catch {
            throw JournalToolError.repositoryError(underlying: error)
        }
    }

    /// Write validated excerpts to today's journal
    /// - Parameters:
    ///   - excerpts: Verbatim quotes from user message
    ///   - userMessage: The original user message (for validation)
    ///   - append: If true (default), append to existing. If false, replace.
    /// - Returns: JournalToolResult with success/failure info
    func writeValidatedExcerpts(excerpts: [String], userMessage: String, append: Bool = true) throws -> JournalToolResult {
        // Validate excerpts are from user message
        try JournalContentValidator.validate(excerpts: excerpts, userMessage: userMessage)

        // Build content from excerpts
        let content = excerpts.joined(separator: "\n\n")

        return try writeToTodaysJournal(content: content, append: append)
    }

    // MARK: - Create Draft

    /// Create a draft journal entry for a session
    func createDraft(for sessionId: UUID) throws -> JournalToolResult {
        // Verify session exists
        guard let session = try sessionRepository.fetchSession(for: sessionId) else {
            return .failure("Session not found")
        }

        // Check if entry already exists for this date
        if let existing = try journalRepository.fetchEntry(for: session.date) {
            return .success(id: existing.id.uuidString, message: "Entry already exists for this date")
        }

        // Create new entry
        let entry = try journalRepository.createEntry(
            fullText: "",  // Draft starts empty
            for: session.date
        )

        return .success(id: entry.id.uuidString, message: "Created journal draft")
    }

    // MARK: - Update Entry

    /// Update a journal entry's text
    func updateEntry(id: UUID, text: String) throws -> JournalToolResult {
        // Find the entry
        let entries = try journalRepository.fetchAllEntries()
        guard let entry = entries.first(where: { $0.id == id }) else {
            return .failure("Journal entry not found")
        }

        // Update the text
        try journalRepository.update(entry, fullText: text)

        return .success(id: id.uuidString, message: "Updated journal entry")
    }

    // MARK: - Get Entry

    /// Get journal entry for a specific date (read-only access to past dates)
    func getEntry(for date: Date) throws -> JournalSummary? {
        guard let entry = try journalRepository.fetchEntry(for: date) else {
            return nil
        }

        return JournalSummary(
            id: entry.id.uuidString,
            entryDate: entry.entryDate,
            summary: entry.summary,
            moodScore: entry.moodScore,
            hasFullText: !entry.fullText.isEmpty
        )
    }

    // MARK: - List Recent

    /// List recent journal entries (read-only)
    func listRecent(limit: Int = 7) throws -> [JournalSummary] {
        let entries = try journalRepository.fetchAllEntries()
        let limited = Array(entries.prefix(limit))

        return limited.map { entry in
            JournalSummary(
                id: entry.id.uuidString,
                entryDate: entry.entryDate,
                summary: entry.summary,
                moodScore: entry.moodScore,
                hasFullText: !entry.fullText.isEmpty
            )
        }
    }

    // MARK: - Helpers

    /// Check if a date is today (using injected clock)
    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: clock.now)
    }
}
