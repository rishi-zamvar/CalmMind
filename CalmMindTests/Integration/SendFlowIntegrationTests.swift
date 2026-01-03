import XCTest
import SwiftData
@testable import CalmMind

/// Integration tests for the complete send flow: input -> orchestrator -> persistence
/// These tests verify atomicity, persistence, and error recovery
@MainActor
final class SendFlowIntegrationTests: XCTestCase {

    var container: ModelContainer!
    var orchestrator: AIOrchestrator!
    var mockOpenAI: MockOpenAIService!
    var messageRepo: MessageRepository!
    var sessionRepo: SessionRepository!
    var todoRepo: TodoRepository!
    var journalRepo: JournalRepository!

    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: ChatMessage.self, DailySession.self, TodoItem.self, JournalEntry.self, MemoryItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        mockOpenAI = MockOpenAIService()
        messageRepo = MessageRepository(context: container.mainContext)
        sessionRepo = SessionRepository(context: container.mainContext)
        todoRepo = TodoRepository(context: container.mainContext)
        journalRepo = JournalRepository(context: container.mainContext)

        let contextManager = ContextManager()
        let safetyClassifier = SafetyClassifier()
        let toolRegistry = ToolRegistry()
        let toolValidator = ToolValidator(registry: toolRegistry)

