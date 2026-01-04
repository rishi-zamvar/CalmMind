import XCTest
import SwiftData
@testable import CalmMind

final class JournalSynthesizerTests: XCTestCase {

    // MARK: - Properties

    var sut: JournalSynthesizer!
    var mockPersistence: MockJournalPersistence!
    var mockGenerator: MockJournalSynthesizerProtocol!
    var testCalendar: Calendar!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        testCalendar = Calendar.current
        mockPersistence = MockJournalPersistence()
        mockGenerator = MockJournalSynthesizerProtocol()
        sut = JournalSynthesizer(
            journalPersistence: mockPersistence,
            journalGenerator: mockGenerator,
            calendar: testCalendar
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockPersistence = nil
        mockGenerator = nil
        try await super.tearDown()
    }

    // MARK: - Throttle Tests

    func test_synthesizeYesterdayIfNeeded_throttlesRepeatedCalls() async {
        // First call should proceed
        _ = await sut.synthesizeYesterdayIfNeeded()

        // Second call within throttle window should be skipped
        let secondResult = await sut.synthesizeYesterdayIfNeeded()

        // Second should be throttled (return false)
        XCTAssertFalse(secondResult)
    }

    func test_resetThrottle_allowsImmediateCall() async {
        // Setup: mock returns an entry
        let entry = makeEntry(isSynthesized: false)
        entry.events = [JournalEvent(userText: "Test event")]
        await mockPersistence.setEntry(entry)
        await mockGenerator.setResult("Test narrative")

        // First call
        _ = await sut.synthesizeYesterdayIfNeeded()

        // Reset throttle
        await sut.resetThrottle()

        // Should not be throttled after reset
        let callCountBefore = await mockGenerator.synthesizeCallCount
        _ = await sut.synthesizeYesterdayIfNeeded()
        let callCountAfter = await mockGenerator.synthesizeCallCount

        // Second call should have happened (not throttled)
        XCTAssertEqual(callCountAfter, callCountBefore + 1)
    }

    // MARK: - Idempotency Tests

    func test_synthesizeYesterdayIfNeeded_skipsIfAlreadySynthesized() async {
        // Setup: entry already synthesized with matching digest
        let entry = makeEntry(isSynthesized: true, eventsDigest: "abc123")
        await mockPersistence.setEntry(entry)
        await mockPersistence.setDigest("abc123")

        let result = await sut.synthesizeYesterdayIfNeeded()

        let callCount = await mockGenerator.synthesizeCallCount
        XCTAssertFalse(result)
        XCTAssertEqual(callCount, 0)
    }

    func test_synthesizeYesterdayIfNeeded_resynthesizesIfDigestChanged() async {
        // Setup: entry synthesized but digest different (new events added)
        let entry = makeEntry(isSynthesized: true, eventsDigest: "oldDigest")
        entry.events = [JournalEvent(userText: "New event")]
        await mockPersistence.setEntry(entry)
        await mockPersistence.setDigest("newDigest")
        await mockGenerator.setResult("New narrative")

        let result = await sut.synthesizeYesterdayIfNeeded()

        let callCount = await mockGenerator.synthesizeCallCount
        XCTAssertTrue(result)
        XCTAssertEqual(callCount, 1)
    }

    // MARK: - Event Filtering Tests

    func test_synthesizeYesterdayIfNeeded_usesOnlyIncludedEvents() async {
        // Setup: entry with mix of included and excluded events
        let entry = makeEntry(isSynthesized: false)
        let includedEvent = JournalEvent(userText: "Included")
        includedEvent.includeInSynthesis = true

        let excludedEvent = JournalEvent(userText: "Excluded")
        excludedEvent.includeInSynthesis = false

        entry.events = [includedEvent, excludedEvent]
        await mockPersistence.setEntry(entry)
        await mockGenerator.setResult("Narrative")

        _ = await sut.synthesizeYesterdayIfNeeded()

        // Generator should only receive the included event
        let receivedEvents = await mockGenerator.lastReceivedEvents
        XCTAssertEqual(receivedEvents?.count, 1)
        XCTAssertEqual(receivedEvents?.first?.userText, "Included")
    }

    func test_synthesizeYesterdayIfNeeded_skipsIfNoIncludedEvents() async {
        // Setup: entry with only excluded events
        let entry = makeEntry(isSynthesized: false)
        let excludedEvent = JournalEvent(userText: "Excluded")
        excludedEvent.includeInSynthesis = false
        entry.events = [excludedEvent]
        await mockPersistence.setEntry(entry)

        let result = await sut.synthesizeYesterdayIfNeeded()

        let callCount = await mockGenerator.synthesizeCallCount
        XCTAssertFalse(result)
        XCTAssertEqual(callCount, 0)
    }

    // MARK: - Capping Tests

    func test_synthesizeYesterdayIfNeeded_capsAtMaxEvents() async {
        // Setup: entry with more than 50 events
        let entry = makeEntry(isSynthesized: false)
        entry.events = (0..<60).map { JournalEvent(userText: "Event \($0)") }
        await mockPersistence.setEntry(entry)
        await mockGenerator.setResult("Narrative")

        _ = await sut.synthesizeYesterdayIfNeeded()

        // Should be capped at 50
        let receivedEvents = await mockGenerator.lastReceivedEvents
        XCTAssertLessThanOrEqual(receivedEvents?.count ?? 0, 50)
    }

    // MARK: - Helpers

    private func makeEntry(isSynthesized: Bool, eventsDigest: String? = nil) -> JournalEntry {
        let entry = JournalEntry(date: Date())
        entry.isSynthesized = isSynthesized
        entry.eventsDigest = eventsDigest
        return entry
    }
}

// MARK: - Mock Persistence Actor

actor MockJournalPersistence: JournalPersistenceProtocol {
    private var stubbedEntry: JournalEntry?
    private var stubbedDigest: String = ""
    private(set) var markSynthesizedCallCount = 0

    func setEntry(_ entry: JournalEntry?) {
        stubbedEntry = entry
    }

    func setDigest(_ digest: String) {
        stubbedDigest = digest
    }

    func addEvent(_ event: JournalEvent) throws {
        // Not used in these tests
    }

    func excludeEventFromSynthesis(_ eventID: UUID) throws {
        // Not used in these tests
    }

    func fetchEntry(for date: Date) throws -> JournalEntry? {
        return stubbedEntry
    }

    func computeEventsDigest(for entry: JournalEntry) -> String {
        return stubbedDigest
    }

    func markSynthesized(
        entryDate: Date,
        synthesizedText: String,
        synthesizedAt: Date,
        eventsDigest: String
    ) throws {
        markSynthesizedCallCount += 1
    }
}

// MARK: - Mock Journal Generator

actor MockJournalSynthesizerProtocol: JournalSynthesizerProtocol {
    private(set) var synthesizeCallCount = 0
    private(set) var lastReceivedEvents: [JournalEvent]?
    private var stubbedResult: String = ""

    func setResult(_ result: String) {
        stubbedResult = result
    }

    func synthesizeJournal(from events: [JournalEvent]) async throws -> String {
        synthesizeCallCount += 1
        lastReceivedEvents = events
        return stubbedResult
    }
}
