import Foundation

// MARK: - Todo Fingerprint (for dedupe)

/// Fingerprint for deduplicating todos within a day
struct TodoFingerprint: Hashable {
    let normalizedTitle: String  // lowercase, trimmed, punctuation removed
    let dateWindow: Date         // rounded to start of day

    init(title: String, date: Date) {
        // Normalize: lowercase, remove punctuation, trim
        self.normalizedTitle = title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // Round to start of day
        self.dateWindow = Calendar.current.startOfDay(for: date)
    }
}

// MARK: - Result Types

/// Reason a todo was skipped
enum TodoSkipReason: Sendable {
    case duplicate
    case hypothetical
    case autoCreateDisabled
}

/// Result of a todo tool operation
struct TodoToolResult: Sendable {
    let success: Bool
    let todoId: String?
    let error: String?
    let message: String?
    let skipReason: TodoSkipReason?
    let undoAction: (@Sendable () -> Void)?

    static func success(id: String? = nil, message: String? = nil, undoAction: (@Sendable () -> Void)? = nil) -> TodoToolResult {
        TodoToolResult(success: true, todoId: id, error: nil, message: message, skipReason: nil, undoAction: undoAction)
    }

    static func skipped(reason: TodoSkipReason, message: String) -> TodoToolResult {
        TodoToolResult(success: false, todoId: nil, error: nil, message: message, skipReason: reason, undoAction: nil)
    }

    static func failure(_ error: String) -> TodoToolResult {
        TodoToolResult(success: false, todoId: nil, error: error, message: nil, skipReason: nil, undoAction: nil)
    }
}

/// Result of listing todos
struct TodoListResult: Sendable {
    let todos: [TodoSummary]
    let totalCount: Int
}

/// Summary of a todo for tool responses
struct TodoSummary: Sendable {
    let id: String
    let title: String
    let isCompleted: Bool
    let dueDate: Date?
    let source: TodoSource
}

/// Tools for managing todos via AI function calls
final class TodoTools {

    // MARK: - Dependencies

    private let todoRepository: TodoRepository
    private let normalizer: TodoTitleNormalizer
    private let clock: any DateClock

    // MARK: - Dedupe State

    /// Recent fingerprints for deduplication (per-day)
    private var recentFingerprints: Set<TodoFingerprint> = []

    /// Day the fingerprints are valid for
    private var fingerprintDay: Date?

    // MARK: - Initialization

    init(
        todoRepository: TodoRepository,
        normalizer: TodoTitleNormalizer = TodoTitleNormalizer(),
        clock: any DateClock = SystemClock()
    ) {
        self.todoRepository = todoRepository
        self.normalizer = normalizer
        self.clock = clock
    }

    // MARK: - Reset

    /// Reset fingerprints (for testing or new day)
    func resetFingerprints() {
        recentFingerprints.removeAll()
        fingerprintDay = nil
    }

    // MARK: - Add Todo

    /// Add a new todo item with deduplication
    func addTodo(title: String, dueDate: Date? = nil) throws -> TodoToolResult {
        // Validate
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure("Title cannot be empty")
        }

        // Reset fingerprints if day changed
        let today = calendar.startOfDay(for: clock.now)
        if fingerprintDay != today {
            recentFingerprints.removeAll()
            fingerprintDay = today
        }

        // Check for duplicate
        let fingerprint = TodoFingerprint(title: trimmed, date: clock.now)
        if recentFingerprints.contains(fingerprint) {
            return .skipped(reason: .duplicate, message: "Already added today: \(trimmed)")
        }

        // Normalize title
        let normalized = normalizer.normalize(trimmed)

        // Create todo with AI source
        let todo = try todoRepository.create(
            title: normalized.title,
            source: .ai
        )

        // Set due date (from parameter or extracted from title)
        todo.dueDate = dueDate ?? normalized.extractedDueDate

        // Add to fingerprints
        recentFingerprints.insert(fingerprint)

        // Create undo action
        let todoId = todo.id
        let undoAction: @Sendable () -> Void = { [weak self] in
            try? self?.deleteTodo(id: todoId)
        }

        return .success(
            id: todo.id.uuidString,
            message: "Added: \(todo.title)",
            undoAction: undoAction
        )
    }

    /// Delete a todo by ID (for undo)
    private func deleteTodo(id: UUID) throws {
        let todos = try todoRepository.fetchIncomplete() + todoRepository.fetchCompleted()
        if let todo = todos.first(where: { $0.id == id }) {
            try todoRepository.delete(todo)
        }
    }

    private var calendar: Calendar { .current }

    // MARK: - Complete Todo

    /// Mark a todo as complete by title (fuzzy match) or ID
    func completeTodo(title: String? = nil, id: String? = nil) throws -> TodoToolResult {
        var todoToComplete: TodoItem?

        // Find by ID first
        if let idString = id, let uuid = UUID(uuidString: idString) {
            let todos = try todoRepository.fetchIncomplete()
            todoToComplete = todos.first { $0.id == uuid }
        }

        // If not found by ID, try fuzzy match by title
        if todoToComplete == nil, let searchTitle = title {
            let todos = try todoRepository.fetchIncomplete()
            todoToComplete = fuzzyMatch(searchTitle, in: todos)
        }

        guard let todo = todoToComplete else {
            return .failure("Todo not found")
        }

        try todoRepository.complete(todo)
        return .success(id: todo.id.uuidString, message: "Completed: \(todo.title)")
    }

    // MARK: - List Todos

    /// List todos
    func listTodos(includeCompleted: Bool = false) throws -> TodoListResult {
        let todos: [TodoItem]

        if includeCompleted {
            let incomplete = try todoRepository.fetchIncomplete()
            let completed = try todoRepository.fetchCompleted()
            todos = incomplete + completed
        } else {
            todos = try todoRepository.fetchIncomplete()
        }

        let summaries = todos.map { todo in
            TodoSummary(
                id: todo.id.uuidString,
                title: todo.title,
                isCompleted: todo.isCompleted,
                dueDate: todo.dueDate,
                source: todo.source
            )
        }

        return TodoListResult(todos: summaries, totalCount: summaries.count)
    }

    // MARK: - Private

    /// Fuzzy match a search string against todos
    private func fuzzyMatch(_ search: String, in todos: [TodoItem]) -> TodoItem? {
        let normalizedSearch = search.lowercased()
            .replacingOccurrences(of: "the ", with: "")
            .replacingOccurrences(of: "a ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Exact match first
        if let exact = todos.first(where: { $0.title.lowercased() == normalizedSearch }) {
            return exact
        }

        // Contains match
        if let contains = todos.first(where: { $0.title.lowercased().contains(normalizedSearch) }) {
            return contains
        }

        // Reverse contains (search contains todo title)
        if let reverse = todos.first(where: { normalizedSearch.contains($0.title.lowercased()) }) {
            return reverse
        }

        // Word overlap match
        let searchWords = Set(normalizedSearch.components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        var bestMatch: (todo: TodoItem, score: Int)?

        for todo in todos {
            let todoWords = Set(todo.title.lowercased().components(separatedBy: .whitespaces).filter { !$0.isEmpty })
            let overlap = searchWords.intersection(todoWords).count

            if overlap > 0 {
                if bestMatch == nil || overlap > bestMatch!.score {
                    bestMatch = (todo, overlap)
                }
            }
        }

        return bestMatch?.todo
    }
}
