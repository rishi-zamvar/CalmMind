import Foundation
import SwiftData

/// A journal entry for a specific day
@Model
final class JournalEntry: Identifiable {

    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique)
    var id: UUID

    /// The full journal text (stays on device) - legacy field for manual entries
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

    // MARK: - Auto-Journaling Properties

    /// Raw conversation events captured during the day (NEVER deleted/overwritten)
    @Relationship(deleteRule: .cascade)
    var events: [JournalEvent] = []

    /// LLM-generated narrative from events (kept separate from raw events)
    var synthesizedText: String?

    /// When synthesis was performed
    var synthesizedAt: Date?

    /// SHA256 hash of included events for idempotency
    var eventsDigest: String?

    /// Whether end-of-day synthesis has been completed
    var isSynthesized: Bool = false

    // MARK: - AI Insights Properties

    /// Encoded JournalInsights JSON (stored for persistence)
    var insightsData: Data?

    /// Decoded insights (computed from insightsData)
    var insights: JournalInsights? {
        guard let data = insightsData else { return nil }
        return try? JSONDecoder().decode(JournalInsights.self, from: data)
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        fullText: String = "",
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

    /// Events that should be included in synthesis
    var includedEvents: [JournalEvent] {
        events.filter { $0.includeInSynthesis }
    }

    /// Display text - ONLY returns AI synthesized text
    /// No fallback to bullet list (removed as per journal improvements)
    var displayText: String {
        guard let synthesized = synthesizedText, !synthesized.isEmpty else {
            return ""
        }
        return synthesized
    }
}
