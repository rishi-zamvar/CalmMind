import XCTest
@testable import CalmMind

final class TodoTitleNormalizerTests: XCTestCase {

    var sut: TodoTitleNormalizer!

    override func setUp() {
        super.setUp()
        sut = TodoTitleNormalizer()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Length

    func test_shortensLongTitle_to50Chars() {
        let longTitle = String(repeating: "a", count: 100)

        let result = sut.normalize(longTitle)

        XCTAssertEqual(result.title.count, 50)
    }

    func test_addEllipsisWhenTruncated() {
        let longTitle = String(repeating: "word ", count: 20)

        let result = sut.normalize(longTitle)

        XCTAssertTrue(result.title.hasSuffix("..."))
    }

    // MARK: - Filler Words

    func test_removesLeadingFillerWords_iNeedTo() {
        let result = sut.normalize("I need to call the doctor")

        XCTAssertEqual(result.title, "Call the doctor")
    }

    func test_removesLeadingFillerWords_remember() {
        let result = sut.normalize("Remember to buy groceries")

        XCTAssertEqual(result.title, "Buy groceries")
    }

    func test_removesLeadingFillerWords_dontForget() {
        let result = sut.normalize("Don't forget to pick up kids")

        XCTAssertEqual(result.title, "Pick up kids")
    }

    func test_removesLeadingFillerWords_iShouldProbably() {
        let result = sut.normalize("I should probably schedule a meeting")

        XCTAssertEqual(result.title, "Schedule a meeting")
    }

    // MARK: - Capitalization

    func test_capitalizesFirstLetter() {
        let result = sut.normalize("call mom")

        XCTAssertEqual(result.title, "Call mom")
    }

    func test_preservesCapitalizationIfAlreadyCapitalized() {
        let result = sut.normalize("Call Mom")

        XCTAssertEqual(result.title, "Call Mom")
    }

    // MARK: - Punctuation

    func test_removesTrailingPunctuation_period() {
        let result = sut.normalize("Buy milk.")

        XCTAssertEqual(result.title, "Buy milk")
    }

    func test_removesTrailingPunctuation_exclamation() {
        let result = sut.normalize("Call dad!")

        XCTAssertEqual(result.title, "Call dad")
    }

    func test_preservesInternalPunctuation() {
        let result = sut.normalize("Buy milk, eggs, and bread")

        XCTAssertEqual(result.title, "Buy milk, eggs, and bread")
    }

    // MARK: - Date Extraction

    func test_extractsDateIfPresent_tomorrow() {
        let result = sut.normalize("Call doctor tomorrow")

        XCTAssertNotNil(result.extractedDueDate)
        XCTAssertEqual(result.title, "Call doctor")
    }

    func test_extractsDateIfPresent_today() {
        let result = sut.normalize("Submit report today")

        XCTAssertNotNil(result.extractedDueDate)
        // Due date should be today
        XCTAssertTrue(Calendar.current.isDateInToday(result.extractedDueDate!))
    }

    func test_noDateExtracted_whenNoDateMentioned() {
        let result = sut.normalize("Buy groceries")

        XCTAssertNil(result.extractedDueDate)
    }

    // MARK: - Whitespace

    func test_collapsesMultipleSpaces() {
        let result = sut.normalize("Call   the   doctor")

        XCTAssertEqual(result.title, "Call the doctor")
    }

    func test_trimsWhitespace() {
        let result = sut.normalize("  Buy milk  ")

        XCTAssertEqual(result.title, "Buy milk")
    }
}
