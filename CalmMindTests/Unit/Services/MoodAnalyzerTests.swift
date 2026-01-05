import XCTest
@testable import CalmMind

/// Tests for MoodAnalyzer - keyword-based sentiment analysis
/// TDD: These tests are written FIRST, implementation follows
final class MoodAnalyzerTests: XCTestCase {

    // MARK: - Positive Text Tests

    func test_analyzeMood_positiveText_returnsHighScore() {
        // Text with multiple positive indicators
        let text = "I feel so happy and grateful today. Life is wonderful!"

        let mood = MoodAnalyzer.analyzeMood(from: text)

        // Baseline 5 + "happy" (+1) + "grateful" (+1) + "wonderful" (+1) = 8
        XCTAssertNotNil(mood)
        XCTAssertGreaterThanOrEqual(mood!, 7)
        XCTAssertLessThanOrEqual(mood!, 10)
    }

    func test_analyzeMood_veryPositiveText_clampedAt10() {
        // Many positive words should clamp at 10
        let text = "I'm so happy, grateful, wonderful, excited, proud, hopeful, peaceful, calm, blessed, and content!"

        let mood = MoodAnalyzer.analyzeMood(from: text)

        XCTAssertNotNil(mood)
        XCTAssertEqual(mood!, 10)  // Clamped at max
    }

    // MARK: - Negative Text Tests

    func test_analyzeMood_negativeText_returnsLowScore() {
        // Text with multiple negative indicators
        let text = "I feel sad and frustrated. Everything seems hopeless."

        let mood = MoodAnalyzer.analyzeMood(from: text)

        // Baseline 5 + "sad" (-1) + "frustrated" (-1) + "hopeless" (-1) = 2
        XCTAssertNotNil(mood)
        XCTAssertGreaterThanOrEqual(mood!, 1)
        XCTAssertLessThanOrEqual(mood!, 4)
    }

    func test_analyzeMood_veryNegativeText_clampedAt1() {
        // Many negative words should clamp at 1
        let text = "I'm sad, angry, frustrated, anxious, worried, stressed, overwhelmed, tired, exhausted, hurt, lonely, scared, afraid, depressed, and hopeless."

        let mood = MoodAnalyzer.analyzeMood(from: text)

        XCTAssertNotNil(mood)
        XCTAssertEqual(mood!, 1)  // Clamped at min
    }

    // MARK: - Neutral Text Tests

    func test_analyzeMood_neutralText_returnsMidScore() {
        // Text with no sentiment indicators
        let text = "Today I went to the store and bought groceries."

        let mood = MoodAnalyzer.analyzeMood(from: text)

        // Should return baseline (5) or close to it
        XCTAssertNotNil(mood)
        XCTAssertGreaterThanOrEqual(mood!, 4)
        XCTAssertLessThanOrEqual(mood!, 6)
    }

    // MARK: - Empty/Whitespace Text Tests

    func test_analyzeMood_emptyText_returnsNil() {
        let text = ""

        let mood = MoodAnalyzer.analyzeMood(from: text)

        XCTAssertNil(mood)
    }

    func test_analyzeMood_whitespaceOnlyText_returnsNil() {
        let text = "   \n\t   "

        let mood = MoodAnalyzer.analyzeMood(from: text)

        XCTAssertNil(mood)
    }

    // MARK: - Dark Thoughts Capture Tests

    func test_analyzeMood_darkThoughts_capturesLowScore() {
        // Important: dark/difficult content should be captured, not suppressed
        let text = "I feel depressed and scared. Everything feels hopeless today."

        let mood = MoodAnalyzer.analyzeMood(from: text)

        XCTAssertNotNil(mood)
        XCTAssertLessThanOrEqual(mood!, 3)  // Should capture the low mood
    }

    func test_analyzeMood_mixedSentiment_balances() {
        // Text with both positive and negative indicators
        let text = "I was feeling sad earlier but now I feel hopeful and calm."

        let mood = MoodAnalyzer.analyzeMood(from: text)

        // Baseline 5 + "sad" (-1) + "hopeful" (+1) + "calm" (+1) = 6
        XCTAssertNotNil(mood)
        XCTAssertGreaterThanOrEqual(mood!, 5)
        XCTAssertLessThanOrEqual(mood!, 7)
    }

    // MARK: - Case Insensitivity

    func test_analyzeMood_caseInsensitive() {
        let text = "I feel HAPPY and GRATEFUL"

        let mood = MoodAnalyzer.analyzeMood(from: text)

        // Should detect uppercase words
        XCTAssertNotNil(mood)
        XCTAssertGreaterThanOrEqual(mood!, 6)
    }
}
