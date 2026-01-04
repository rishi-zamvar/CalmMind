import Foundation
@testable import CalmMind

/// Mock prompt service for testing
final class MockPromptService: PromptServiceProtocol {
    var shouldFail = false
    var failureError: PromptServiceError = .networkError
    var generatedPrompt = "What's bringing you joy today?"
    var generateCalled = false
    var generateCallCount = 0
    var lastContext: String?
    var delay: TimeInterval = 0

    func generatePrompt(context: String) async throws -> String {
        generateCalled = true
        generateCallCount += 1
        lastContext = context

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw failureError
        }

        return generatedPrompt
    }

    func reset() {
        shouldFail = false
        failureError = .networkError
        generatedPrompt = "What's bringing you joy today?"
        generateCalled = false
        generateCallCount = 0
        lastContext = nil
        delay = 0
    }
}
