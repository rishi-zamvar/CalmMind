import Foundation
import SwiftData

/// A single conversation event captured for journaling
/// Stores ONLY verbatim user text - no assistant responses
@Model
final class JournalEvent {

    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique)
    var id: UUID

    /// The calendar day this event belongs to (midnight normalized)
    var date: Date

    /// Exact timestamp when event was captured
    var timestamp: Date

    /// Verbatim user message text (capped at 2KB)
    var userText: String

    /// Whether to include this event in synthesis
    /// User can toggle off via "Remove from journal" undo
    var includeInSynthesis: Bool

    /// Parent journal entry (inverse relationship)
    var entry: JournalEntry?

    // MARK: - Constants

    /// Maximum user text length (2KB)
    static let maxUserTextLength = 2000

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        userText: String,
        date: Date = Date()
    ) {
        self.id = id
        self.timestamp = date
        self.date = Calendar.current.startOfDay(for: date)
        // Truncate if over limit
        self.userText = String(userText.prefix(Self.maxUserTextLength))
        self.includeInSynthesis = true
    }

    // MARK: - Helpers

    /// Check if text was truncated
    var wasTruncated: Bool {
        userText.count == Self.maxUserTextLength
    }
}
