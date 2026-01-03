import Foundation

/// Result of a journal tool operation
struct JournalToolResult: Sendable {
    let success: Bool
    let journalId: String?
    let error: String?
    let message: String?

    static func success(id: String? = nil, message: String? = nil) -> JournalToolResult {
        JournalToolResult(success: true, journalId: id, error: nil, message: message)
    }

    static func failure(_ error: String) -> JournalToolResult {
        JournalToolResult(success: false, journalId: nil, error: error, message: nil)
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

/// Tools for managing journal entries via AI function calls
final class JournalTools {

    // MARK: - Dependencies

    private let journalRepository: JournalRepository
    private let sessionRepository: SessionRepository

    // MARK: - Initialization

    init(journalRepository: JournalRepository, sessionRepository: SessionRepository) {
        self.journalRepository = journalRepository
        self.sessionRepository = sessionRepository
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

    /// Get journal entry for a specific date
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

    /// List recent journal entries
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
}
