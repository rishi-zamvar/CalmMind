import Foundation
import SwiftData

/// A journal entry for a specific day
@Model
final class JournalEntry {

    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique)
    var id: UUID

    /// The full journal text (stays on device)
    var fullText: String

    /// Short summary for context (can be sent to AI)
    var summary: String?

    /// Mood score from 1-10
    var moodScore: Int?

    /// When the entry was created
    var createdAt: Date

    /// The calendar day this entry is for
    var entryDate: Date

    /// Formatted date key for lookups (YYYY-MM-DD)
    @Attribute(.unique)
    var dateKey: String

    /// When the entry was last modified
    var modifiedAt: Date

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        fullText: String,
        summary: String? = nil,
        moodScore: Int? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.fullText = fullText
        self.summary = summary
        self.moodScore = moodScore
        self.createdAt = Date()
        self.entryDate = Calendar.current.startOfDay(for: date)
        self.dateKey = Self.formatDateKey(date)
        self.modifiedAt = Date()
    }

    // MARK: - Helpers

    /// Format a date as YYYY-MM-DD
    static func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
