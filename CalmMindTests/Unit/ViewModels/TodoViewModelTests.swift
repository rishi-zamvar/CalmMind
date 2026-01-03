import XCTest
import SwiftData
@testable import CalmMind

@MainActor
final class TodoViewModelTests: XCTestCase {

    var sut: TodoViewModel!
    var container: ModelContainer!
    var todoRepo: TodoRepository!

    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: TodoItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        todoRepo = TodoRepository(context: container.mainContext)
        sut = TodoViewModel(todoRepository: todoRepo)
    }

    override func tearDown() {
        sut = nil
        todoRepo = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Loading Todos

    func test_loadTodos_loadsIncompleteTodos() async throws {
        // Create some todos
        _ = try todoRepo.create(title: "Task 1", source: .user)
        _ = try todoRepo.create(title: "Task 2", source: .user)

        await sut.loadTodos()

        XCTAssertEqual(sut.incompleteTodos.count, 2)
    }

    func test_loadTodos_separatesCompletedTodos() async throws {
        // Create todos
        let todo1 = try todoRepo.create(title: "Incomplete", source: .user)
        let todo2 = try todoRepo.create(title: "Complete", source: .user)
        try todoRepo.complete(todo2)

        await sut.loadTodos()

        XCTAssertEqual(sut.incompleteTodos.count, 1)
        XCTAssertEqual(sut.completedTodos.count, 1)
        XCTAssertEqual(sut.incompleteTodos.first?.title, "Incomplete")
        XCTAssertEqual(sut.completedTodos.first?.title, "Complete")
    }

    func test_loadTodos_ordersChronologically() async throws {
        // Create in specific order
        _ = try todoRepo.create(title: "First", source: .user)
        _ = try todoRepo.create(title: "Second", source: .user)
        _ = try todoRepo.create(title: "Third", source: .user)

        await sut.loadTodos()

        XCTAssertEqual(sut.incompleteTodos[0].title, "First")
        XCTAssertEqual(sut.incompleteTodos[1].title, "Second")
        XCTAssertEqual(sut.incompleteTodos[2].title, "Third")
    }

    // MARK: - Adding Todos

    func test_addTodo_createsItem() async throws {
        sut.newTodoTitle = "New task"

        await sut.addTodo()

        let todos = try todoRepo.fetchIncomplete()
        XCTAssertEqual(todos.count, 1)
        XCTAssertEqual(todos.first?.title, "New task")
    }

    func test_addTodo_marksAsUserSource() async throws {
        sut.newTodoTitle = "User task"

        await sut.addTodo()

        let todos = try todoRepo.fetchIncomplete()
        XCTAssertEqual(todos.first?.source, .user)
    }

    func test_addTodo_clearsInputField() async throws {
        sut.newTodoTitle = "Task to add"

        await sut.addTodo()

        XCTAssertEqual(sut.newTodoTitle, "")
    }

    func test_addTodo_updatesIncompleteTodos() async throws {
        sut.newTodoTitle = "New task"

        await sut.addTodo()

        XCTAssertEqual(sut.incompleteTodos.count, 1)
        XCTAssertEqual(sut.incompleteTodos.first?.title, "New task")
    }

    func test_addTodo_ignoresEmptyTitle() async throws {
        sut.newTodoTitle = ""

        await sut.addTodo()

        XCTAssertEqual(sut.incompleteTodos.count, 0)
    }

    func test_addTodo_ignoresWhitespaceOnlyTitle() async throws {
        sut.newTodoTitle = "   "

        await sut.addTodo()

        XCTAssertEqual(sut.incompleteTodos.count, 0)
    }

    // MARK: - Completing Todos

    func test_completeTodo_movesToCompleted() async throws {
        _ = try todoRepo.create(title: "Task to complete", source: .user)
        await sut.loadTodos()

        let todo = sut.incompleteTodos.first!
        await sut.completeTodo(todo)

        XCTAssertEqual(sut.incompleteTodos.count, 0)
        XCTAssertEqual(sut.completedTodos.count, 1)
    }

    func test_completeTodo_setsCompletedDate() async throws {
        _ = try todoRepo.create(title: "Task", source: .user)
        await sut.loadTodos()

        let todo = sut.incompleteTodos.first!
        await sut.completeTodo(todo)

        XCTAssertNotNil(sut.completedTodos.first?.completedAt)
    }

    func test_uncompleteTodo_movesBackToIncomplete() async throws {
        let todo = try todoRepo.create(title: "Completed task", source: .user)
        try todoRepo.complete(todo)
        await sut.loadTodos()

        let completedTodo = sut.completedTodos.first!
        await sut.uncompleteTodo(completedTodo)

        XCTAssertEqual(sut.incompleteTodos.count, 1)
        XCTAssertEqual(sut.completedTodos.count, 0)
    }

    // MARK: - Deleting Todos

    func test_deleteTodo_removesFromList() async throws {
        _ = try todoRepo.create(title: "Task to delete", source: .user)
        await sut.loadTodos()

        let todo = sut.incompleteTodos.first!
        await sut.deleteTodo(todo)

        XCTAssertEqual(sut.incompleteTodos.count, 0)
    }

    func test_deleteTodo_removesFromDatabase() async throws {
        _ = try todoRepo.create(title: "Task", source: .user)
        await sut.loadTodos()

        let todo = sut.incompleteTodos.first!
        await sut.deleteTodo(todo)

        let all = try todoRepo.fetchIncomplete()
        XCTAssertEqual(all.count, 0)
    }

    // MARK: - AI vs User Todos

    func test_aiTodos_distinguishable() async throws {
        _ = try todoRepo.create(title: "User task", source: .user)
        _ = try todoRepo.create(title: "AI task", source: .ai)
        await sut.loadTodos()

        let userTodos = sut.incompleteTodos.filter { $0.source == .user }
        let aiTodos = sut.incompleteTodos.filter { $0.source == .ai }

        XCTAssertEqual(userTodos.count, 1)
        XCTAssertEqual(aiTodos.count, 1)
    }

    // MARK: - Computed Properties

    func test_hasIncompleteTodos_true() async throws {
        _ = try todoRepo.create(title: "Task", source: .user)
        await sut.loadTodos()

        XCTAssertTrue(sut.hasIncompleteTodos)
    }

    func test_hasIncompleteTodos_false() async throws {
        await sut.loadTodos()

        XCTAssertFalse(sut.hasIncompleteTodos)
    }

    func test_canAdd_falseWhenEmpty() {
        sut.newTodoTitle = ""
        XCTAssertFalse(sut.canAdd)
    }

    func test_canAdd_trueWhenHasContent() {
        sut.newTodoTitle = "Task"
        XCTAssertTrue(sut.canAdd)
    }
}
