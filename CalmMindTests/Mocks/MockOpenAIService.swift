import Foundation
@testable import CalmMind

/// Mock OpenAI service for testing dependent components
final class MockOpenAIService: OpenAIServiceProtocol, @unchecked Sendable {

    // MARK: - Response Configuration

    /// Text content to return
    var mockResponseContent: String = "I understand how you feel."

    /// Tool calls to return (if any)
    var mockToolCalls: [OpenAIToolCall]? = nil

    /// Response ID to return
    var mockResponseId: String = "chatcmpl-mock-123"

    /// Finish reason to return
    var mockFinishReason: String = "stop"

    /// Usage stats to return
    var mockUsage: TokenUsage? = nil

    // MARK: - Error Configuration

    /// If true, throws the configured error
    var shouldFail: Bool = false

    /// Error to throw when shouldFail is true
    var failureError: OpenAIError = .networkError("Mock network error")

    // MARK: - Behavior Configuration

    /// Delay before returning (in seconds)
    var delaySeconds: TimeInterval = 0

    /// Chunks to return for streaming (if not set, uses mockResponseContent)
    var streamingChunks: [String]? = nil

    // MARK: - Call Tracking

    /// Number of times sendChatCompletion was called
    private(set) var sendCallCount = 0

    /// Number of times streamChatCompletion was called
    private(set) var streamCallCount = 0

    /// Messages from the last call
    private(set) var lastMessages: [OpenAIMessage]?

    /// Tools from the last call
    private(set) var lastTools: [OpenAIToolDefinition]?

    /// Model from the last call
    private(set) var lastModel: String?

    /// MaxTokens from the last call
    private(set) var lastMaxTokens: Int?

    /// Temperature from the last call
    private(set) var lastTemperature: Double?

    // MARK: - OpenAIServiceProtocol

    func sendChatCompletion(
        messages: [OpenAIMessage],
        tools: [OpenAIToolDefinition]?,
        model: String,
        maxTokens: Int?,
        temperature: Double?
    ) async throws -> ChatCompletionResponse {
        sendCallCount += 1
        lastMessages = messages
        lastTools = tools
        lastModel = model
        lastMaxTokens = maxTokens
        lastTemperature = temperature

        if delaySeconds > 0 {
            try await Task.sleep(for: .seconds(delaySeconds))
        }

        if shouldFail {
            throw failureError
        }

        return ChatCompletionResponse(
            id: mockResponseId,
            content: mockResponseContent,
            toolCalls: mockToolCalls,
            finishReason: mockFinishReason,
            usage: mockUsage
        )
    }

    func streamChatCompletion(
        messages: [OpenAIMessage],
        tools: [OpenAIToolDefinition]?,
        model: String,
        maxTokens: Int?
    ) -> AsyncThrowingStream<String, Error> {
        streamCallCount += 1
        lastMessages = messages
        lastTools = tools
        lastModel = model
        lastMaxTokens = maxTokens

        return AsyncThrowingStream { continuation in
            Task {
                if self.delaySeconds > 0 {
                    try await Task.sleep(for: .seconds(self.delaySeconds))
                }

                if self.shouldFail {
                    continuation.finish(throwing: self.failureError)
                    return
                }

                // Use configured chunks or split mockResponseContent
                let chunks = self.streamingChunks ?? self.mockResponseContent.split(separator: " ").map { String($0) + " " }

                for chunk in chunks {
                    continuation.yield(chunk)
                    try await Task.sleep(for: .milliseconds(10))
                }

                continuation.finish()
            }
        }
    }

    // MARK: - Test Helpers

    /// Reset all state and call counts
    func reset() {
        sendCallCount = 0
        streamCallCount = 0
        lastMessages = nil
        lastTools = nil
        lastModel = nil
        lastMaxTokens = nil
        lastTemperature = nil
        shouldFail = false
        mockResponseContent = "I understand how you feel."
        mockToolCalls = nil
        streamingChunks = nil
    }

    /// Configure a tool call response
    func configureTodoToolCall(title: String) {
        mockToolCalls = [
            OpenAIToolCall(
                id: "call_\(UUID().uuidString.prefix(8))",
                type: "function",
                function: OpenAIFunctionCall(
                    name: "add_todo",
                    arguments: "{\"title\":\"\(title)\"}"
                )
            )
        ]
        mockResponseContent = ""
        mockFinishReason = "tool_calls"
    }

    /// Configure a crisis response (for testing safety bypass)
    func configureCrisisResponse() {
        mockResponseContent = "I'm here to help. If you're in crisis, please call 988."
        mockFinishReason = "stop"
        mockToolCalls = nil
    }

    /// Configure an error response
    func configureError(_ error: OpenAIError) {
        shouldFail = true
        failureError = error
    }
}