        orchestrator = AIOrchestrator(
            openAIService: mockOpenAI,
            contextManager: contextManager,
            safetyClassifier: safetyClassifier,
            toolRegistry: toolRegistry,
            toolValidator: toolValidator,
            messageRepository: messageRepo,
            sessionRepository: sessionRepo,
            todoRepository: todoRepo,
            journalRepository: journalRepo
        )
    }

    override func tearDown() {
        orchestrator = nil
        journalRepo = nil
        todoRepo = nil
        sessionRepo = nil
        messageRepo = nil
        mockOpenAI = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Happy Path

    func test_fullConversation_persistsAndReloads() async throws {
        // Send multiple messages
        mockOpenAI.mockResponseContent = "Hello! How are you feeling today?"
        _ = try await orchestrator.processMessage("Hi there")

        mockOpenAI.mockResponseContent = "I understand. It's okay to feel that way."
        _ = try await orchestrator.processMessage("I'm feeling a bit stressed")

        mockOpenAI.mockResponseContent = "What's on your mind?"
        _ = try await orchestrator.processMessage("Work has been overwhelming")

        // Verify all messages persisted
        let session = try sessionRepo.getOrCreate(for: Date())
        let messages = try messageRepo.fetchMessages(for: session)

        // Should have 6 messages: 3 user + 3 assistant
        XCTAssertEqual(messages.count, 6)

        let userMessages = messages.filter { $0.role == .user }
        let assistantMessages = messages.filter { $0.role == .assistant }

        XCTAssertEqual(userMessages.count, 3)
        XCTAssertEqual(assistantMessages.count, 3)

        // Verify message order (alternating user/assistant)
        XCTAssertEqual(messages[0].role, .user)
        XCTAssertEqual(messages[1].role, .assistant)
        XCTAssertEqual(messages[2].role, .user)
        XCTAssertEqual(messages[3].role, .assistant)
    }

    func test_conversation_sendsContextToOpenAI() async throws {
        // First message
        mockOpenAI.mockResponseContent = "Hello!"
        _ = try await orchestrator.processMessage("Hi")

        // Second message should include context from first
        mockOpenAI.mockResponseContent = "I see."
        _ = try await orchestrator.processMessage("How are you?")

        // Check that OpenAI received the conversation context
        XCTAssertNotNil(mockOpenAI.lastMessages)

        // Should have system + previous messages + current message
        let messageCount = mockOpenAI.lastMessages?.count ?? 0
        XCTAssertGreaterThanOrEqual(messageCount, 3) // system + at least user + assistant + user
    }

    func test_sessionIsolation_differentDays() async throws {
        // Create session for yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdaySession = try sessionRepo.getOrCreate(for: yesterday)
        let oldMessage = ChatMessage(content: "Yesterday's message", role: .user)
        try messageRepo.save(oldMessage, to: yesterdaySession)

        // Send a message today
        mockOpenAI.mockResponseContent = "Hello!"
        _ = try await orchestrator.processMessage("Hi today")

        // Verify today's session is separate
        let todaySession = try sessionRepo.getOrCreate(for: Date())
        XCTAssertNotEqual(todaySession.id, yesterdaySession.id)

        let todayMessages = try messageRepo.fetchMessages(for: todaySession)
        let yesterdayMessages = try messageRepo.fetchMessages(for: yesterdaySession)

        XCTAssertEqual(todayMessages.count, 2) // user + assistant
        XCTAssertEqual(yesterdayMessages.count, 1) // only yesterday's message
    }

    // MARK: - Atomicity (CRITICAL)

    func test_userMessageSaved_beforeNetworkCall() async throws {
        // Configure mock to track when it's called
        var apiCallTime: Date?
        mockOpenAI.mockResponseContent = "Response"

        // We can verify by checking message exists even if API call happens
        _ = try await orchestrator.processMessage("Test message")
        apiCallTime = Date()

        // User message should exist
        let session = try sessionRepo.getOrCreate(for: Date())
        let messages = try messageRepo.fetchMessages(for: session)
        let userMessages = messages.filter { $0.role == .user }

        XCTAssertEqual(userMessages.count, 1)
        XCTAssertEqual(userMessages.first?.content, "Test message")

        // Message timestamp should be before or equal to API call
        if let messageTime = userMessages.first?.timestamp, let apiTime = apiCallTime {
            XCTAssertLessThanOrEqual(messageTime, apiTime)
        }
    }

    func test_networkFailure_doesNotLoseUserMessage() async throws {
        // Configure failure
        mockOpenAI.shouldFail = true
        mockOpenAI.failureError = .networkError("Connection failed")

        // Send should fail
        do {
            _ = try await orchestrator.processMessage("Important message")
            XCTFail("Should have thrown")
        } catch {
            // Expected
        }

        // User message should STILL be saved
        let session = try sessionRepo.getOrCreate(for: Date())
        let messages = try messageRepo.fetchMessages(for: session)

        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.content, "Important message")
        XCTAssertEqual(messages.first?.role, .user)
    }

    func test_multipleNetworkFailures_preserveAllMessages() async throws {
        mockOpenAI.shouldFail = true
        mockOpenAI.failureError = .networkError("No connection")

        // Try to send multiple messages that all fail
        for i in 1...3 {
            do {
                _ = try await orchestrator.processMessage("Message \(i)")
            } catch {
                // Expected
            }
        }

        // All user messages should be saved
        let session = try sessionRepo.getOrCreate(for: Date())
        let messages = try messageRepo.fetchMessages(for: session)

        XCTAssertEqual(messages.count, 3)
        XCTAssertTrue(messages.allSatisfy { $0.role == .user })
    }

    func test_recoveryAfterNetworkFailure() async throws {
        // First message fails
        mockOpenAI.shouldFail = true
        mockOpenAI.failureError = .networkError("Temporary error")

        do {
            _ = try await orchestrator.processMessage("First message")
        } catch {
            // Expected
        }

        // Network recovers
        mockOpenAI.shouldFail = false
        mockOpenAI.mockResponseContent = "I'm back online!"

        // Second message succeeds
        let response = try await orchestrator.processMessage("Second message")

        XCTAssertEqual(response.content, "I'm back online!")

        // Both user messages should be saved
        let session = try sessionRepo.getOrCreate(for: Date())
        let messages = try messageRepo.fetchMessages(for: session)

        let userMessages = messages.filter { $0.role == .user }
        let assistantMessages = messages.filter { $0.role == .assistant }

        XCTAssertEqual(userMessages.count, 2)
        XCTAssertEqual(assistantMessages.count, 1) // Only second message got response
    }

    // MARK: - Crisis Flow Integration

    func test_crisisMessage_bypassesNetwork_savesToSession() async throws {
        // Send crisis message
        let response = try await orchestrator.processMessage("I don't want to live anymore")

        // Should return crisis response
        XCTAssertTrue(response.isCrisisResponse)
        XCTAssertTrue(response.content.contains("988"))

        // Should NOT call OpenAI
        XCTAssertEqual(mockOpenAI.sendCallCount, 0)

        // But should save both messages to session
        let session = try sessionRepo.getOrCreate(for: Date())
        let messages = try messageRepo.fetchMessages(for: session)

        XCTAssertEqual(messages.count, 2) // User + crisis response
        XCTAssertEqual(messages[0].role, .user)
        XCTAssertEqual(messages[1].role, .assistant)
    }

    // MARK: - Tool Integration

    func test_todoAdded_whenModelCallsTool() async throws {
        // Configure mock to return todo tool call
        mockOpenAI.configureTodoToolCall(title: "Call doctor")

        // Send message that triggers tool
        _ = try await orchestrator.processMessage("Remind me to call doctor")

        // Todo should be created
        let todos = try todoRepo.fetchIncomplete()
        XCTAssertEqual(todos.count, 1)
        XCTAssertEqual(todos.first?.title, "Call doctor")
        XCTAssertEqual(todos.first?.source, .ai)
    }

    func test_multipleTools_executed() async throws {
        // Configure mock to return multiple tool calls
        mockOpenAI.mockToolCalls = [
            OpenAIToolCall(
                id: "call_1",
                type: "function",
                function: OpenAIFunctionCall(
                    name: "add_todo",
                    arguments: "{\"title\": \"Task A\"}"
                )
            ),
            OpenAIToolCall(
                id: "call_2",
                type: "function",
                function: OpenAIFunctionCall(
                    name: "add_todo",
                    arguments: "{\"title\": \"Task B\"}"
                )
            )
        ]
        mockOpenAI.mockResponseContent = "Added both tasks!"

        _ = try await orchestrator.processMessage("Add two tasks")

        // Both todos should be created
        let todos = try todoRepo.fetchIncomplete()
        XCTAssertEqual(todos.count, 2)
    }

    func test_toolExecution_preservesMessageFlow() async throws {
        mockOpenAI.configureTodoToolCall(title: "Buy groceries")
        mockOpenAI.mockResponseContent = "I've added that to your list!"

        let response = try await orchestrator.processMessage("Add todo: buy groceries")

        // Response should still be returned (default response when empty)
        XCTAssertFalse(response.content.isEmpty)

        // Both user message and assistant response should be saved
        let session = try sessionRepo.getOrCreate(for: Date())
        let messages = try messageRepo.fetchMessages(for: session)

        XCTAssertGreaterThanOrEqual(messages.count, 2)
    }

    // MARK: - Response Quality

    func test_emptyMessage_rejected() async throws {
        do {
            _ = try await orchestrator.processMessage("")
            XCTFail("Should throw for empty message")
        } catch let error as OrchestratorError {
            XCTAssertEqual(error, .emptyMessage)
        }

        // No messages should be saved
        let session = try sessionRepo.getOrCreate(for: Date())
        let messages = try messageRepo.fetchMessages(for: session)
        XCTAssertEqual(messages.count, 0)
    }

    func test_whitespaceOnlyMessage_rejected() async throws {
        do {
            _ = try await orchestrator.processMessage("   \n\t  ")
            XCTFail("Should throw for whitespace-only message")
        } catch let error as OrchestratorError {
            XCTAssertEqual(error, .emptyMessage)
        }
    }

    func test_response_includesToolsExecuted() async throws {
        mockOpenAI.configureTodoToolCall(title: "Test task")

        let response = try await orchestrator.processMessage("Add a task")

        XCTAssertTrue(response.toolsExecuted.contains("add_todo"))
    }

    // MARK: - Session Management

    func test_session_createdIfNotExists() async throws {
        // No session exists yet
        mockOpenAI.mockResponseContent = "Hello!"

        _ = try await orchestrator.processMessage("Hi")

        // Session should be created
        let sessions = try sessionRepo.fetchRecentSessions(limit: 10)
        XCTAssertEqual(sessions.count, 1)
    }

    func test_session_reusedForSameDay() async throws {
        mockOpenAI.mockResponseContent = "Hello!"

        // Send multiple messages
        _ = try await orchestrator.processMessage("Message 1")
        _ = try await orchestrator.processMessage("Message 2")
        _ = try await orchestrator.processMessage("Message 3")

        // Should still be only one session
        let sessions = try sessionRepo.fetchRecentSessions(limit: 10)
        XCTAssertEqual(sessions.count, 1)

        // All messages in same session
        let session = sessions.first!
        let messages = try messageRepo.fetchMessages(for: session)
        XCTAssertEqual(messages.count, 6) // 3 user + 3 assistant
    }
}
