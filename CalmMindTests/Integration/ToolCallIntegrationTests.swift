import XCTest
import SwiftData
@testable import CalmMind

/// Integration tests for the tool call flow: validation -> execution -> result
@MainActor
final class ToolCallIntegrationTests: XCTestCase {

    var container: ModelContainer!
    var todoRepo: TodoRepository!
    var journalRepo: JournalRepository!
    var sessionRepo: SessionRepository!
    var registry: ToolRegistry!
    var validator: ToolValidator!
    var todoTools: TodoTools!
    var journalTools: JournalTools!

    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: TodoItem.self, JournalEntry.self, DailySession.self, ChatMessage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        todoRepo = TodoRepository(context: container.mainContext)
        journalRepo = JournalRepository(context: container.mainContext)
        sessionRepo = SessionRepository(context: container.mainContext)
        registry = ToolRegistry()
        validator = ToolValidator(registry: registry)
        todoTools = TodoTools(todoRepository: todoRepo)
        journalTools = JournalTools(journalRepository: journalRepo, sessionRepository: sessionRepo)
    }

    override func tearDown() {
        todoTools = nil
        journalTools = nil
        validator = nil
        registry = nil
        sessionRepo = nil
        journalRepo = nil
        todoRepo = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Full Flow Tests

    func test_addTodoFlow_validateAndExecute() throws {
        // Simulate a tool call from the model
        let toolName = "add_todo"
        let arguments: [String: Any] = ["title": "Buy groceries"]

        // Step 1: Validate the tool call
        let validation = validator.validate(toolName: toolName, arguments: arguments)
        XCTAssertTrue(validation.isValid)

        // Step 2: Execute the tool
        let title = arguments["title"] as! String
        let result = try todoTools.addTodo(title: title)

        // Step 3: Verify the result
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.todoId)

        // Step 4: Verify the effect persisted to database
        let todos = try todoRepo.fetchIncomplete()
        XCTAssertEqual(todos.count, 1)
        XCTAssertEqual(todos.first?.title, "Buy groceries")
    }

    func test_completeTodoFlow_validateAndExecute() throws {
        // Setup: create a todo first
        _ = try todoTools.addTodo(title: "Test task")

        // Simulate a tool call to complete
        let toolName = "complete_todo"
        let arguments: [String: Any] = ["title": "Test task"]

        // Step 1: Validate
        let validation = validator.validate(toolName: toolName, arguments: arguments)
        XCTAssertTrue(validation.isValid)

        // Step 2: Execute
        let result = try todoTools.completeTodo(title: arguments["title"] as? String)

        // Step 3: Verify result
        XCTAssertTrue(result.success)

        // Step 4: Verify database
        let incomplete = try todoRepo.fetchIncomplete()
        XCTAssertTrue(incomplete.isEmpty)
        let completed = try todoRepo.fetchCompleted()
        XCTAssertEqual(completed.count, 1)
    }

    func test_listTodosFlow_validateAndExecute() throws {
        // Setup
        _ = try todoTools.addTodo(title: "Task 1")
        _ = try todoTools.addTodo(title: "Task 2")

        // Validate
        let validation = validator.validate(toolName: "list_todos", arguments: [:])
        XCTAssertTrue(validation.isValid)

        // Execute
        let result = try todoTools.listTodos(includeCompleted: false)

        // Verify
        XCTAssertEqual(result.todos.count, 2)
    }

    // MARK: - Unknown Tool Rejection

    func test_unknownToolCall_rejected() throws {
        let validation = validator.validate(toolName: "unknown_tool", arguments: [:])
        XCTAssertFalse(validation.isValid)
        XCTAssertNotNil(validation.error)
        XCTAssertTrue(validation.error!.contains("Unknown tool"))
    }

    // MARK: - Invalid Arguments Rejection

    func test_invalidArgs_rejected_missingRequired() throws {
        // add_todo requires "title"
        let validation = validator.validate(toolName: "add_todo", arguments: [:])
        XCTAssertFalse(validation.isValid)
        XCTAssertNotNil(validation.error)
        XCTAssertTrue(validation.error!.contains("Missing required"))
    }

    func test_invalidArgs_rejected_wrongType() throws {
        // title should be a string, not a number
        let validation = validator.validate(toolName: "add_todo", arguments: ["title": 123])
        XCTAssertFalse(validation.isValid)
        XCTAssertNotNil(validation.error)
        XCTAssertTrue(validation.error!.contains("Invalid type"))
    }

    // MARK: - Tool Effect Persisted to Database

    func test_todoEffect_persistedToDatabase() throws {
        // Add multiple todos
        _ = try todoTools.addTodo(title: "Task A")
        _ = try todoTools.addTodo(title: "Task B")
        _ = try todoTools.addTodo(title: "Task C")

        // Complete one
        _ = try todoTools.completeTodo(title: "Task B")

        // Verify database state
        let incomplete = try todoRepo.fetchIncomplete()
        let completed = try todoRepo.fetchCompleted()

        XCTAssertEqual(incomplete.count, 2)
        XCTAssertEqual(completed.count, 1)

        // Verify the completed one is correct
        XCTAssertEqual(completed.first?.title, "Task B")
        XCTAssertNotNil(completed.first?.completedAt)
    }

    func test_journalEffect_persistedToDatabase() throws {
        // Create a session first
        let session = try sessionRepo.getOrCreate(for: Date())

        // Create a journal draft
        let createResult = try journalTools.createDraft(for: session.id)
        XCTAssertTrue(createResult.success)

        guard let journalId = createResult.journalId, let uuid = UUID(uuidString: journalId) else {
            XCTFail("Failed to get journal ID")
            return
        }

        // Update the journal
        let updateResult = try journalTools.updateEntry(id: uuid, text: "Today I learned about integration tests.")
        XCTAssertTrue(updateResult.success)

        // Verify database state
        let entry = try journalRepo.fetchEntry(for: Date())
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.fullText, "Today I learned about integration tests.")
    }

    // MARK: - Tool Registry Exports Valid Schema

    func test_registryExportsValidOpenAISchema() {
        let tools = registry.openAIToolDefinitions

        // All tools should have valid schema
        for tool in tools {
            XCTAssertFalse(tool.function.name.isEmpty)
            XCTAssertFalse(tool.function.description.isEmpty)
            XCTAssertEqual(tool.type, "function")
        }
    }

    // MARK: - JSON Parsing Integration

    func test_parseJSONAndValidate() throws {
        let json = """
        {"title": "Buy milk"}
        """

        guard let arguments = validator.parseArguments(json) else {
            XCTFail("Failed to parse JSON")
            return
        }

        let validation = validator.validate(toolName: "add_todo", arguments: arguments)
        XCTAssertTrue(validation.isValid)
    }

    func test_parseInvalidJSONRejectsGracefully() {
        let invalidJSON = "not valid json"
        let arguments = validator.parseArguments(invalidJSON)
        XCTAssertNil(arguments)
    }

    // MARK: - AI Source Tracking

    func test_aiCreatedTodos_markedCorrectly() throws {
        // Add via tools (simulating AI)
        _ = try todoTools.addTodo(title: "AI task")

        // Add directly (simulating user)
        _ = try todoRepo.create(title: "User task", source: .user)

        // Verify sources
        let aiTodos = try todoRepo.fetchBySource(.ai)
        let userTodos = try todoRepo.fetchBySource(.user)

        XCTAssertEqual(aiTodos.count, 1)
        XCTAssertEqual(userTodos.count, 1)
        XCTAssertEqual(aiTodos.first?.title, "AI task")
        XCTAssertEqual(userTodos.first?.title, "User task")
    }
}
