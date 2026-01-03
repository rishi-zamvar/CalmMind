import Foundation
import SwiftData

/// Repository for managing DailySession entities
final class SessionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Get or Create

    /// Gets an existing session for the date or creates a new one
    func getOrCreateSession(for date: Date) throws -> DailySession {
        let dateKey = DailySession.formatDateKey(date)

        if let existing = try fetchSession(for: dateKey) {
            return existing
        }

        let session = DailySession(date: date)
        context.insert(session)
        try context.save()
        return session
    }

    // MARK: - Fetch

    /// Fetches a session by its date key
    func fetchSession(for dateKey: String) throws -> DailySession? {
        let descriptor = FetchDescriptor<DailySession>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )
        return try context.fetch(descriptor).first
    }

    /// Fetches all sessions ordered by date descending (most recent first)
    func fetchAllSessions() throws -> [DailySession] {
        var descriptor = FetchDescriptor<DailySession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = nil
        return try context.fetch(descriptor)
    }

    // MARK: - Update

    /// Marks the session's journal as generated
    func markJournalGenerated(for session: DailySession) throws {
        session.isJournalGenerated = true
        try context.save()
    }
}
