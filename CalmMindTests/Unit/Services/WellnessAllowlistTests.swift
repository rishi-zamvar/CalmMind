import XCTest
@testable import CalmMind

/// Tests for WellnessAllowlist - code-level enforcement of allowed suggestions
/// Prevents off-policy advice from reaching users (not just prompt-based)
final class WellnessAllowlistTests: XCTestCase {

    var sut: WellnessAllowlist!

    override func setUp() {
        super.setUp()
        sut = WellnessAllowlist()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Allowed Suggestions Pass Through

    func test_filter_breathingSuggestion_passesThrough() {
        let suggestions = ["Try 4-7-8 breathing technique"]
        let filtered = sut.filter(suggestions)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertTrue(filtered[0].lowercased().contains("breathing"))
    }

    func test_filter_walkSuggestion_passesThrough() {
        let suggestions = ["Take a 5-minute walk outside"]
        let filtered = sut.filter(suggestions)
        XCTAssertEqual(filtered.count, 1)
    }

    func test_filter_stretchSuggestion_passesThrough() {
        let suggestions = ["Do some gentle stretching"]
        let filtered = sut.filter(suggestions)
        XCTAssertEqual(filtered.count, 1)
    }

    func test_filter_gratitudeSuggestion_passesThrough() {
        let suggestions = ["Practice gratitude by listing three things you're thankful for"]
        let filtered = sut.filter(suggestions)
        XCTAssertEqual(filtered.count, 1)
    }

    func test_filter_meditationSuggestion_passesThrough() {
        let suggestions = ["Try a 5-minute meditation"]
        let filtered = sut.filter(suggestions)
        XCTAssertEqual(filtered.count, 1)
    }

    func test_filter_relaxationSuggestion_passesThrough() {
        let suggestions = ["Progressive muscle relaxation can help"]
        let filtered = sut.filter(suggestions)
        XCTAssertEqual(filtered.count, 1)
    }

    func test_filter_journalSuggestion_passesThrough() {
        let suggestions = ["Write about your feelings in a journal"]
        let filtered = sut.filter(suggestions)
        XCTAssertEqual(filtered.count, 1)
    }

    func test_filter_breakSuggestion_passesThrough() {
        let suggestions = ["Take a short break from work"]
        let filtered = sut.filter(suggestions)
        XCTAssertEqual(filtered.count, 1)
    }

    // MARK: - Disallowed Suggestions Removed

    func test_filter_therapistAdvice_isRemoved() {
        let suggestions = ["You should see a therapist immediately"]
        let filtered = sut.filter(suggestions)
        XCTAssertTrue(filtered.isEmpty)
    }

    func test_filter_doctorAdvice_isRemoved() {
        let suggestions = ["Consider seeing a doctor about this"]
        let filtered = sut.filter(suggestions)
        XCTAssertTrue(filtered.isEmpty)
    }

    func test_filter_medicationAdvice_isRemoved() {
        let suggestions = ["Consider taking medication for anxiety"]
        let filtered = sut.filter(suggestions)
        XCTAssertTrue(filtered.isEmpty)
    }

    func test_filter_psychiatristAdvice_isRemoved() {
        let suggestions = ["A psychiatrist can help with this"]
        let filtered = sut.filter(suggestions)
        XCTAssertTrue(filtered.isEmpty)
    }

    func test_filter_diagnosisAdvice_isRemoved() {
        let suggestions = ["You might have depression, get diagnosed"]
        let filtered = sut.filter(suggestions)
        XCTAssertTrue(filtered.isEmpty)
    }

    func test_filter_emergencyAdvice_isRemoved() {
        let suggestions = ["Call emergency services immediately"]
        let filtered = sut.filter(suggestions)
        XCTAssertTrue(filtered.isEmpty)
    }

    func test_filter_crisisLineAdvice_isRemoved() {
        let suggestions = ["Call the crisis line at 988"]
        let filtered = sut.filter(suggestions)
        XCTAssertTrue(filtered.isEmpty)
    }

    func test_filter_hospitalAdvice_isRemoved() {
        let suggestions = ["Go to the hospital for evaluation"]
        let filtered = sut.filter(suggestions)
        XCTAssertTrue(filtered.isEmpty)
    }

    func test_filter_treatmentAdvice_isRemoved() {
        let suggestions = ["Seek professional treatment for this condition"]
        let filtered = sut.filter(suggestions)
        XCTAssertTrue(filtered.isEmpty)
    }

    // MARK: - Mixed Input

    func test_filter_mixedInput_keepsOnlyAllowed() {
        let suggestions = [
            "Try deep breathing exercises",
            "You should see a doctor",
            "Take a short walk"
        ]
        let filtered = sut.filter(suggestions)

        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.contains("Try deep breathing exercises"))
        XCTAssertTrue(filtered.contains("Take a short walk"))
    }

    func test_filter_allDisallowed_returnsEmpty() {
        let suggestions = [
            "See a therapist",
            "Take medication",
            "Go to the hospital"
        ]
        let filtered = sut.filter(suggestions)

        XCTAssertTrue(filtered.isEmpty)
    }

    // MARK: - Max Output Cap

    func test_filter_output_cappedAtMax() {
        let suggestions = [
            "Breathing exercise",
            "Walking outside",
            "Stretching gently",
            "Meditation practice",
            "Gratitude reflection"
        ]
        let filtered = sut.filter(suggestions)

        XCTAssertLessThanOrEqual(filtered.count, 2)
    }

    func test_filter_preservesOrder_whenCapping() {
        let suggestions = [
            "Breathing exercise",
            "Walking outside",
            "Stretching gently"
        ]
        let filtered = sut.filter(suggestions)

        // Should preserve original order, taking first two
        XCTAssertEqual(filtered[0], "Breathing exercise")
        XCTAssertEqual(filtered[1], "Walking outside")
    }

    // MARK: - Case Insensitivity

    func test_filter_caseInsensitive_allowed() {
        let suggestions = ["Try DEEP BREATHING"]
        let filtered = sut.filter(suggestions)
        XCTAssertEqual(filtered.count, 1)
    }

    func test_filter_caseInsensitive_blocked() {
        let suggestions = ["See a THERAPIST"]
        let filtered = sut.filter(suggestions)
        XCTAssertTrue(filtered.isEmpty)
    }

    // MARK: - Edge Cases

    func test_filter_emptyArray_returnsEmpty() {
        let filtered = sut.filter([])
        XCTAssertTrue(filtered.isEmpty)
    }

    func test_filter_emptyStrings_removed() {
        let suggestions = ["", "Breathing exercise", ""]
        let filtered = sut.filter(suggestions)
        XCTAssertEqual(filtered.count, 1)
    }

    func test_filter_unknownSuggestion_rejected() {
        // Suggestions without allowed keywords are rejected (default deny)
        let suggestions = ["Do something fun today"]
        let filtered = sut.filter(suggestions)
        XCTAssertTrue(filtered.isEmpty)
    }
}
