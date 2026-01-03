import XCTest
import SwiftData
@testable import CalmMind

final class TodoItemTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: TodoItem.self, configurations: config)
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Creation

    func test_createTodo_withTitle() {
        let todo = TodoItem(title: "Buy groceries")

        XCTAssertEqual(todo.title, "Buy groceries")
    }

    func test_createTodo_setsCreatedDate() {
        let before = Date()
        let todo = TodoItem(title: "Test")
        let after = Date()

        XCTAssertGreaterThanOrEqual(todo.createdAt, before)
        XCTAssertLessThanOrEqual(todo.createdAt, after)
    }

    func test_createTodo_isNotCompletedByDefault() {
        let todo = TodoItem(title: "Test")

        XCTAssertFalse(todo.isCompleted)
        XCTAssertNil(todo.completedAt)
    }

    func test_createTodo_sourceDefaultsToUser() {
        let todo = TodoItem(title: "Test")

        XCTAssertEqual(todo.source, .user)
    }

    // MARK: - Completion

    func test_markComplete_setsCompletedDate() {
        let todo = TodoItem(title: "Test")

        todo.markCompleted()

        XCTAssertTrue(todo.isCompleted)
        XCTAssertNotNil(todo.completedAt)
    }

    func test_markIncomplete_clearsCompletedDate() {
        let todo = TodoItem(title: "Test")
        todo.markCompleted()

        todo.markIncomplete()

        XCTAssertFalse(todo.isCompleted)
        XCTAssertNil(todo.completedAt)
    }

    // MARK: - Source

    func test_aiExtractedTodos_markedAsAISource() {
        let todo = TodoItem(title: "AI suggestion", source: .ai)

        XCTAssertEqual(todo.source, .ai)
    }

    func test_userCreatedTodos_markedAsUserSource() {
        let todo = TodoItem(title: "User task", source: .user)

        XCTAssertEqual(todo.source, .user)
    }

    // MARK: - Due Date

    func test_dueDate_defaultsToNil() {
        let todo = TodoItem(title: "Test")

        XCTAssertNil(todo.dueDate)
    }

    func test_dueDate_canBeSet() {
        let todo = TodoItem(title: "Test")
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        todo.dueDate = tomorrow

        XCTAssertNotNil(todo.dueDate)
    }

    // MARK: - Persistence

    func test_todo_persistsToSwiftData() throws {
        let todo = TodoItem(title: "Persisted")
        context.insert(todo)
        try context.save()

        let descriptor = FetchDescriptor<TodoItem>()
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Persisted")
    }

    // MARK: - Queries

    func test_fetchIncompleteTodos() throws {
        let todo1 = TodoItem(title: "Incomplete 1")
        let todo2 = TodoItem(title: "Complete")
        let todo3 = TodoItem(title: "Incomplete 2")

        todo2.markCompleted()

        context.insert(todo1)
        context.insert(todo2)
        context.insert(todo3)
        try context.save()

        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted }
        )
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 2)
    }

    func test_fetchAIExtractedTodos() throws {
        let todo1 = TodoItem(title: "User task", source: .user)
        let todo2 = TodoItem(title: "AI task", source: .ai)
        let todo3 = TodoItem(title: "Another AI task", source: .ai)

        context.insert(todo1)
        context.insert(todo2)
        context.insert(todo3)
        try context.save()

        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.sourceRaw == "ai" }
        )
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 2)
    }
}
