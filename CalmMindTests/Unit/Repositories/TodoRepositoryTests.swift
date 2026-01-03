import XCTest
import SwiftData
@testable import CalmMind

final class TodoRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var sut: TodoRepository!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: TodoItem.self, configurations: config)
        context = ModelContext(container)
        sut = TodoRepository(context: context)
    }

    override func tearDown() {
        sut = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Create

    func test_createTodo_persistsToStore() throws {
        let todo = try sut.create(title: "Buy milk")

        XCTAssertNotNil(todo.id)
        XCTAssertEqual(todo.title, "Buy milk")
    }

    // MARK: - Complete

    func test_completeTodo_setsCompletedDate() throws {
        let todo = try sut.create(title: "Test")

        try sut.complete(todo)

        XCTAssertTrue(todo.isCompleted)
        XCTAssertNotNil(todo.completedAt)
    }

    // MARK: - Delete

    func test_deleteTodo_removesFromStore() throws {
        let todo = try sut.create(title: "Delete me")

        try sut.delete(todo)

        let all = try sut.fetchAll()
        XCTAssertEqual(all.count, 0)
    }

    // MARK: - Fetch

    func test_fetchIncompleteTodos_ordered() throws {
        let _ = try sut.create(title: "First")
        let complete = try sut.create(title: "Complete")
        let _ = try sut.create(title: "Third")

        try sut.complete(complete)

        let incomplete = try sut.fetchIncomplete()

        XCTAssertEqual(incomplete.count, 2)
    }

    func test_fetchCompletedTodos_ordered() throws {
        let todo1 = try sut.create(title: "Done 1")
        let _ = try sut.create(title: "Not done")
        let todo2 = try sut.create(title: "Done 2")

        try sut.complete(todo1)
        try sut.complete(todo2)

        let completed = try sut.fetchCompleted()

        XCTAssertEqual(completed.count, 2)
    }

    // MARK: - AI Source

    func test_createAITodo_markedAsAISource() throws {
        let todo = try sut.create(title: "AI suggestion", source: .ai)

        XCTAssertEqual(todo.source, .ai)
    }

    func test_fetchAITodos() throws {
        let _ = try sut.create(title: "User task", source: .user)
        let _ = try sut.create(title: "AI task 1", source: .ai)
        let _ = try sut.create(title: "AI task 2", source: .ai)

        let aiTodos = try sut.fetchBySource(.ai)

        XCTAssertEqual(aiTodos.count, 2)
    }
}
