import XCTest
@testable import CalmMind

/// Live integration tests that call the real OpenAI API
/// These tests are SKIPPED unless OPENAI_API_KEY is configured
///
/// Setup:
/// 1. Copy Config/Secrets.xcconfig.example to Config/Secrets.xcconfig
/// 2. Add your OpenAI API key
/// OR
/// 1. Edit Scheme → Test → Arguments → Environment Variables
/// 2. Add OPENAI_API_KEY = your-key
final class OpenAILiveTests: XCTestCase {

    var sut: OpenAIService!
    var testSecretsStore: MockSecretsStore!

    override func setUp() {
        super.setUp()
        testSecretsStore = MockSecretsStore()
        testSecretsStore.setStoredKey(TestSecrets.openAIAPIKey)
        sut = OpenAIService(
            urlSession: URLSession.shared,
            secretsStore: testSecretsStore,
            rateLimiter: RateLimiter(maxRequestsPerMinute: 10),
            retryPolicy: RetryPolicy()
        )
    }

    override func tearDown() {
        sut = nil
        testSecretsStore = nil
        super.tearDown()
    }

    // MARK: - Live Tests

    func test_live_simpleCompletion() async throws {
        try TestSecrets.skipIfNoAPIKey()

        let messages = [
            OpenAIMessage(role: .user, content: "Say 'hello' and nothing else")
        ]

        let response = try await sut.sendChatCompletion(
            messages: messages,
            tools: nil,
            model: "gpt-4o-mini",
            maxTokens: 10
        )

        XCTAssertNotNil(response.content)
        XCTAssertTrue(response.content?.lowercased().contains("hello") == true)
    }

    func test_live_toolCall() async throws {
        try TestSecrets.skipIfNoAPIKey()

        let tool = OpenAIToolDefinition(function: OpenAIFunctionDefinition(
            name: "add_todo",
            description: "Add a todo item to the user's list",
            parameters: [
                "type": AnyCodable("object"),
                "properties": AnyCodable([
                    "title": ["type": "string", "description": "The todo title"]
                ]),
                "required": AnyCodable(["title"])
            ]
        ))

        let messages = [
            OpenAIMessage(role: .user, content: "Add a todo: buy groceries")
        ]

        let response = try await sut.sendChatCompletion(
            messages: messages,
            tools: [tool],
            model: "gpt-4o-mini",
            maxTokens: 100
        )

        XCTAssertNotNil(response.toolCalls)
        XCTAssertEqual(response.toolCalls?.first?.function.name, "add_todo")
    }

    func test_live_conversationContext() async throws {
        try TestSecrets.skipIfNoAPIKey()

        let messages = [
            OpenAIMessage(role: .system, content: "You are a helpful assistant."),
            OpenAIMessage(role: .user, content: "My name is Alice."),
            OpenAIMessage(role: .assistant, content: "Nice to meet you, Alice!"),
            OpenAIMessage(role: .user, content: "What is my name?")
        ]

        let response = try await sut.sendChatCompletion(
            messages: messages,
            tools: nil,
            model: "gpt-4o-mini",
            maxTokens: 50
        )

        XCTAssertNotNil(response.content)
        XCTAssertTrue(response.content?.contains("Alice") == true)
    }

    func test_live_streaming() async throws {
        try TestSecrets.skipIfNoAPIKey()

        let messages = [
            OpenAIMessage(role: .user, content: "Count from 1 to 5")
        ]

        let stream = sut.streamChatCompletion(
            messages: messages,
            tools: nil,
            model: "gpt-4o-mini",
            maxTokens: 50
        )

        var fullResponse = ""
        for try await chunk in stream {
            fullResponse += chunk
        }

        XCTAssertFalse(fullResponse.isEmpty)
        // Should contain numbers 1-5
        XCTAssertTrue(fullResponse.contains("1"))
        XCTAssertTrue(fullResponse.contains("5"))
    }
}
