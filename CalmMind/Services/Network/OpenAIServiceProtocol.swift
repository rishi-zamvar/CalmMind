import Foundation

/// Protocol defining OpenAI service operations
protocol OpenAIServiceProtocol: Sendable {

    /// Sends a chat completion request and returns the full response
    /// - Parameters:
    ///   - messages: The conversation messages
    ///   - tools: Optional tool definitions for function calling
    ///   - model: The model to use (defaults to gpt-4)
    ///   - maxTokens: Maximum tokens in response
    /// - Returns: The chat completion response
    func sendChatCompletion(
        messages: [OpenAIMessage],
        tools: [OpenAIToolDefinition]?,
        model: String,
        maxTokens: Int?
    ) async throws -> ChatCompletionResponse

    /// Sends a chat completion request with streaming
    /// - Parameters:
    ///   - messages: The conversation messages
    ///   - tools: Optional tool definitions
    ///   - model: The model to use
    ///   - maxTokens: Maximum tokens
    /// - Returns: AsyncThrowingStream of partial responses
    func streamChatCompletion(
        messages: [OpenAIMessage],
        tools: [OpenAIToolDefinition]?,
        model: String,
        maxTokens: Int?
    ) -> AsyncThrowingStream<String, Error>
}

/// Protocol for URL session operations (for mocking)
protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// Make URLSession conform to our protocol
extension URLSession: URLSessionProtocol {}
