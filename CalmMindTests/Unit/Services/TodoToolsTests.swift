import XCTest
import SwiftData
@testable import CalmMind

@MainActor
final class TodoToolsTests: XCTestCase {

    var sut: TodoTools!
    var container: ModelContainer!
    var todoRepo: TodoRepository!

    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: TodoItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        todoRepo = TodoRepository(context: container.mainContext)
        sut = TodoTools(todoRepository: todoRepo)
    }

    override func tearDown() {
        sut = nil
        todoRepo = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Add Todo

    func test_addTodo_createsItem() throws {
        let result = try sut.addTodo(title: "Buy groceries")

        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.todoId)

        let todos = try todoRepo.fetchIncomplete()
        XCTAssertEqual(todos.count, 1)
        XCTAssertEqual(todos.first?.title, "Buy groceries")
    }

    func test_addTodo_normalizesTitle() throws {
        let result = try sut.addTodo(title: "  i need to call doctor  ")

        XCTAssertTrue(result.success)

        let todos = try todoRepo.fetchIncomplete()
        // Should be normalized (trimmed, filler words removed, capitalized)
        XCTAssertEqual(todos.first?.title, "Call doctor")
    }

    func test_addTodo_extractsDueDate() throws {
        let result = try sut.addTodo(title: "Call mom tomorrow")

        XCTAssertTrue(result.success)

        let todos = try todoRepo.fetchIncomplete()
        // Should have extracted due date
        XCTAssertNotNil(todos.first?.dueDate)
    }

    func test_addTodo_marksAsAISource() throws {
        let result = try sut.addTodo(title: "Test todo")

        XCTAssertTrue(result.success)

        let todos = try todoRepo.fetchIncomplete()
        XCTAssertEqual(todos.first?.source, .ai)
    }

    func test_addTodo_validatesTitle_notEmpty() throws {
        let result = try sut.addTodo(title: "")

        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }

    func test_addTodo_validatesTitle_maxLength() throws {
        let longTitle = String(repeating: "a", count: 1000)
        let result = try sut.addTodo(title: longTitle)

        XCTAssertTrue(result.success)

        let todos = try todoRepo.fetchIncomplete()
        // Title should be truncated
        XCTAssertLessThanOrEqual(todos.first?.title.count ?? 0, 50)
    }

    // MARK: - Complete Todo

    func test_completeTodo_byTitle() throws {
        // Setup: create a todo
        _ = try sut.addTodo(title: "Test task")

        // Complete it
        let result = try sut.completeTodo(title: "Test task")

        XCTAssertTrue(result.success)

        let incomplete = try todoRepo.fetchIncomplete()
        XCTAssertTrue(incomplete.isEmpty)
    }

    func test_completeTodo_byTitle_fuzzyMatch() throws {
        // Setup: create a todo
        _ = try sut.addTodo(title: "Call the doctor")

        // Complete with slightly different wording
        let result = try sut.completeTodo(title: "call doctor")

        XCTAssertTrue(result.success)
    }

    func test_completeTodo_setsCompletedDate() throws {
        _ = try sut.addTodo(title: "Test task")
        _ = try sut.completeTodo(title: "Test task")

        let completed = try todoRepo.fetchCompleted()
        XCTAssertNotNil(completed.first?.completedAt)
    }

    func test_completeTodo_returnsErrorIfNotFound() throws {
        let result = try sut.completeTodo(title: "Nonexistent task")

        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }

    // MARK: - List Todos

    func test_listTodos_returnsIncomplete() throws {
        _ = try sut.addTodo(title: "Task 1")
        _ = try sut.addTodo(title: "Task 2")
        _ = try sut.addTodo(title: "Task 3")

        let result = try sut.listTodos(includeCompleted: false)

        XCTAssertEqual(result.todos.count, 3)
    }

    func test_listTodos_excludesCompletedByDefault() throws {
        _ = try sut.addTodo(title: "Task 1")
        _ = try sut.addTodo(title: "Task 2")
        _ = try sut.completeTodo(title: "Task 1")

        let result = try sut.listTodos(includeCompleted: false)

        XCTAssertEqual(result.todos.count, 1)
        XCTAssertEqual(result.todos.first?.title, "Task 2")
    }

    func test_listTodos_canIncludeCompleted() throws {
        _ = try sut.addTodo(title: "Task 1")
        _ = try sut.addTodo(title: "Task 2")
        _ = try sut.completeTodo(title: "Task 1")

        let result = try sut.listTodos(includeCompleted: true)

        XCTAssertEqual(result.todos.count, 2)
    }

    // MARK: - AI Source Filtering

    func test_listTodos_canFilterBySource() throws {
        // Add AI todo
        _ = try sut.addTodo(title: "AI Task")

        // Add user todo directly
        _ = try todoRepo.create(title: "User Task", source: .user)

        let aiTodos = try todoRepo.fetchBySource(.ai)
        XCTAssertEqual(aiTodos.count, 1)
        XCTAssertEqual(aiTodos.first?.title, "AI Task")
    }
}
