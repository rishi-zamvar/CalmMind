import Foundation

/// Service for communicating with OpenAI API
final class OpenAIService: OpenAIServiceProtocol, Sendable {

    // MARK: - Constants

    private static let baseURL = "https://api.openai.com/v1"
    private static let chatCompletionsPath = "/chat/completions"

    // MARK: - Dependencies

    private let urlSession: URLSessionProtocol
    private let secretsStore: SecretsStore
    private let rateLimiter: RateLimiter
    private let retryPolicy: RetryPolicy

    // MARK: - Initialization

    init(
        urlSession: URLSessionProtocol = URLSession.shared,
        secretsStore: SecretsStore = KeychainSecretsStore(),
        rateLimiter: RateLimiter = RateLimiter(maxRequestsPerMinute: 60),
        retryPolicy: RetryPolicy = RetryPolicy()
    ) {
        self.urlSession = urlSession
        self.secretsStore = secretsStore
        self.rateLimiter = rateLimiter
        self.retryPolicy = retryPolicy
    }

    // MARK: - OpenAIServiceProtocol

    func sendChatCompletion(
        messages: [OpenAIMessage],
        tools: [OpenAIToolDefinition]?,
        model: String,
        maxTokens: Int?
    ) async throws -> ChatCompletionResponse {
        // Check API key
        guard let apiKey = secretsStore.getAPIKey() else {
            throw OpenAIError.missingAPIKey
        }

        // Check rate limit
        let allowed = await rateLimiter.shouldAllowRequest()
        guard allowed else {
            let waitTime = await rateLimiter.waitTimeUntilNextRequest()
            throw OpenAIError.rateLimited(retryAfter: waitTime)
        }

        // Build request
        let request = try buildRequest(
            apiKey: apiKey,
            messages: messages,
            tools: tools,
            model: model,
            maxTokens: maxTokens,
            stream: false
        )

        // Execute with retries
        var attempt = 1
        while true {
            do {
                await rateLimiter.recordRequest()
                let (data, response) = try await urlSession.data(for: request)
                return try handleResponse(data: data, response: response)
            } catch {
                // Check if we should retry
                let shouldRetry: Bool
                if let httpResponse = error as? OpenAIError {
                    switch httpResponse {
                    case .serverError(let code):
                        shouldRetry = retryPolicy.shouldRetry(statusCode: code, attempt: attempt)
                    case .rateLimited:
                        await rateLimiter.trigger429Cooldown()
                        shouldRetry = retryPolicy.shouldRetry(statusCode: 429, attempt: attempt)
                    default:
                        shouldRetry = false
                    }
                } else {
                    shouldRetry = retryPolicy.shouldRetry(error: error, attempt: attempt)
                }

                if shouldRetry {
                    let delay = retryPolicy.delayForAttempt(attempt)
                    try await Task.sleep(for: .seconds(delay))
                    attempt += 1
                    continue
                }

                // Transform error to OpenAIError
                throw transformError(error)
            }
        }
    }

    func streamChatCompletion(
        messages: [OpenAIMessage],
        tools: [OpenAIToolDefinition]?,
        model: String,
        maxTokens: Int?
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Check API key
                    guard let apiKey = secretsStore.getAPIKey() else {
                        continuation.finish(throwing: OpenAIError.missingAPIKey)
                        return
                    }

                    // Check rate limit
                    let allowed = await rateLimiter.shouldAllowRequest()
                    guard allowed else {
                        let waitTime = await rateLimiter.waitTimeUntilNextRequest()
                        continuation.finish(throwing: OpenAIError.rateLimited(retryAfter: waitTime))
                        return
                    }

                    // Build request
                    let request = try buildRequest(
                        apiKey: apiKey,
                        messages: messages,
                        tools: tools,
                        model: model,
                        maxTokens: maxTokens,
                        stream: true
                    )

                    await rateLimiter.recordRequest()

                    // Use URLSession directly for streaming
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: OpenAIError.invalidResponse)
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: errorForStatusCode(httpResponse.statusCode))
                        return
                    }

                    // Parse SSE stream
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            if jsonString == "[DONE]" {
                                continuation.finish()
                                return
                            }

                            if let data = jsonString.data(using: .utf8),
                               let chunk = try? JSONDecoder().decode(StreamingChunk.self, from: data),
                               let content = chunk.choices.first?.delta.content {
                                continuation.yield(content)
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: transformError(error))
                }
            }
        }
    }

    // MARK: - Private Methods

    private func buildRequest(
        apiKey: String,
        messages: [OpenAIMessage],
        tools: [OpenAIToolDefinition]?,
        model: String,
        maxTokens: Int?,
        stream: Bool
    ) throws -> URLRequest {
        guard let url = URL(string: Self.baseURL + Self.chatCompletionsPath) else {
            throw OpenAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatCompletionRequest(
            model: model,
            messages: messages,
            tools: tools,
            stream: stream,
            maxTokens: maxTokens,
            temperature: 0.7
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw OpenAIError.encodingError
        }

        return request
    }

    private func handleResponse(data: Data, response: URLResponse) throws -> ChatCompletionResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        // Handle error status codes
        if httpResponse.statusCode != 200 {
            throw errorForStatusCode(httpResponse.statusCode, data: data)
        }

        // Parse response
        do {
            let apiResponse = try JSONDecoder().decode(ChatCompletionAPIResponse.self, from: data)
            return ChatCompletionResponse(
                id: apiResponse.id,
                content: apiResponse.choices.first?.message.content,
                toolCalls: apiResponse.choices.first?.message.toolCalls,
                finishReason: apiResponse.choices.first?.finishReason,
                usage: apiResponse.usage
            )
        } catch {
            throw OpenAIError.decodingError(error.localizedDescription)
        }
    }

    private func errorForStatusCode(_ statusCode: Int, data: Data? = nil) -> OpenAIError {
        // Try to parse error message
        var message: String?
        if let data = data,
           let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
            message = errorResponse.error.message
        }

        switch statusCode {
        case 429:
            return .rateLimited(retryAfter: nil)
        case 500, 502, 503, 504:
            return .serverError(statusCode: statusCode)
        default:
            return .httpError(statusCode: statusCode, message: message)
        }
    }

    private func transformError(_ error: Error) -> OpenAIError {
        if let openAIError = error as? OpenAIError {
            return openAIError
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .timeout
            case NSURLErrorCancelled:
                return .cancelled
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return .networkError("No internet connection")
            default:
                return .networkError(nsError.localizedDescription)
            }
        }

        return .unknown(error.localizedDescription)
    }
}

// MARK: - API Response Types

private struct ChatCompletionAPIResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: TokenUsage?

    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Message: Codable {
        let role: OpenAIRole
        let content: String?
        let toolCalls: [OpenAIToolCall]?

        enum CodingKeys: String, CodingKey {
            case role
            case content
            case toolCalls = "tool_calls"
        }
    }
}
