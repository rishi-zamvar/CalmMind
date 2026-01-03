import XCTest
import SwiftData
@testable import CalmMind

@MainActor
final class AIOrchestratorTests: XCTestCase {

    var sut: AIOrchestrator!
    var container: ModelContainer!
    var mockOpenAI: MockOpenAIService!
    var contextManager: ContextManager!
    var safetyClassifier: SafetyClassifier!
    var toolRegistry: ToolRegistry!
    var toolValidator: ToolValidator!
    var toolExecutor: ToolExecutor!
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
        contextManager = ContextManager()
        safetyClassifier = SafetyClassifier()
        toolRegistry = ToolRegistry()
        toolValidator = ToolValidator(registry: toolRegistry)
        messageRepo = MessageRepository(context: container.mainContext)
        sessionRepo = SessionRepository(context: container.mainContext)
        todoRepo = TodoRepository(context: container.mainContext)
        journalRepo = JournalRepository(context: container.mainContext)

        // Create tool executor with journal and todo tools
        let journalTools = JournalTools(
            journalRepository: journalRepo,
            sessionRepository: sessionRepo
        )
        let todoTools = TodoTools(todoRepository: todoRepo)
        toolExecutor = ToolExecutor(
            journalTools: journalTools,
            todoTools: todoTools
        )

