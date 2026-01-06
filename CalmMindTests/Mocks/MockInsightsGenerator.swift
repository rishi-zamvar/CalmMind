import Foundation
@testable import CalmMind

/// Mock insights generator for testing
final class MockInsightsGenerator: InsightsGeneratorProtocol, @unchecked Sendable {

    // MARK: - Response Configuration

    /// Result to return on success
    var mockResult: JournalInsights = JournalInsights(
        patterns: ["Test pattern"],
        suggestions: ["Take a walk"],
        inputHash: "mock_hash",
        providerModel: "mock-model",
        generatedAt: Date()
    )

    // MARK: - Error Configuration

    /// If true, throws the configured error
    var shouldFail: Bool = false

    /// Error to throw when shouldFail is true
    var failureError: OpenAIError = .networkError("Mock network error")

    // MARK: - Behavior Configuration

    /// Delay before returning (in seconds)
    var delaySeconds: TimeInterval = 0

    // MARK: - Call Tracking

    /// Number of times generate was called
    private(set) var callCount = 0

    /// Input from the last call
    private(set) var lastInput: String?

    // MARK: - InsightsGeneratorProtocol

    func generate(for entryText: String) async throws -> JournalInsights {
        callCount += 1
        lastInput = entryText

        if delaySeconds > 0 {
            try await Task.sleep(for: .seconds(delaySeconds))
        }

        if shouldFail {
            throw failureError
        }

        return mockResult
    }

    // MARK: - Test Helpers

    /// Reset all state
    func reset() {
        callCount = 0
        lastInput = nil
        shouldFail = false
        delaySeconds = 0
    }
}
