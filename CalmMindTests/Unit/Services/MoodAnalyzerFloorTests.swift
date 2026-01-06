import XCTest
@testable import CalmMind

/// Tests for MoodAnalyzer mood floor enforcement
/// Mood score minimum is 4 (avoid depressing scores)
final class MoodAnalyzerFloorTests: XCTestCase {

    // MARK: - Mood Floor Enforcement

    func test_analyzeMood_veryNegative_floorsAt4() {
        // Text with many negative indicators
        let text = "I am sad, angry, frustrated, anxious, worried, stressed, overwhelmed, tired, exhausted, hurt, lonely, scared, afraid, depressed, hopeless"
        let score = MoodAnalyzer.analyzeMood(from: text)

        // Should floor at 4, not go below
        XCTAssertEqual(score, 4)
    }

    func test_analyzeMood_moderatelyNegative_floorsAt4() {
        let text = "I feel sad and tired and frustrated"
        let score = MoodAnalyzer.analyzeMood(from: text)

        // 5 - 3 = 2, but floors at 4
        XCTAssertGreaterThanOrEqual(score ?? 0, 4)
    }

    func test_analyzeMood_slightlyNegative_isAboveFloor() {
        let text = "I feel a bit sad today"
        let score = MoodAnalyzer.analyzeMood(from: text)

        // 5 - 1 = 4, which is at floor
        XCTAssertEqual(score, 4)
    }

    func test_analyzeMood_neutral_is5() {
        let text = "I went to the store today"
        let score = MoodAnalyzer.analyzeMood(from: text)

        // Neutral text = baseline 5
        XCTAssertEqual(score, 5)
    }

    func test_analyzeMood_positive_noFloorApplied() {
        let text = "I feel happy and grateful today"
        let score = MoodAnalyzer.analyzeMood(from: text)

        // 5 + 2 = 7, no floor needed
        XCTAssertEqual(score, 7)
    }

    func test_analyzeMood_veryPositive_cappedAt10() {
        let text = "I am happy, great, wonderful, excited, grateful, love, joy, amazing, blessed, peaceful, calm, proud, hopeful, relaxed, content"
        let score = MoodAnalyzer.analyzeMood(from: text)

        // Should cap at 10
        XCTAssertEqual(score, 10)
    }

    // MARK: - Floor Value

    func test_moodFloor_is4() {
        // Verify the floor constant is 4
        XCTAssertEqual(MoodAnalyzer.moodFloor, 4)
    }
}
