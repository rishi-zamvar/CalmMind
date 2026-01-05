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
    private let services: ServiceContainer?
    private let fallbackCalendar: Calendar
    private let logger = Logger(subsystem: "com.calmmind", category: "JournalSynthesizer")

    // MARK: - State

    /// Last time we checked for synthesis (actor-isolated)
    private var lastCheckedAt: Date?

    // MARK: - Initialization

    /// Initialize with ServiceContainer (preferred for timezone handling)
    init(
        journalPersistence: any JournalPersistenceProtocol,
        journalGenerator: any JournalSynthesizerProtocol,
        services: ServiceContainer
    ) {
        self.journalPersistence = journalPersistence
        self.journalGenerator = journalGenerator
        self.services = services
        self.fallbackCalendar = services.calendar
    }

    /// Backwards-compatible initializer without ServiceContainer
    init(
        journalPersistence: any JournalPersistenceProtocol,
        journalGenerator: any JournalSynthesizerProtocol,
        calendar: Calendar = .current
    ) {
        self.journalPersistence = journalPersistence
        self.journalGenerator = journalGenerator
        self.services = nil
        self.fallbackCalendar = calendar
    }

    // MARK: - Private Helpers

    /// Get timezone-aware calendar (from services or fallback)
    private var calendar: Calendar {
        services?.calendar ?? fallbackCalendar
    }

    /// Get yesterday's start using timezone-aware calendar
    private func yesterdayStart() async -> Date {
        if let services = services {
            // Use ServiceContainer's timezone-aware method (MainActor)
            return await MainActor.run {
                services.yesterdayStart()
            }
        } else {
            // Fallback to local calendar
            let now = Date()
            guard let yesterday = fallbackCalendar.date(byAdding: .day, value: -1, to: now) else {
                return fallbackCalendar.startOfDay(for: now)
            }
            return fallbackCalendar.startOfDay(for: yesterday)
        }
    }

    /// Get weather progression for a date (for future use)
    private func getWeatherProgression(for date: Date) async -> WeatherProgression? {
        guard let services = services else { return nil }
        return await MainActor.run {
            services.weatherStore.getProgression(for: date)
        }
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

        // Get yesterday's start using timezone-aware calendar
        let yesterdayStart = await self.yesterdayStart()

        // Get weather progression for yesterday (for future weather-mood correlation)
        _ = await getWeatherProgression(for: yesterdayStart)

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

    // MARK: - On-Demand Synthesis (Today)

    /// Synthesize TODAY's journal on-demand (user initiated)
    /// Unlike synthesizeYesterdayIfNeeded, this:
    /// - Always runs (no throttle for user action)
    /// - Works on today's entry
    /// - Returns synthesized text and mood score
    /// - Parameters:
    ///   - forceResynthesis: If true, regenerate even if already synthesized
    /// - Returns: Tuple of (synthesizedText, moodScore) or nil if no events
    func synthesizeTodayOnDemand(forceResynthesis: Bool = false) async -> (text: String, mood: Int)? {
        let today = calendar.startOfDay(for: Date())

        do {
            guard let entry = try await journalPersistence.fetchEntry(for: today) else {
                logger.debug("No journal entry for today")
                return nil
            }

            let includedEvents = entry.includedEvents
            guard !includedEvents.isEmpty else {
                logger.debug("No events to synthesize for today")
                return nil
            }

            let currentDigest = await journalPersistence.computeEventsDigest(for: entry)

            // Skip if already synthesized with same digest (unless forced)
            if !forceResynthesis && entry.isSynthesized && entry.eventsDigest == currentDigest {
                if let existing = entry.synthesizedText {
                    let mood = entry.moodScore ?? MoodAnalyzer.analyzeMood(from: existing) ?? 5
                    return (existing, mood)
                }
            }

            let cappedEvents = capEvents(Array(includedEvents))
            logger.info("Synthesizing today's journal with \(cappedEvents.count) events")

            let narrative = try await journalGenerator.synthesizeJournal(from: cappedEvents)
            let cappedNarrative = String(narrative.prefix(maxSynthesizedLength))

            // Auto-detect mood from synthesized text
            let mood = MoodAnalyzer.analyzeMood(from: cappedNarrative) ?? 5

            try await journalPersistence.markSynthesized(
                entryDate: today,
                synthesizedText: cappedNarrative,
                synthesizedAt: Date(),
                eventsDigest: currentDigest
            )

            // Also set mood score
            try await journalPersistence.updateMoodScore(for: today, score: mood)

            logger.info("Successfully synthesized today's journal, mood: \(mood)")
            return (cappedNarrative, mood)
        } catch {
            logger.error("Today synthesis failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Check if entry is locked (read-only)
    /// Only locked if entry is from a PREVIOUS day
    func isEntryLocked(for date: Date) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let entryDay = calendar.startOfDay(for: date)
        return entryDay < today
    }

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
