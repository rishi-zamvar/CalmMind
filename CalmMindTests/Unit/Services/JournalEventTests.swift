import XCTest
import SwiftData
@testable import CalmMind

final class JournalEventTests: XCTestCase {

    // MARK: - Initialization

    func test_init_setsUserText() {
        let event = JournalEvent(userText: "Hello world")

        XCTAssertEqual(event.userText, "Hello world")
    }

    func test_init_setsDateToStartOfDay() {
        let now = Date()
        let event = JournalEvent(userText: "Test", date: now)

        let expectedDate = Calendar.current.startOfDay(for: now)
        XCTAssertEqual(event.date, expectedDate)
    }

    func test_init_setsTimestamp() {
        let now = Date()
        let event = JournalEvent(userText: "Test", date: now)

        XCTAssertEqual(event.timestamp, now)
    }

    func test_init_setsIncludeInSynthesisTrue() {
        let event = JournalEvent(userText: "Test")

        XCTAssertTrue(event.includeInSynthesis)
    }

    func test_init_generatesUniqueID() {
        let event1 = JournalEvent(userText: "Test 1")
        let event2 = JournalEvent(userText: "Test 2")

        XCTAssertNotEqual(event1.id, event2.id)
    }

    // MARK: - Text Truncation (2KB Cap)

    func test_init_truncatesLongText() {
        let longText = String(repeating: "a", count: 3000)
        let event = JournalEvent(userText: longText)

        XCTAssertEqual(event.userText.count, JournalEvent.maxUserTextLength)
    }

    func test_init_preservesShortText() {
        let shortText = "Short message"
        let event = JournalEvent(userText: shortText)

        XCTAssertEqual(event.userText, shortText)
    }

    func test_init_preservesExactlyMaxLengthText() {
        let exactText = String(repeating: "b", count: JournalEvent.maxUserTextLength)
        let event = JournalEvent(userText: exactText)

        XCTAssertEqual(event.userText.count, JournalEvent.maxUserTextLength)
    }

    func test_wasTruncated_returnsTrueForTruncatedText() {
        let longText = String(repeating: "c", count: 3000)
        let event = JournalEvent(userText: longText)

        XCTAssertTrue(event.wasTruncated)
    }

    func test_wasTruncated_returnsFalseForShortText() {
        let event = JournalEvent(userText: "Short")

        XCTAssertFalse(event.wasTruncated)
    }

    // MARK: - Constants

    func test_maxUserTextLength_is2000() {
        XCTAssertEqual(JournalEvent.maxUserTextLength, 2000)
    }
}
