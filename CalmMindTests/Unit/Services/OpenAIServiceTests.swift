import XCTest
@testable import CalmMind

final class OpenAIServiceTests: XCTestCase {

    var sut: OpenAIService!
    var mockURLSession: MockURLSession!
    var mockSecretsStore: MockSecretsStore!
    var mockRateLimiter: RateLimiter!

    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        mockSecretsStore = MockSecretsStore()
        mockRateLimiter = RateLimiter(maxRequestsPerMinute: 60)
        mockSecretsStore.setStoredKey("sk-test-key")
        sut = OpenAIService(
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            rateLimiter: mockRateLimiter
        )
    }

    override func tearDown() {
        sut = nil
        mockURLSession = nil
        mockSecretsStore = nil
        mockRateLimiter = nil
        super.tearDown()
    }

    // MARK: - Configuration

    func test_requiresAPIKey_throwsIfMissing() async {
        mockSecretsStore.setStoredKey(nil)

        do {
            let _ = try await sut.sendChatCompletion(
                messages: [OpenAIMessage(role: .user, content: "Hello")],
                tools: nil,
                model: "gpt-4",
                maxTokens: nil
            )
            XCTFail("Expected missingAPIKey error")
        } catch {
            XCTAssertEqual(error as? OpenAIError, .missingAPIKey)
        }
    }

    func test_usesCorrectEndpoint() async throws {
        setupSuccessResponse()

        let _ = try await sut.sendChatCompletion(
            messages: [OpenAIMessage(role: .user, content: "Hello")],
            tools: nil,
            model: "gpt-4",
            maxTokens: nil
        )

        XCTAssertEqual(mockURLSession.recordedRequests.first?.url?.host, "api.openai.com")
        XCTAssertEqual(mockURLSession.recordedRequests.first?.url?.path, "/v1/chat/completions")
    }

    func test_setsAuthorizationHeader() async throws {
        setupSuccessResponse()

        let _ = try await sut.sendChatCompletion(
            messages: [OpenAIMessage(role: .user, content: "Hello")],
            tools: nil,
            model: "gpt-4",
            maxTokens: nil
        )

        let authHeader = mockURLSession.recordedRequests.first?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "Bearer sk-test-key")
    }

    func test_setsContentTypeHeader() async throws {
        setupSuccessResponse()

        let _ = try await sut.sendChatCompletion(
            messages: [OpenAIMessage(role: .user, content: "Hello")],
            tools: nil,
            model: "gpt-4",
            maxTokens: nil
        )

        let contentType = mockURLSession.recordedRequests.first?.value(forHTTPHeaderField: "Content-Type")
        XCTAssertEqual(contentType, "application/json")
    }

    // MARK: - Request Building

    func test_constructsCorrectRequestBody() async throws {
        setupSuccessResponse()

        let messages = [
            OpenAIMessage(role: .system, content: "You are helpful"),
            OpenAIMessage(role: .user, content: "Hello")
        ]
        let _ = try await sut.sendChatCompletion(
            messages: messages,
            tools: nil,
            model: "gpt-4",
            maxTokens: 500
        )

        let body = mockURLSession.recordedRequests.first?.httpBody
        XCTAssertNotNil(body)
        let json = try JSONSerialization.jsonObject(with: body!, options: []) as? [String: Any]
        XCTAssertEqual(json?["model"] as? String, "gpt-4")
        XCTAssertEqual(json?["max_tokens"] as? Int, 500)
    }

    func test_includesAllMessages() async throws {
        setupSuccessResponse()

        let messages = [
            OpenAIMessage(role: .system, content: "System"),
            OpenAIMessage(role: .user, content: "User"),
            OpenAIMessage(role: .assistant, content: "Assistant")
        ]
        let _ = try await sut.sendChatCompletion(
            messages: messages,
            tools: nil,
            model: "gpt-4",
            maxTokens: nil
        )

        let body = mockURLSession.recordedRequests.first?.httpBody
        let json = try JSONSerialization.jsonObject(with: body!, options: []) as? [String: Any]
        let messageArray = json?["messages"] as? [[String: Any]]
        XCTAssertEqual(messageArray?.count, 3)
    }

    func test_includesTools_whenProvided() async throws {
        setupSuccessResponse()

        let tool = OpenAIToolDefinition(function: OpenAIFunctionDefinition(
            name: "add_todo",
            description: "Add a todo item",
            parameters: ["type": AnyCodable("object")]
        ))
        let _ = try await sut.sendChatCompletion(
            messages: [OpenAIMessage(role: .user, content: "Hello")],
            tools: [tool],
            model: "gpt-4",
            maxTokens: nil
        )

        let body = mockURLSession.recordedRequests.first?.httpBody
        let json = try JSONSerialization.jsonObject(with: body!, options: []) as? [String: Any]
        let tools = json?["tools"] as? [[String: Any]]
        XCTAssertEqual(tools?.count, 1)
    }

    // MARK: - Response Parsing

    func test_parsesSuccessfulResponse() async throws {
        let responseJSON = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion",
            "created": 1677652288,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "Hello! How can I help you?"
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": 9,
                "completion_tokens": 12,
                "total_tokens": 21
            }
        }
        """
        mockURLSession.mockData = responseJSON.data(using: .utf8)!
        mockURLSession.mockStatusCode = 200

        let response = try await sut.sendChatCompletion(
            messages: [OpenAIMessage(role: .user, content: "Hello")],
            tools: nil,
            model: "gpt-4",
            maxTokens: nil
        )

        XCTAssertEqual(response.id, "chatcmpl-123")
        XCTAssertEqual(response.content, "Hello! How can I help you?")
        XCTAssertEqual(response.finishReason, "stop")
    }

    func test_parsesToolCallResponse() async throws {
        let responseJSON = """
        {
            "id": "chatcmpl-456",
            "object": "chat.completion",
            "created": 1677652288,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": null,
                    "tool_calls": [{
                        "id": "call_abc123",
                        "type": "function",
                        "function": {
                            "name": "add_todo",
                            "arguments": "{\\"title\\":\\"Buy milk\\"}"
                        }
                    }]
                },
                "finish_reason": "tool_calls"
            }]
        }
        """
        mockURLSession.mockData = responseJSON.data(using: .utf8)!
        mockURLSession.mockStatusCode = 200

        let response = try await sut.sendChatCompletion(
            messages: [OpenAIMessage(role: .user, content: "Add todo: buy milk")],
            tools: nil,
            model: "gpt-4",
            maxTokens: nil
        )

        XCTAssertEqual(response.toolCalls?.count, 1)
        XCTAssertEqual(response.toolCalls?.first?.function.name, "add_todo")
    }

    // MARK: - Error Handling

    func test_handleRateLimitError_429() async {
        mockURLSession.mockData = """
        {"error": {"message": "Rate limit exceeded", "type": "rate_limit_error", "code": "rate_limit"}}
        """.data(using: .utf8)!
        mockURLSession.mockStatusCode = 429

        do {
            let _ = try await sut.sendChatCompletion(
                messages: [OpenAIMessage(role: .user, content: "Hello")],
                tools: nil,
                model: "gpt-4",
                maxTokens: nil
            )
            XCTFail("Expected rate limit error")
        } catch {
            if case .rateLimited = error as? OpenAIError {
                // Success
            } else {
                XCTFail("Expected rateLimited error, got \(error)")
            }
        }
    }

    func test_handleInvalidAPIKey_401() async {
        mockURLSession.mockData = """
        {"error": {"message": "Invalid API key", "type": "invalid_api_key", "code": "invalid_api_key"}}
        """.data(using: .utf8)!
        mockURLSession.mockStatusCode = 401

        do {
            let _ = try await sut.sendChatCompletion(
                messages: [OpenAIMessage(role: .user, content: "Hello")],
                tools: nil,
                model: "gpt-4",
                maxTokens: nil
            )
            XCTFail("Expected HTTP error")
        } catch {
            if case let .httpError(statusCode, _) = error as? OpenAIError {
                XCTAssertEqual(statusCode, 401)
            } else {
                XCTFail("Expected httpError, got \(error)")
            }
        }
    }

    func test_handleServerError_500() async {
        mockURLSession.mockData = Data()
        mockURLSession.mockStatusCode = 500

        do {
            let _ = try await sut.sendChatCompletion(
                messages: [OpenAIMessage(role: .user, content: "Hello")],
                tools: nil,
                model: "gpt-4",
                maxTokens: nil
            )
            XCTFail("Expected server error")
        } catch {
            if case .serverError(let code) = error as? OpenAIError {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        }
    }

    func test_handleNetworkTimeout() async {
        mockURLSession.mockError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)

        do {
            let _ = try await sut.sendChatCompletion(
                messages: [OpenAIMessage(role: .user, content: "Hello")],
                tools: nil,
                model: "gpt-4",
                maxTokens: nil
            )
            XCTFail("Expected timeout error")
        } catch {
            if case .timeout = error as? OpenAIError {
                // Success
            } else {
                XCTFail("Expected timeout error, got \(error)")
            }
        }
    }

    func test_handleMalformedResponse() async {
        mockURLSession.mockData = "not valid json".data(using: .utf8)!
        mockURLSession.mockStatusCode = 200

        do {
            let _ = try await sut.sendChatCompletion(
                messages: [OpenAIMessage(role: .user, content: "Hello")],
                tools: nil,
                model: "gpt-4",
                maxTokens: nil
            )
            XCTFail("Expected decoding error")
        } catch {
            if case .decodingError = error as? OpenAIError {
                // Success
            } else {
                XCTFail("Expected decodingError, got \(error)")
            }
        }
    }

    // MARK: - Rate Limiting Integration

    func test_respectsRateLimiter() async throws {
        // Use a rate limiter that's exhausted
        mockRateLimiter = RateLimiter(maxRequestsPerMinute: 1)
        await mockRateLimiter.recordRequest() // Exhaust the limiter
        sut = OpenAIService(
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            rateLimiter: mockRateLimiter
        )

        setupSuccessResponse()

        do {
            let _ = try await sut.sendChatCompletion(
                messages: [OpenAIMessage(role: .user, content: "Hello")],
                tools: nil,
                model: "gpt-4",
                maxTokens: nil
            )
            XCTFail("Expected rate limit error")
        } catch {
            if case .rateLimited = error as? OpenAIError {
                // Success - request was blocked
            } else {
                XCTFail("Expected rateLimited, got \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func setupSuccessResponse() {
        mockURLSession.mockData = """
        {
            "id": "chatcmpl-123",
            "object": "chat.completion",
            "created": 1677652288,
            "model": "gpt-4",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "OK"
                },
                "finish_reason": "stop"
            }]
        }
        """.data(using: .utf8)!
        mockURLSession.mockStatusCode = 200
    }
}
