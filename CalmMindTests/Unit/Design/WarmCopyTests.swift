import XCTest
@testable import CalmMind

/// Tests for WarmCopy constants
/// Verifies tone (no harsh words) and specific values
final class WarmCopyTests: XCTestCase {

    // MARK: - All Copy Strings for Testing

    private var allCopyStrings: [String] {
        [
            WarmCopy.emptyTodosHome,
            WarmCopy.emptyTodosTab,
            WarmCopy.noJournalEntries,
            WarmCopy.promptFallback,
            WarmCopy.offlineError,
            WarmCopy.todosCardTitle,
            WarmCopy.todosCardSubtitle,
            WarmCopy.promptCardTitle,
            WarmCopy.dateHeaderHint,
            WarmCopy.viewAllTodos,
            WarmCopy.addTask
        ]
    }

    // MARK: - Forbidden Words (Never Contains)

    func test_allCopy_neverContains_error() {
        for copy in allCopyStrings {
            XCTAssertFalse(
                copy.lowercased().contains("error"),
                "Copy should not contain 'error': \(copy)"
            )
        }
    }

    func test_allCopy_neverContains_failed() {
        for copy in allCopyStrings {
            XCTAssertFalse(
                copy.lowercased().contains("failed"),
                "Copy should not contain 'failed': \(copy)"
            )
        }
    }

    func test_allCopy_neverContains_cannot() {
        for copy in allCopyStrings {
            XCTAssertFalse(
                copy.lowercased().contains("cannot"),
                "Copy should not contain 'cannot': \(copy)"
            )
        }
    }

    func test_allCopy_neverContains_overdue() {
        for copy in allCopyStrings {
            XCTAssertFalse(
                copy.lowercased().contains("overdue"),
                "Copy should not contain 'overdue': \(copy)"
            )
        }
    }

    func test_allCopy_neverContains_incomplete() {
        for copy in allCopyStrings {
            XCTAssertFalse(
                copy.lowercased().contains("incomplete"),
                "Copy should not contain 'incomplete': \(copy)"
            )
        }
    }

    // MARK: - Prompt Constraints

    func test_promptFallback_maxTwoSentences() {
        let sentences = WarmCopy.promptFallback.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        XCTAssertLessThanOrEqual(sentences.count, 2, "Prompt fallback should have max 2 sentences")
    }

    func test_promptFallback_endsWithQuestionMark() {
        XCTAssertTrue(
            WarmCopy.promptFallback.hasSuffix("?"),
            "Prompt fallback should end with a question mark"
        )
    }

    // MARK: - Specific Values

    func test_todosCardTitle_equals_todaysFocus() {
        XCTAssertEqual(WarmCopy.todosCardTitle, "Today's Focus")
    }

    func test_promptCardTitle_equals_gentleCheckIn() {
        XCTAssertEqual(WarmCopy.promptCardTitle, "A gentle check-in")
    }

    func test_emptyTodosHome_invitational() {
        // Should invite, not scold
        let copy = WarmCopy.emptyTodosHome.lowercased()
        XCTAssertTrue(
            copy.contains("want") || copy.contains("add") || copy.contains("nothing"),
            "Empty todos home should be invitational"
        )
    }

    func test_noJournalEntries_invitational() {
        // Should guide, not complain
        let copy = WarmCopy.noJournalEntries.lowercased()
        XCTAssertTrue(
            copy.contains("tap") || copy.contains("start") || copy.contains("yet"),
            "No journal entries should guide the user"
        )
    }

    func test_offlineError_noTechnicalJargon() {
        let copy = WarmCopy.offlineError.lowercased()
        XCTAssertFalse(copy.contains("network"), "Should not mention network")
        XCTAssertFalse(copy.contains("connection"), "Should not mention connection")
        XCTAssertFalse(copy.contains("server"), "Should not mention server")
        XCTAssertFalse(copy.contains("internet"), "Should not mention internet")
    }
}
