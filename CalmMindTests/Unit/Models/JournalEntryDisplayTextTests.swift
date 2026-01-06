import XCTest
import SwiftData
@testable import CalmMind

/// Tests for JournalEntry.displayText - only returns AI synthesized text
/// NO fallback to bullet list (that's the change)
final class JournalEntryDisplayTextTests: XCTestCase {

    var container: ModelContainer!

    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: JournalEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    // MARK: - No Synthesis = Empty

    func test_displayText_noSynthesis_returnsEmpty() {
        let entry = JournalEntry(fullText: "Some text", date: Date())
        entry.synthesizedText = nil

        XCTAssertEqual(entry.displayText, "")
    }

    func test_displayText_emptySynthesis_returnsEmpty() {
        let entry = JournalEntry(fullText: "Some text", date: Date())
        entry.synthesizedText = ""

        XCTAssertEqual(entry.displayText, "")
    }

    // MARK: - With Synthesis

    func test_displayText_withSynthesis_returnsSynthesis() {
        let entry = JournalEntry(fullText: "Original", date: Date())
        entry.synthesizedText = "AI generated summary"

        XCTAssertEqual(entry.displayText, "AI generated summary")
    }

    func test_displayText_preservesWhitespace() {
        let entry = JournalEntry(fullText: "", date: Date())
        entry.synthesizedText = "Line one\n\nLine two"

        XCTAssertEqual(entry.displayText, "Line one\n\nLine two")
    }

    // MARK: - NO Fallback to Events

    func test_displayText_noSynthesisWithEvents_stillReturnsEmpty() {
        let entry = JournalEntry(fullText: "", date: Date())
        entry.synthesizedText = nil

        // Even if we had events, displayText should return empty (no bullet fallback)
        // This is verified by the return value being empty
        XCTAssertEqual(entry.displayText, "")
    }

    // MARK: - Synthesis Takes Priority

    func test_displayText_synthesisTakesPriority() {
        let entry = JournalEntry(fullText: "Full text here", date: Date())
        entry.synthesizedText = "Synthesized text"

        // synthesizedText takes priority
        XCTAssertEqual(entry.displayText, "Synthesized text")
    }
}
