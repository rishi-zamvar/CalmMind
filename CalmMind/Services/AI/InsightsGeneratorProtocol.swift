import Foundation

/// Protocol for insights generation to enable testing with mocks
protocol InsightsGeneratorProtocol: Sendable {
    /// Generate insights for the given text
    /// - Parameter entryText: Journal entry text to analyze
    /// - Throws: OpenAIError on failure
    /// - Returns: JournalInsights with provenance metadata
    func generate(for entryText: String) async throws -> JournalInsights
}

// Conformance for production implementation
extension InsightsGenerator: InsightsGeneratorProtocol {}
