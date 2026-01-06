import XCTest
import CryptoKit
@testable import CalmMind

/// Tests for JournalInsights - AI-generated insights with provenance metadata
/// Provenance enables staleness detection when journal entry is edited
final class JournalInsightsTests: XCTestCase {

    // MARK: - Initialization

    func test_init_storesAllProperties() {
        let now = Date()
        let insights = JournalInsights(
            patterns: ["Pattern 1", "Pattern 2"],
            suggestions: ["Suggestion 1"],
            inputHash: "abc123",
            providerModel: "gpt-4o-mini",
            generatedAt: now
        )

        XCTAssertEqual(insights.patterns, ["Pattern 1", "Pattern 2"])
        XCTAssertEqual(insights.suggestions, ["Suggestion 1"])
        XCTAssertEqual(insights.inputHash, "abc123")
        XCTAssertEqual(insights.providerModel, "gpt-4o-mini")
        XCTAssertEqual(insights.generatedAt, now)
        XCTAssertEqual(insights.schemaVersion, JournalInsights.schemaVersion)
    }

    // MARK: - Provenance Tracking

    func test_insights_storesGeneratedAtTimestamp() {
        let now = Date()
        let insights = JournalInsights(
            patterns: [],
            suggestions: [],
            inputHash: "abc",
            providerModel: "model",
            generatedAt: now
        )

        XCTAssertEqual(insights.generatedAt, now)
    }

    func test_insights_storesProviderModel() {
        let insights = JournalInsights(
            patterns: [],
            suggestions: [],
            inputHash: "abc",
            providerModel: "gpt-4o-mini",
            generatedAt: Date()
        )

        XCTAssertEqual(insights.providerModel, "gpt-4o-mini")
    }

    func test_insights_storesInputHash() {
        let insights = JournalInsights(
            patterns: [],
            suggestions: [],
            inputHash: "sha256hash",
            providerModel: "model",
            generatedAt: Date()
        )

        XCTAssertEqual(insights.inputHash, "sha256hash")
    }

    func test_insights_storesSchemaVersion() {
        let insights = JournalInsights(
            patterns: [],
            suggestions: [],
            inputHash: "hash",
            providerModel: "model",
            generatedAt: Date()
        )

        XCTAssertEqual(insights.schemaVersion, JournalInsights.schemaVersion)
    }

    // MARK: - Staleness Detection

    func test_isStale_differentHash_returnsTrue() {
        let insights = JournalInsights(
            patterns: ["Old pattern"],
            suggestions: [],
            inputHash: "original_hash",
            providerModel: "model",
            generatedAt: Date()
        )

        XCTAssertTrue(insights.isStale(forInputHash: "new_hash"))
    }

    func test_isStale_sameHash_returnsFalse() {
        let hash = "same_hash"
        let insights = JournalInsights(
            patterns: [],
            suggestions: [],
            inputHash: hash,
            providerModel: "model",
            generatedAt: Date()
        )

        XCTAssertFalse(insights.isStale(forInputHash: hash))
    }

    func test_isStale_emptyHashes_matchesCorrectly() {
        let insights = JournalInsights(
            patterns: [],
            suggestions: [],
            inputHash: "",
            providerModel: "model",
            generatedAt: Date()
        )

        XCTAssertFalse(insights.isStale(forInputHash: ""))
        XCTAssertTrue(insights.isStale(forInputHash: "non-empty"))
    }

    // MARK: - Input Hash Computation

    func test_computeInputHash_isDeterministic() {
        let text = "Hello world"
        let hash1 = JournalInsights.computeInputHash(text)
        let hash2 = JournalInsights.computeInputHash(text)

        XCTAssertEqual(hash1, hash2)
    }

    func test_computeInputHash_differentInput_differentHash() {
        let hash1 = JournalInsights.computeInputHash("Hello")
        let hash2 = JournalInsights.computeInputHash("World")

        XCTAssertNotEqual(hash1, hash2)
    }

    func test_computeInputHash_emptyString_producesHash() {
        let hash = JournalInsights.computeInputHash("")
        XCTAssertFalse(hash.isEmpty)
    }

    func test_computeInputHash_isHexadecimal() {
        let hash = JournalInsights.computeInputHash("test")
        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(hash.unicodeScalars.allSatisfy { hexCharacters.contains($0) })
    }

    func test_computeInputHash_length() {
        // SHA256 produces 64 hex characters
        let hash = JournalInsights.computeInputHash("test")
        XCTAssertEqual(hash.count, 64)
    }

    // MARK: - Codable Conformance

    func test_codable_roundTrip() throws {
        let original = JournalInsights(
            patterns: ["Pattern"],
            suggestions: ["Suggestion"],
            inputHash: "hash123",
            providerModel: "gpt-4o-mini",
            generatedAt: Date()
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JournalInsights.self, from: encoded)

        XCTAssertEqual(decoded.patterns, original.patterns)
        XCTAssertEqual(decoded.suggestions, original.suggestions)
        XCTAssertEqual(decoded.inputHash, original.inputHash)
        XCTAssertEqual(decoded.providerModel, original.providerModel)
        XCTAssertEqual(decoded.schemaVersion, original.schemaVersion)
    }

    func test_codable_emptyArrays() throws {
        let original = JournalInsights(
            patterns: [],
            suggestions: [],
            inputHash: "hash",
            providerModel: "model",
            generatedAt: Date()
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JournalInsights.self, from: encoded)

        XCTAssertTrue(decoded.patterns.isEmpty)
        XCTAssertTrue(decoded.suggestions.isEmpty)
    }

    // MARK: - Equatable Conformance

    func test_equatable_sameValues_equal() {
        let date = Date()
        let a = JournalInsights(patterns: ["A"], suggestions: ["B"], inputHash: "h", providerModel: "m", generatedAt: date)
        let b = JournalInsights(patterns: ["A"], suggestions: ["B"], inputHash: "h", providerModel: "m", generatedAt: date)

        XCTAssertEqual(a, b)
    }

    func test_equatable_differentPatterns_notEqual() {
        let date = Date()
        let a = JournalInsights(patterns: ["A"], suggestions: ["B"], inputHash: "h", providerModel: "m", generatedAt: date)
        let b = JournalInsights(patterns: ["C"], suggestions: ["B"], inputHash: "h", providerModel: "m", generatedAt: date)

        XCTAssertNotEqual(a, b)
    }

    func test_equatable_differentHash_notEqual() {
        let date = Date()
        let a = JournalInsights(patterns: ["A"], suggestions: ["B"], inputHash: "h1", providerModel: "m", generatedAt: date)
        let b = JournalInsights(patterns: ["A"], suggestions: ["B"], inputHash: "h2", providerModel: "m", generatedAt: date)

        XCTAssertNotEqual(a, b)
    }

    // MARK: - Schema Version

    func test_schemaVersion_isPositive() {
        XCTAssertGreaterThan(JournalInsights.schemaVersion, 0)
    }

    func test_schemaVersion_static_matchesInstance() {
        let insights = JournalInsights(
            patterns: [],
            suggestions: [],
            inputHash: "",
            providerModel: "",
            generatedAt: Date()
        )

        XCTAssertEqual(insights.schemaVersion, JournalInsights.schemaVersion)
    }
}
