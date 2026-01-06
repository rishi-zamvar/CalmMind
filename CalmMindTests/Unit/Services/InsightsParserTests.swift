import XCTest
@testable import CalmMind

/// Tests for InsightsParser - deterministic parser with strict contract
/// Extracts PATTERNS: and SUGGESTIONS: sections from LLM responses
final class InsightsParserTests: XCTestCase {

    var sut: InsightsParser!

    override func setUp() {
        super.setUp()
        sut = InsightsParser(config: InsightsConfig())
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Perfect Format

    func test_parse_perfectFormat_extractsBothSections() {
        let input = """
        PATTERNS:
        - Meeting with friends improved mood
        - Work stress appearing frequently
        SUGGESTIONS:
        - Try 4-7-8 breathing technique
        - Take a 5-minute walk
        """

        let result = sut.parse(input)

        XCTAssertEqual(result.patterns.count, 2)
        XCTAssertEqual(result.suggestions.count, 2)
        XCTAssertEqual(result.patterns[0], "Meeting with friends improved mood")
        XCTAssertEqual(result.suggestions[0], "Try 4-7-8 breathing technique")
    }

    // MARK: - Missing Sections

    func test_parse_missingPatterns_returnsEmptyPatterns() {
        let input = """
        SUGGESTIONS:
        - Try breathing exercises
        """

        let result = sut.parse(input)

        XCTAssertTrue(result.patterns.isEmpty)
        XCTAssertEqual(result.suggestions.count, 1)
    }

    func test_parse_missingSuggestions_returnsEmptySuggestions() {
        let input = """
        PATTERNS:
        - Work stress noted
        """

        let result = sut.parse(input)

        XCTAssertEqual(result.patterns.count, 1)
        XCTAssertTrue(result.suggestions.isEmpty)
    }

    func test_parse_bothMissing_returnsEmptyArrays() {
        let input = "Some random text without sections"

        let result = sut.parse(input)

        XCTAssertTrue(result.patterns.isEmpty)
        XCTAssertTrue(result.suggestions.isEmpty)
    }

    func test_parse_emptyString_returnsEmptyArrays() {
        let result = sut.parse("")

        XCTAssertTrue(result.patterns.isEmpty)
        XCTAssertTrue(result.suggestions.isEmpty)
    }

    // MARK: - Over-Long Items

    func test_parse_overLongItem_isTruncated() {
        let longPattern = String(repeating: "x", count: 200)
        let input = """
        PATTERNS:
        - \(longPattern)
        SUGGESTIONS:
        - Short tip
        """

        let result = sut.parse(input)

        XCTAssertLessThanOrEqual(result.patterns[0].count, InsightsConfig().maxItemLength)
        XCTAssertTrue(result.patterns[0].hasSuffix("..."))
    }

    // MARK: - Max Items Cap

    func test_parse_tooManyPatterns_cappedAtMax() {
        let input = """
        PATTERNS:
        - Pattern 1
        - Pattern 2
        - Pattern 3
        - Pattern 4
        - Pattern 5
        SUGGESTIONS:
        - Tip 1
        """

        let result = sut.parse(input)

        XCTAssertEqual(result.patterns.count, InsightsConfig().maxPatterns)
    }

    func test_parse_tooManySuggestions_cappedAtMax() {
        let input = """
        PATTERNS:
        - Pattern 1
        SUGGESTIONS:
        - Tip 1
        - Tip 2
        - Tip 3
        - Tip 4
        - Tip 5
        """

        let result = sut.parse(input)

        XCTAssertEqual(result.suggestions.count, InsightsConfig().maxSuggestions)
    }

    // MARK: - Bullet/Numbering Variants

    func test_parse_numberedList_stripsNumbers() {
        let input = """
        PATTERNS:
        1. First pattern
        2. Second pattern
        SUGGESTIONS:
        1) First tip
        """

        let result = sut.parse(input)

        XCTAssertEqual(result.patterns[0], "First pattern")
        XCTAssertEqual(result.suggestions[0], "First tip")
    }

    func test_parse_asteriskBullets_stripsAsterisks() {
        let input = """
        PATTERNS:
        * Pattern one
        SUGGESTIONS:
        * Tip one
        """

        let result = sut.parse(input)

        XCTAssertEqual(result.patterns[0], "Pattern one")
    }

    func test_parse_bulletPoint_stripsBullet() {
        let input = """
        PATTERNS:
        • Bullet pattern
        SUGGESTIONS:
        • Bullet tip
        """

        let result = sut.parse(input)

        XCTAssertEqual(result.patterns[0], "Bullet pattern")
    }

    // MARK: - Whitespace Normalization

    func test_parse_extraWhitespace_normalized() {
        let input = """
        PATTERNS:
        -   Extra   spaces   here
        SUGGESTIONS:
        -    More   spaces
        """

        let result = sut.parse(input)

        XCTAssertEqual(result.patterns[0], "Extra spaces here")
        XCTAssertEqual(result.suggestions[0], "More spaces")
    }

    func test_parse_leadingTrailingWhitespace_trimmed() {
        let input = """
        PATTERNS:
        -    Leading and trailing
        SUGGESTIONS:
        -    Also trimmed
        """

        let result = sut.parse(input)

        XCTAssertEqual(result.patterns[0], "Leading and trailing")
        XCTAssertEqual(result.suggestions[0], "Also trimmed")
    }

    // MARK: - Stable Ordering

    func test_parse_ordering_isStable() {
        let input = """
        PATTERNS:
        - Alpha
        - Beta
        SUGGESTIONS:
        - One
        - Two
        """

        let result1 = sut.parse(input)
        let result2 = sut.parse(input)

        XCTAssertEqual(result1.patterns, result2.patterns)
        XCTAssertEqual(result1.suggestions, result2.suggestions)
    }

    func test_parse_ordering_preservesOriginalOrder() {
        let input = """
        PATTERNS:
        - Third item
        - First item
        - Second item
        SUGGESTIONS:
        - Zebra
        - Apple
        """

        let result = sut.parse(input)

        // Should preserve input order, not alphabetize
        XCTAssertEqual(result.patterns[0], "Third item")
        XCTAssertEqual(result.patterns[1], "First item")
        XCTAssertEqual(result.suggestions[0], "Zebra")
        XCTAssertEqual(result.suggestions[1], "Apple")
    }

    // MARK: - Case Insensitive Headers

    func test_parse_lowercaseHeaders_works() {
        let input = """
        patterns:
        - Lower pattern
        suggestions:
        - Lower tip
        """

        let result = sut.parse(input)

        XCTAssertEqual(result.patterns.count, 1)
        XCTAssertEqual(result.suggestions.count, 1)
    }

    func test_parse_mixedCaseHeaders_works() {
        let input = """
        PaTtErNs:
        - Mixed pattern
        SuGgEsTiOnS:
        - Mixed tip
        """

        let result = sut.parse(input)

        XCTAssertEqual(result.patterns.count, 1)
        XCTAssertEqual(result.suggestions.count, 1)
    }

    // MARK: - Edge Cases

    func test_parse_emptyLines_skipped() {
        let input = """
        PATTERNS:
        - First pattern

        - Second pattern

        SUGGESTIONS:
        - Tip
        """

        let result = sut.parse(input)

        XCTAssertEqual(result.patterns.count, 2)
    }

    func test_parse_sectionOnly_noItems() {
        let input = """
        PATTERNS:
        SUGGESTIONS:
        """

        let result = sut.parse(input)

        XCTAssertTrue(result.patterns.isEmpty)
        XCTAssertTrue(result.suggestions.isEmpty)
    }

    // MARK: - ParsedInsights Equatable

    func test_parsedInsights_equatable() {
        let a = InsightsParser.ParsedInsights(patterns: ["A"], suggestions: ["B"])
        let b = InsightsParser.ParsedInsights(patterns: ["A"], suggestions: ["B"])
        let c = InsightsParser.ParsedInsights(patterns: ["C"], suggestions: ["D"])

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
