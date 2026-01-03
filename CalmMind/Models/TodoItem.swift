import Foundation
import SwiftData

/// Source of a todo item
enum TodoSource: String, Codable {
    case user   // Created manually by user
    case ai     // Extracted by AI from conversation
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

    // MARK: - Computed Properties

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
        source: TodoSource = .user
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = Date()
        self.completedAt = nil
        self.dueDate = dueDate
        self.sourceRaw = source.rawValue
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
