import Foundation
import SwiftData
import CryptoKit
import os.log

/// Protocol for journal persistence operations (for testability)
protocol JournalPersistenceProtocol: Actor {
    func addEvent(_ event: JournalEvent) throws
    func excludeEventFromSynthesis(_ eventID: UUID) throws
    func fetchEntry(for date: Date) throws -> JournalEntry?
    func markSynthesized(entryDate: Date, synthesizedText: String, synthesizedAt: Date, eventsDigest: String) throws
    func computeEventsDigest(for entry: JournalEntry) -> String
}

/// Thread-safe actor for journal persistence operations
/// Owns its own ModelContext to ensure SwiftData thread safety
actor JournalPersistenceActor: JournalPersistenceProtocol {

    // MARK: - Properties

    private let modelContainer: ModelContainer
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.calmmind", category: "JournalPersistence")

    // MARK: - Initialization

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.context = ModelContext(modelContainer)
    }

    // MARK: - Event Operations

    /// Add a new journal event
    /// - Parameter event: The event to add (userText already truncated at init)
    func addEvent(_ event: JournalEvent) throws {
        let entry = try getOrCreateEntry(for: event.date)
        entry.events.append(event)
        entry.modifiedAt = Date()
        try context.save()
        logger.debug("Added journal event for \(entry.dateKey)")
    }

    /// Exclude an event from synthesis (soft delete)
    /// - Parameter eventID: The event ID to exclude
    func excludeEventFromSynthesis(_ eventID: UUID) throws {
        let descriptor = FetchDescriptor<JournalEvent>(
            predicate: #Predicate { $0.id == eventID }
        )
        if let event = try context.fetch(descriptor).first {
            event.includeInSynthesis = false
            if let entry = event.entry {
                entry.modifiedAt = Date()
            }
            try context.save()
            logger.debug("Excluded event \(eventID) from synthesis")
        }
    }

    // MARK: - Entry Operations

    /// Fetch a journal entry for a specific date
    /// - Parameter date: The date to fetch (will be normalized to start of day)
    /// - Returns: The journal entry if it exists
    func fetchEntry(for date: Date) throws -> JournalEntry? {
        let dateKey = JournalEntry.formatDateKey(date)
        let descriptor = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )
        return try context.fetch(descriptor).first
    }

    /// Mark an entry as synthesized with the generated text
    /// - Parameters:
    ///   - entryDate: The date of the entry
    ///   - synthesizedText: The LLM-generated narrative
    ///   - synthesizedAt: When synthesis occurred
    ///   - eventsDigest: SHA256 hash of included events for idempotency
    func markSynthesized(
        entryDate: Date,
        synthesizedText: String,
        synthesizedAt: Date,
        eventsDigest: String
    ) throws {
        guard let entry = try fetchEntry(for: entryDate) else {
            logger.warning("Cannot mark synthesized: no entry for \(JournalEntry.formatDateKey(entryDate))")
            return
        }

        // Single atomic update
        entry.synthesizedText = synthesizedText
        entry.synthesizedAt = synthesizedAt
        entry.eventsDigest = eventsDigest
        entry.isSynthesized = true
        entry.modifiedAt = Date()

        try context.save()
        logger.info("Marked entry \(entry.dateKey) as synthesized")
    }

    // MARK: - Digest Computation

    /// Compute SHA256 digest of included events for idempotency checking
    /// Only includes events where includeInSynthesis == true
    /// - Parameter entry: The journal entry
    /// - Returns: Hex-encoded SHA256 hash
    func computeEventsDigest(for entry: JournalEntry) -> String {
        let includedEvents = entry.events
            .filter { $0.includeInSynthesis }
            .sorted { $0.timestamp < $1.timestamp }

        // Include userText (already truncated at write time)
        let combined = includedEvents
            .map { $0.userText }
            .joined(separator: "|")

        let hash = SHA256.hash(data: Data(combined.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Private Helpers

    private func getOrCreateEntry(for date: Date) throws -> JournalEntry {
        if let existing = try fetchEntry(for: date) {
            return existing
        }
        let entry = JournalEntry(date: date)
        context.insert(entry)
        return entry
    }
}
