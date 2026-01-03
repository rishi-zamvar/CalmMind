import XCTest
@testable import CalmMind

final class MessageValidatorTests: XCTestCase {

    var sut: MessageValidator!

    override func setUp() {
        super.setUp()
        sut = MessageValidator()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Empty

    func test_rejectsEmptyMessage() {
        let result = sut.validate("")

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, .empty)
    }

    func test_rejectsWhitespaceOnlyMessage() {
        let result = sut.validate("   \n\t  ")

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, .empty)
    }

    // MARK: - Length

    func test_acceptsMessageUnderLimit() {
        let message = "Hello, how are you today?"

        let result = sut.validate(message)

        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.error)
    }

    func test_truncatesMessageOverLimit() {
        let longMessage = String(repeating: "a", count: 2500)

        let result = sut.validate(longMessage)

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.sanitized.count, 2000)
        XCTAssertTrue(result.wasTruncated)
    }

    func test_maxLengthIs2000Characters() {
        XCTAssertEqual(MessageValidator.maxLength, 2000)
    }

    // MARK: - Sanitization

    func test_trimsLeadingTrailingWhitespace() {
        let message = "  Hello world  "

        let result = sut.validate(message)

        XCTAssertEqual(result.sanitized, "Hello world")
    }

    func test_normalizesNewlines() {
        let message = "Line 1\r\nLine 2\rLine 3"

        let result = sut.validate(message)

        XCTAssertEqual(result.sanitized, "Line 1\nLine 2\nLine 3")
    }

    func test_collapsesMultipleNewlines() {
        let message = "Line 1\n\n\n\nLine 2"

        let result = sut.validate(message)

        XCTAssertEqual(result.sanitized, "Line 1\n\nLine 2")
    }

    // MARK: - Result

    func test_validResult_containsOriginalAndSanitized() {
        let message = "  Test  "

        let result = sut.validate(message)

        XCTAssertEqual(result.original, "  Test  ")
        XCTAssertEqual(result.sanitized, "Test")
    }
}
