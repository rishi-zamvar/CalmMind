import Foundation
import SwiftData
import Observation

/// ViewModel for the todo list interface
@MainActor
@Observable
final class TodoViewModel {

    // MARK: - Published State

    /// Incomplete todos
    private(set) var incompleteTodos: [TodoItem] = []

    /// Completed todos
    private(set) var completedTodos: [TodoItem] = []

    /// New todo input text
    var newTodoTitle: String = ""

    /// Whether an operation is in progress
    private(set) var isLoading: Bool = false

    /// Error message if any
    private(set) var errorMessage: String?

    /// Whether to show error
    var showError: Bool = false

    // MARK: - Computed Properties

    /// Whether there are incomplete todos
    var hasIncompleteTodos: Bool {
        !incompleteTodos.isEmpty
    }

    /// Whether the add button should be enabled
    var canAdd: Bool {
        !newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Dependencies

    private let todoRepository: TodoRepository

    // MARK: - Initialization

    init(todoRepository: TodoRepository) {
        self.todoRepository = todoRepository
    }

    // MARK: - Loading

    /// Load all todos from the repository
    func loadTodos() async {
        do {
            incompleteTodos = try todoRepository.fetchIncomplete()
            completedTodos = try todoRepository.fetchCompleted()
        } catch {
            errorMessage = "Failed to load todos: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Adding

    /// Add a new todo from the input field
    func addTodo() async {
        let trimmedTitle = newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            return
        }

        do {
            _ = try todoRepository.create(title: trimmedTitle, source: .user)
            newTodoTitle = ""
            await loadTodos()
        } catch {
            errorMessage = "Failed to add todo: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Completing

    /// Mark a todo as complete
    func completeTodo(_ todo: TodoItem) async {
        do {
            try todoRepository.complete(todo)
            await loadTodos()
        } catch {
            errorMessage = "Failed to complete todo: \(error.localizedDescription)"
            showError = true
        }
    }

    /// Mark a todo as incomplete
    func uncompleteTodo(_ todo: TodoItem) async {
        do {
            try todoRepository.uncomplete(todo)
            await loadTodos()
        } catch {
            errorMessage = "Failed to uncomplete todo: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Deleting

    /// Delete a todo
    func deleteTodo(_ todo: TodoItem) async {
        do {
            try todoRepository.delete(todo)
            await loadTodos()
        } catch {
            errorMessage = "Failed to delete todo: \(error.localizedDescription)"
            showError = true
        }
    }

    // MARK: - Error Handling

    /// Dismiss the current error
    func dismissError() {
        showError = false
        errorMessage = nil
    }
}
