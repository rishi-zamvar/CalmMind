import Foundation
import CryptoKit

/// AI-generated insights with provenance metadata for staleness tracking
/// When journal entry text changes, insights become stale (inputHash mismatch)
struct JournalInsights: Codable, Equatable {

    /// Current schema version - increment when structure changes
    static let schemaVersion = 1

    // MARK: - Content

    /// Observed patterns from the journal entry
    let patterns: [String]

    /// Wellness suggestions based on the entry
    let suggestions: [String]

    // MARK: - Provenance Metadata

    /// SHA256 hash of the input text used to generate these insights
    /// Used for staleness detection when entry is edited
    let inputHash: String

    /// Model used to generate insights (e.g., "gpt-4o-mini")
    /// Useful for debugging and analytics
    let providerModel: String

    /// When these insights were generated
    let generatedAt: Date

    /// Schema version at time of creation
    /// Enables migration when structure changes
    let schemaVersion: Int

    // MARK: - Initialization

    init(
        patterns: [String],
        suggestions: [String],
        inputHash: String,
        providerModel: String,
        generatedAt: Date = Date()
    ) {
        self.patterns = patterns
        self.suggestions = suggestions
        self.inputHash = inputHash
        self.providerModel = providerModel
        self.generatedAt = generatedAt
        self.schemaVersion = Self.schemaVersion
    }

    // MARK: - Staleness Detection

    /// Check if these insights are stale (input text has changed)
    /// - Parameter currentHash: Hash of current entry text
    /// - Returns: true if entry has been modified since insights were generated
    func isStale(forInputHash currentHash: String) -> Bool {
        return inputHash != currentHash
    }

    // MARK: - Hash Computation

    /// Compute deterministic SHA256 hash of input text for staleness tracking
    /// - Parameter text: Entry text to hash
    /// - Returns: 64-character lowercase hex string
    static func computeInputHash(_ text: String) -> String {
        let data = Data(text.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
