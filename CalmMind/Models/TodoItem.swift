import Foundation
import SwiftData

/// Source of a todo item
enum TodoSource: String, Codable {
    case user   // Created manually by user
    case ai     // Extracted by AI from conversation
}

/// Priority level for a todo item
/// Explicit ordering (not relying on raw values)
enum TodoPriority: Int, Codable, Comparable, CaseIterable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    static func < (lhs: TodoPriority, rhs: TodoPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A todo/task item
@Model
final class TodoItem {

    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique)
    var id: UUID

    /// The todo title/description
    var title: String

    /// Whether the todo is completed
    var isCompleted: Bool

    /// When the todo was created
    var createdAt: Date

    /// When the todo was completed (nil if not completed)
    var completedAt: Date?

    /// Optional due date
    var dueDate: Date?

    /// Source of the todo (user-created or AI-extracted)
    var sourceRaw: String

    /// Priority level (stored as raw value)
    var priorityRaw: Int

    // MARK: - Computed Properties

    var priority: TodoPriority {
        get { TodoPriority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    var source: TodoSource {
        get { TodoSource(rawValue: sourceRaw) ?? .user }
        set { sourceRaw = newValue.rawValue }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        source: TodoSource = .user,
        priority: TodoPriority = .none
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.completedAt = nil
        self.dueDate = dueDate
        self.sourceRaw = source.rawValue
        self.priorityRaw = priority.rawValue
    }

    // MARK: - Actions

    /// Mark the todo as completed
    func markCompleted() {
        isCompleted = true
        completedAt = Date()
    }

    /// Mark the todo as incomplete
    func markIncomplete() {
        isCompleted = false
        completedAt = nil
    }
}
