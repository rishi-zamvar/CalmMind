import Foundation
import SwiftData

/// Repository for managing TodoItem entities
final class TodoRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Create

    /// Creates a new todo item with the specified title and source
    @discardableResult
    func create(title: String, source: TodoSource = .user) throws -> TodoItem {
        let todo = TodoItem(title: title, source: source)
        context.insert(todo)
        try context.save()
        return todo
    }

    // MARK: - Update

    /// Marks a todo as completed
    func complete(_ todo: TodoItem) throws {
        todo.markCompleted()
        try context.save()
    }

    /// Marks a todo as incomplete
    func uncomplete(_ todo: TodoItem) throws {
        todo.markIncomplete()
        try context.save()
    }

    // MARK: - Delete

    /// Deletes a todo from the store
    func delete(_ todo: TodoItem) throws {
        context.delete(todo)
        try context.save()
    }

    // MARK: - Fetch

    /// Fetches all todos
    func fetchAll() throws -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetches incomplete todos ordered by creation date
    func fetchIncomplete() throws -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetches completed todos ordered by completion date
    func fetchCompleted() throws -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.isCompleted },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetches todos by source (user or AI)
    func fetchBySource(_ source: TodoSource) throws -> [TodoItem] {
        let sourceRaw = source.rawValue
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { $0.sourceRaw == sourceRaw },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }
}