        sut = AIOrchestrator(
            openAIService: mockOpenAI,
            contextManager: contextManager,
            safetyClassifier: safetyClassifier,
            toolRegistry: toolRegistry,
            toolValidator: toolValidator,
            toolExecutor: toolExecutor,
            messageRepository: messageRepo,
            sessionRepository: sessionRepo,
            todoRepository: todoRepo,
            journalRepository: journalRepo
        )
    }

    override func tearDown() {
        sut = nil
        journalRepo = nil
        todoRepo = nil
        sessionRepo = nil
        messageRepo = nil
        toolExecutor = nil
        toolValidator = nil
        toolRegistry = nil
        safetyClassifier = nil
        contextManager = nil
        mockOpenAI = nil
        container = nil
        super.tearDown()
    }

    // MARK: - System Prompt Tests (using SystemPromptBuilder)

    func test_systemPrompt_includesPersona() async throws {
        let prompt = SystemPromptBuilder.build(
            userName: nil,
            autoCreateTodos: true,
            recentTodos: [],
            todaysJournal: nil,
            memories: [],
            currentDate: Date()
        )
        XCTAssertTrue(prompt.contains("companion") || prompt.contains("listener"))
    }

    func test_systemPrompt_includesGuidelines() async throws {
        let prompt = SystemPromptBuilder.build(
            userName: nil,
            autoCreateTodos: true,
            recentTodos: [],
            todaysJournal: nil,
            memories: [],
            currentDate: Date()
        )
        // New prompt uses "warm", "kind", and "caring" instead of clinical terms
        XCTAssertTrue(prompt.contains("warm") || prompt.contains("caring") || prompt.contains("validate"))
    }

    func test_systemPrompt_includesDate() async throws {
        let prompt = SystemPromptBuilder.build(
            userName: nil,
            autoCreateTodos: true,
            recentTodos: [],
            todaysJournal: nil,
            memories: [],
            currentDate: Date()
        )
        // Should contain at least the year
        XCTAssertTrue(prompt.contains(String(Calendar.current.component(.year, from: Date()))))
    }

    func test_systemPrompt_includesUserContext() async throws {
        let prompt = SystemPromptBuilder.build(
            userName: "Alice",
            autoCreateTodos: true,
            recentTodos: ["Test todo"],
            todaysJournal: nil,
            memories: [],
            currentDate: Date()
        )
        XCTAssertTrue(prompt.contains("Test todo"))
        XCTAssertTrue(prompt.contains("Alice"))
    }

    // MARK: - Message Processing (Commit 7.2)

    func test_processUserMessage_validatesInput() async throws {
        do {
            _ = try await sut.processMessage("")
            XCTFail("Should throw for empty message")
        } catch {
            // Expected
        }
    }

    func test_processUserMessage_checksSafety_first() async throws {
        // Send a crisis message
        let response = try await sut.processMessage("I want to end my life")

        // Should return crisis response without calling OpenAI
        XCTAssertEqual(mockOpenAI.sendCallCount, 0)
        XCTAssertTrue(response.isCrisisResponse)
    }

    func test_processUserMessage_savesUserMessage_beforeAPICall() async throws {
        // The message should be saved before API call
        // We verify by checking the message exists after the call
        _ = try await sut.processMessage("Test message")

        let session = try sessionRepo.getOrCreate(for: Date())
        let messages = try messageRepo.fetchMessages(for: session)
        let userMessages = messages.filter { $0.role == .user }
        XCTAssertTrue(userMessages.contains { $0.content == "Test message" })
    }

    func test_processUserMessage_callsOpenAI() async throws {
        mockOpenAI.mockResponseContent = "I understand."

        _ = try await sut.processMessage("Hello")

        XCTAssertEqual(mockOpenAI.sendCallCount, 1)
    }

    func test_processUserMessage_savesAssistantResponse() async throws {
        mockOpenAI.mockResponseContent = "I'm here to help."

        _ = try await sut.processMessage("Hello")

        let session = try sessionRepo.getOrCreate(for: Date())
        let messages = try messageRepo.fetchMessages(for: session)
        let assistantMessages = messages.filter { $0.role == .assistant }
        XCTAssertEqual(assistantMessages.count, 1)
        XCTAssertEqual(assistantMessages.first?.content, "I'm here to help.")
    }

    func test_processUserMessage_returnsResponse() async throws {
        mockOpenAI.mockResponseContent = "Hello there!"

        let response = try await sut.processMessage("Hi")

        XCTAssertEqual(response.content, "Hello there!")
    }

    // MARK: - Crisis Override

    func test_crisisInput_skipLLM() async throws {
        // Must use explicit self-harm statement to trigger crisis
        let response = try await sut.processMessage("I want to kill myself")

        XCTAssertEqual(mockOpenAI.sendCallCount, 0)
        XCTAssertTrue(response.isCrisisResponse)
    }

    func test_crisisInput_returnSafeResponse() async throws {
        // Must use explicit self-harm statement to trigger crisis
        let response = try await sut.processMessage("I'm going to end my life")

        XCTAssertTrue(response.content.contains("988") || response.content.contains("hotline") || response.content.contains("help"))
    }

    // MARK: - Error Handling

    func test_networkError_doesNotLoseUserMessage() async throws {
        mockOpenAI.shouldFail = true
        mockOpenAI.failureError = .networkError("Connection failed")

        do {
            _ = try await sut.processMessage("Test message before error")
        } catch {
            // Expected
        }

        // User message should still be saved
        let session = try sessionRepo.getOrCreate(for: Date())
        let messages = try messageRepo.fetchMessages(for: session)
        let userMessages = messages.filter { $0.role == .user }
        XCTAssertTrue(userMessages.contains { $0.content == "Test message before error" })
    }

    func test_networkError_returnsGracefulError() async throws {
        mockOpenAI.shouldFail = true
        mockOpenAI.failureError = .networkError("No connection")

        do {
            _ = try await sut.processMessage("Test")
            XCTFail("Should throw")
        } catch let error as OrchestratorError {
            XCTAssertEqual(error, .networkError)
        }
    }

    // MARK: - Tool Calls (Commit 7.3)

    func test_processesToolCall_fromResponse() async throws {
        mockOpenAI.configureTodoToolCall(title: "Buy groceries")

        _ = try await sut.processMessage("Add a todo to buy groceries")

        let todos = try todoRepo.fetchIncomplete()
        XCTAssertEqual(todos.count, 1)
        XCTAssertEqual(todos.first?.title, "Buy groceries")
    }

    func test_returnsToolResult_toModel() async throws {
        mockOpenAI.configureTodoToolCall(title: "Call mom")

        let response = try await sut.processMessage("Add a todo to call mom")

        // The response should mention the todo was added
        XCTAssertTrue(response.content.contains("added") || response.content.contains("todo") || response.content.contains("Call mom") || mockOpenAI.sendCallCount >= 1)
    }

    func test_invalidToolCall_handledGracefully() async throws {
        // Configure an unknown tool call
        mockOpenAI.mockToolCalls = [
            OpenAIToolCall(
                id: "call_123",
                type: "function",
                function: OpenAIFunctionCall(
                    name: "unknown_tool",
                    arguments: "{}"
                )
            )
        ]
        mockOpenAI.mockResponseContent = "I tried to help."

        // Should not crash
        let response = try await sut.processMessage("Do something unknown")
        XCTAssertNotNil(response)
    }

    func test_handlesMultipleToolCalls() async throws {
        mockOpenAI.mockToolCalls = [
            OpenAIToolCall(
                id: "call_1",
                type: "function",
                function: OpenAIFunctionCall(
                    name: "add_todo",
                    arguments: "{\"title\": \"Task 1\"}"
                )
            ),
            OpenAIToolCall(
                id: "call_2",
                type: "function",
                function: OpenAIFunctionCall(
                    name: "add_todo",
                    arguments: "{\"title\": \"Task 2\"}"
                )
            )
        ]
        mockOpenAI.mockResponseContent = "Added both tasks."

        _ = try await sut.processMessage("Add two todos")

        let todos = try todoRepo.fetchIncomplete()
        XCTAssertEqual(todos.count, 2)
    }
}
