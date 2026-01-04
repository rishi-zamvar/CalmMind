import Foundation
@testable import CalmMind

/// Factory for creating TodoItems with controlled properties for testing
/// Allows deterministic testing by setting createdAt and other timestamps
enum TodoItemTestFactory {

    /// Creates a TodoItem with all properties explicitly set
    /// - Parameters:
    ///   - id: Fixed UUID (use for deterministic tie-breaking)
    ///   - title: The todo title
    ///   - priority: Priority level
    ///   - dueDate: Optional due date
    ///   - createdAt: Creation timestamp (for sorting tests)
    ///   - isCompleted: Whether the todo is completed
    ///   - completedAt: Completion timestamp (if completed)
    /// - Returns: A TodoItem with the specified properties
    static func create(
        id: UUID = UUID(),
        title: String,
        priority: TodoPriority = .none,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) -> TodoItem {
        let todo = TodoItem(
            id: id,
            title: title,
            isCompleted: isCompleted,
            dueDate: dueDate,
            source: .user,
            priority: priority
        )
        // Override createdAt (the model sets it to Date() in init)
        todo.createdAt = createdAt
        todo.completedAt = completedAt
        return todo
    }

    /// Creates a TodoItem with a fixed UUID string for deterministic sorting
    /// - Parameters:
    ///   - uuidString: A valid UUID string (e.g., "00000000-0000-0000-0000-000000000001")
    ///   - title: The todo title
    ///   - priority: Priority level
    ///   - dueDate: Optional due date
    ///   - createdAt: Creation timestamp
    ///   - isCompleted: Whether the todo is completed
    /// - Returns: A TodoItem with the specified fixed UUID
    static func createWithFixedUUID(
        _ uuidString: String,
        title: String,
        priority: TodoPriority = .none,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        isCompleted: Bool = false
    ) -> TodoItem {
        guard let uuid = UUID(uuidString: uuidString) else {
            fatalError("Invalid UUID string: \(uuidString)")
        }
        return create(
            id: uuid,
            title: title,
            priority: priority,
            dueDate: dueDate,
            createdAt: createdAt,
            isCompleted: isCompleted
        )
    }

    /// Fixed UUIDs for deterministic tie-breaking tests
    /// Lexicographically ordered: uuid1 < uuid2 < uuid3
    enum FixedUUIDs {
        static let uuid1 = "00000000-0000-0000-0000-000000000001"
        static let uuid2 = "00000000-0000-0000-0000-000000000002"
        static let uuid3 = "00000000-0000-0000-0000-000000000003"
        static let uuid4 = "00000000-0000-0000-0000-000000000004"
        static let uuid5 = "00000000-0000-0000-0000-000000000005"
    }
}
