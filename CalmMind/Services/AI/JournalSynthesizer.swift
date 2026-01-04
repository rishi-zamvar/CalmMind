import Foundation
import os.log

/// Actor responsible for end-of-day journal synthesis
/// - Idempotent via SHA256 digest comparison
/// - Throttled to prevent excessive checks
/// - Thread-safe via actor isolation
actor JournalSynthesizer {

    // MARK: - Configuration

    /// Minimum time between synthesis checks (5 minutes)
    private let checkThrottleInterval: TimeInterval = 60 * 5

    /// Maximum events to include in synthesis
    private let maxEventsCount = 50

    /// Maximum total bytes of event text
    private let maxEventsBytes = 10_000

    /// Maximum synthesized output length
    private let maxSynthesizedLength = 2000

    // MARK: - Dependencies

    private let journalPersistence: any JournalPersistenceProtocol
    private let journalGenerator: any JournalSynthesizerProtocol
    private let calendar: Calendar
    private let logger = Logger(subsystem: "com.calmmind", category: "JournalSynthesizer")

    // MARK: - State

    /// Last time we checked for synthesis (actor-isolated)
    private var lastCheckedAt: Date?

    // MARK: - Initialization

    init(
        journalPersistence: any JournalPersistenceProtocol,
        journalGenerator: any JournalSynthesizerProtocol,
        calendar: Calendar = .current
    ) {
        self.journalPersistence = journalPersistence
        self.journalGenerator = journalGenerator
        self.calendar = calendar
    }

    // MARK: - Public API

    /// Synthesize yesterday's journal if needed
    /// Call this on scenePhase == .active transitions
    /// - Returns: True if synthesis was performed
    @discardableResult
    func synthesizeYesterdayIfNeeded() async -> Bool {
        // Throttle: don't check more than once per checkThrottleInterval
        let now = Date()
        if let lastChecked = lastCheckedAt,
           now.timeIntervalSince(lastChecked) < checkThrottleInterval {
            logger.debug("Synthesis check throttled (last checked \(lastChecked))")
            return false
        }
        lastCheckedAt = now

        // Calculate yesterday's date
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
            logger.error("Failed to calculate yesterday's date")
            return false
        }
        let yesterdayStart = calendar.startOfDay(for: yesterday)

        do {
            // Fetch yesterday's entry
            guard let entry = try await journalPersistence.fetchEntry(for: yesterdayStart) else {
                logger.debug("No journal entry for yesterday")
                return false
            }

            // Get included events only
            let includedEvents = entry.includedEvents
            guard !includedEvents.isEmpty else {
                logger.debug("No included events for synthesis")
                return false
            }

            // Compute current digest (only from included events)
            let currentDigest = await journalPersistence.computeEventsDigest(for: entry)

            // Idempotent: skip if already synthesized with same digest
            if entry.isSynthesized, entry.eventsDigest == currentDigest {
                logger.debug("Entry already synthesized with current digest")
                return false
            }

            // Cap events to prevent excessive synthesis
            let cappedEvents = capEvents(Array(includedEvents))

            logger.info("Synthesizing journal for \(entry.dateKey) with \(cappedEvents.count) events")

            // Generate narrative
            let narrative = try await journalGenerator.synthesizeJournal(from: cappedEvents)

            // Cap output length
            let cappedNarrative = String(narrative.prefix(maxSynthesizedLength))

            // Mark as synthesized (atomic update)
            try await journalPersistence.markSynthesized(
                entryDate: yesterdayStart,
                synthesizedText: cappedNarrative,
                synthesizedAt: now,
                eventsDigest: currentDigest
            )

            logger.info("Successfully synthesized journal for \(entry.dateKey)")
            return true

        } catch {
            logger.error("Journal synthesis failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Reset the throttle for testing
    func resetThrottle() {
        lastCheckedAt = nil
    }

    // MARK: - Private Helpers

    private func capEvents(_ events: [JournalEvent]) -> [JournalEvent] {
        var result: [JournalEvent] = []
        var totalBytes = 0

        // Sort by timestamp to get chronological order
        let sorted = events.sorted { $0.timestamp < $1.timestamp }

        for event in sorted.prefix(maxEventsCount) {
            let eventBytes = event.userText.utf8.count
            if totalBytes + eventBytes > maxEventsBytes {
                break
            }
            result.append(event)
            totalBytes += eventBytes
        }

        return result
    }
}
