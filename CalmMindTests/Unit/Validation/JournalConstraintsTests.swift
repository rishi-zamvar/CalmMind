import XCTest
@testable import CalmMind

final class JournalConstraintsTests: XCTestCase {

    var sut: JournalConstraints!

    override func setUp() {
        super.setUp()
        sut = JournalConstraints()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Max Length

    func test_maxLengthIs5000Characters() {
        XCTAssertEqual(JournalConstraints.maxLength, 5000)
    }

    func test_acceptsEntryUnderLimit() {
        let entry = "Today was a good day."

        let result = sut.validate(entry)

        XCTAssertTrue(result.isValid)
    }

    func test_truncatesEntryOverLimit() {
        let longEntry = String(repeating: "a", count: 6000)

        let result = sut.validate(longEntry)

        XCTAssertEqual(result.sanitized.count, 5000)
        XCTAssertTrue(result.wasTruncated)
    }

    // MARK: - Empty

    func test_entryCantBeEmpty() {
        let result = sut.validate("")

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, .empty)
    }

    func test_entryCantBeWhitespaceOnly() {
        let result = sut.validate("   \n\t   ")

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.error, .empty)
    }

    // MARK: - Sanitization

    func test_trimsWhitespace() {
        let entry = "   My journal entry   "

        let result = sut.validate(entry)

        XCTAssertEqual(result.sanitized, "My journal entry")
    }
}
