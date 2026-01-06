import XCTest
import SwiftData
@testable import CalmMind

/// Tests for JournalViewModel insights generation
/// - Observable errors (no silent swallowing)
/// - Double-tap protection
/// - Task cancellation lifecycle
@MainActor
final class JournalViewModelInsightsTests: XCTestCase {

    var sut: JournalViewModel!
    var container: ModelContainer!
    var journalRepo: JournalRepository!
    var mockGenerator: MockInsightsGenerator!

    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: JournalEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        journalRepo = JournalRepository(context: container.mainContext)
        mockGenerator = MockInsightsGenerator()
        sut = JournalViewModel(
            journalRepository: journalRepo,
            journalSynthesizer: nil,
            insightsGenerator: mockGenerator
        )
    }

    override func tearDown() {
        sut = nil
        journalRepo = nil
        container = nil
        mockGenerator = nil
        super.tearDown()
    }

    // MARK: - InsightsState Enum

    func test_insightsState_startsIdle() {
        XCTAssertEqual(sut.insightsState, .idle)
    }

    // MARK: - Helper

    /// Create a test entry with synthesized text (so displayText works)
    private func createTestEntry(text: String = "Test entry text") throws -> JournalEntry {
        let entry = try journalRepo.createEntry(fullText: text, for: Date())
        entry.synthesizedText = text  // Set synthesized so displayText returns it
        return entry
    }

    // MARK: - Error State (Not Silent)

    func test_generateInsights_onError_setsFailedState() async throws {
        let entry = try createTestEntry()
        mockGenerator.shouldFail = true
        mockGenerator.failureError = .networkError("Connection failed")

        await sut.generateInsights(for: entry)

        XCTAssertEqual(sut.insightsState, .failed)
    }

    func test_generateInsights_onError_setsErrorMessage() async throws {
        let entry = try createTestEntry()
        mockGenerator.shouldFail = true

        await sut.generateInsights(for: entry)

        XCTAssertNotNil(sut.insightsError)
        XCTAssertFalse(sut.insightsError?.isEmpty ?? true)
    }

    func test_generateInsights_onError_doesNotCrash() async throws {
        let entry = try createTestEntry()
        mockGenerator.shouldFail = true

        // Should not throw or crash
        await sut.generateInsights(for: entry)

        // Verify view is in safe state
        XCTAssertFalse(sut.isGeneratingInsights)
    }

    // MARK: - Success State

    func test_generateInsights_onSuccess_setsLoadedState() async throws {
        let entry = try createTestEntry()

        await sut.generateInsights(for: entry)

        XCTAssertEqual(sut.insightsState, .loaded)
    }

    func test_generateInsights_onSuccess_storesInsightsOnEntry() async throws {
        let entry = try createTestEntry()
        mockGenerator.mockResult = JournalInsights(
            patterns: ["Pattern 1"],
            suggestions: ["Take a walk"],
            inputHash: "test_hash",
            providerModel: "test-model",
            generatedAt: Date()
        )

        await sut.generateInsights(for: entry)

        XCTAssertNotNil(entry.insightsData)
        let decoded = try? JSONDecoder().decode(JournalInsights.self, from: entry.insightsData!)
        XCTAssertEqual(decoded?.patterns.first, "Pattern 1")
    }

    func test_generateInsights_onSuccess_clearsError() async throws {
        let entry = try createTestEntry()

        // First fail, then succeed
        mockGenerator.shouldFail = true
        await sut.generateInsights(for: entry)
        XCTAssertNotNil(sut.insightsError)

        mockGenerator.shouldFail = false
        await sut.generateInsights(for: entry)

        XCTAssertNil(sut.insightsError)
    }

    // MARK: - Generating State

    func test_generateInsights_setsGeneratingState() async throws {
        let entry = try createTestEntry()
        mockGenerator.delaySeconds = 1.0

        // Start generation in background
        let task = Task {
            await sut.generateInsights(for: entry)
        }

        // Wait a tiny bit for state to update
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(sut.insightsState, .generating)

        task.cancel()
    }

    // MARK: - Double-Tap Protection

    func test_generateInsights_whileGenerating_isIgnored() async throws {
        let entry = try createTestEntry()
        mockGenerator.delaySeconds = 0.5

        // Start first request in background
        let task1 = Task {
            await sut.generateInsights(for: entry)
        }

        // Wait for it to start generating
        try await Task.sleep(for: .milliseconds(100))

        // Verify it's generating
        XCTAssertTrue(sut.isGeneratingInsights)

        // Try second request - should be ignored due to double-tap protection
        await sut.generateInsights(for: entry)

        // Wait for first to complete
        await task1.value

        XCTAssertEqual(mockGenerator.callCount, 1, "Second call should be ignored")
    }

    // MARK: - Empty Input Handling

    func test_generateInsights_emptyText_staysIdle() async throws {
        let entry = try journalRepo.createEntry(fullText: "", for: Date())
        entry.synthesizedText = nil  // No synthesis = empty displayText

        await sut.generateInsights(for: entry)

        XCTAssertEqual(sut.insightsState, .idle)
        XCTAssertEqual(mockGenerator.callCount, 0)
    }

    // MARK: - Input Selection

    func test_generateInsights_usesSynthesizedTextIfAvailable() async throws {
        let entry = try journalRepo.createEntry(fullText: "Raw text", for: Date())
        entry.synthesizedText = "Synthesized narrative"

        await sut.generateInsights(for: entry)

        XCTAssertEqual(mockGenerator.lastInput, "Synthesized narrative")
    }

    func test_generateInsights_usesEmptyWhenNoSynthesisAndNoEvents() async throws {
        let entry = try journalRepo.createEntry(fullText: "Raw text only", for: Date())
        entry.synthesizedText = nil
        // No events = empty displayText

        await sut.generateInsights(for: entry)

        // Should not call generator since displayText is empty
        XCTAssertEqual(mockGenerator.callCount, 0)
    }

    // MARK: - Cancellation

    func test_cancelInsightsGeneration_resetsState() async throws {
        let entry = try createTestEntry()
        mockGenerator.delaySeconds = 5.0

        // Start generation in background
        Task {
            await sut.generateInsights(for: entry)
        }

        // Wait for it to start
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(sut.isGeneratingInsights)

        // Cancel
        sut.cancelInsightsGeneration()

        XCTAssertFalse(sut.isGeneratingInsights)
        XCTAssertEqual(sut.insightsState, .idle)
    }
}
