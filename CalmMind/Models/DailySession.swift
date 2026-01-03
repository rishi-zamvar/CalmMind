import Foundation
import SwiftData

/// A daily chat session containing messages for a specific calendar day
@Model
final class DailySession {

    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique)
    var id: UUID

    /// The calendar day this session represents (stored as start of day)
    var date: Date

    /// Formatted date key for lookups (YYYY-MM-DD)
    @Attribute(.unique)
    var dateKey: String

    /// Messages in this session, ordered by timestamp
    @Relationship(deleteRule: .cascade)
    var messages: [ChatMessage]

    /// Whether a journal entry has been generated for this session
    var isJournalGenerated: Bool

    /// When the session was created
    var createdAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        messages: [ChatMessage] = [],
        isJournalGenerated: Bool = false
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.dateKey = Self.formatDateKey(date)
        self.messages = messages
        self.isJournalGenerated = isJournalGenerated
        self.createdAt = Date()
    }

    // MARK: - Helpers

    /// Format a date as YYYY-MM-DD
    static func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    /// Get the date key for today
    static var todayKey: String {
        formatDateKey(Date())
    }
}
