import XCTest
@testable import CalmMind

/// Tests for PriorityTodosCard sorting contract
/// Verifies deterministic sorting: Priority > DueDate > CreatedAt > UUID
final class PriorityTodosCardTests: XCTestCase {

    // MARK: - Helper

    /// Extracts top 3 todos using the same logic as PriorityTodosCard
    private func topThree(from todos: [TodoItem]) -> [TodoItem] {
        todos
            .filter { !$0.isCompleted }
            .sorted { a, b in
                // Primary: priority (high to low)
                if a.priority != b.priority {
                    return a.priority.rawValue > b.priority.rawValue
                }
                // Secondary: due date (earlier first, nil last)
                if a.dueDate != b.dueDate {
                    return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
                }
                // Tertiary: created date (older first)
                if a.createdAt != b.createdAt {
                    return a.createdAt < b.createdAt
                }
                // Stable tie-breaker: UUID
                return a.id.uuidString < b.id.uuidString
            }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Max Three Items

    func test_topThree_returnsMaxThreeItems() {
        let todos = [
            TodoItemTestFactory.create(title: "Task 1", priority: .high),
            TodoItemTestFactory.create(title: "Task 2", priority: .high),
            TodoItemTestFactory.create(title: "Task 3", priority: .high),
            TodoItemTestFactory.create(title: "Task 4", priority: .high),
            TodoItemTestFactory.create(title: "Task 5", priority: .high)
        ]

        let result = topThree(from: todos)

        XCTAssertEqual(result.count, 3)
    }

    func test_exactlyThreeTodos_returnsAll() {
        let todos = [
            TodoItemTestFactory.create(title: "Task 1", priority: .high),
            TodoItemTestFactory.create(title: "Task 2", priority: .medium),
            TodoItemTestFactory.create(title: "Task 3", priority: .low)
        ]

        let result = topThree(from: todos)

        XCTAssertEqual(result.count, 3)
    }

    func test_lessThanThreeTodos_returnsAll() {
        let todos = [
            TodoItemTestFactory.create(title: "Task 1", priority: .high),
            TodoItemTestFactory.create(title: "Task 2", priority: .medium)
        ]

        let result = topThree(from: todos)

        XCTAssertEqual(result.count, 2)
    }

    // MARK: - Excludes Completed

    func test_topThree_excludesCompletedTodos() {
        let todos = [
            TodoItemTestFactory.create(title: "Completed", priority: .high, isCompleted: true),
            TodoItemTestFactory.create(title: "Incomplete", priority: .low)
        ]

        let result = topThree(from: todos)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "Incomplete")
    }

    func test_allCompleted_returnsEmptyList() {
        let todos = [
            TodoItemTestFactory.create(title: "Completed 1", isCompleted: true),
            TodoItemTestFactory.create(title: "Completed 2", isCompleted: true)
        ]

        let result = topThree(from: todos)

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Priority Sorting

    func test_topThree_sortsByPriority_highFirst() {
        let baseDate = TestCalendar.createDate(year: 2025, month: 1, day: 15)

        let todos = [
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid1,
                title: "Low Priority",
                priority: .low,
                createdAt: baseDate
            ),
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid2,
                title: "High Priority",
                priority: .high,
                createdAt: baseDate
            ),
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid3,
                title: "Medium Priority",
                priority: .medium,
                createdAt: baseDate
            )
        ]

        let result = topThree(from: todos)

        XCTAssertEqual(result[0].title, "High Priority")
        XCTAssertEqual(result[1].title, "Medium Priority")
        XCTAssertEqual(result[2].title, "Low Priority")
    }

    func test_topThree_priorityOrder_highMediumLowNone() {
        let baseDate = TestCalendar.createDate(year: 2025, month: 1, day: 15)

        let todos = [
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid1,
                title: "None",
                priority: .none,
                createdAt: baseDate
            ),
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid2,
                title: "High",
                priority: .high,
                createdAt: baseDate
            ),
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid3,
                title: "Low",
                priority: .low,
                createdAt: baseDate
            ),
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid4,
                title: "Medium",
                priority: .medium,
                createdAt: baseDate
            )
        ]

        let result = topThree(from: todos)

        XCTAssertEqual(result[0].title, "High")
        XCTAssertEqual(result[1].title, "Medium")
        XCTAssertEqual(result[2].title, "Low")
        // "None" should be excluded (only top 3)
    }

    // MARK: - Due Date Sorting

    func test_topThree_samePriority_sortsByDueDate_earlierFirst() {
        let baseDate = TestCalendar.createDate(year: 2025, month: 1, day: 15)
        let earlyDue = TestCalendar.createDate(year: 2025, month: 1, day: 16)
        let lateDue = TestCalendar.createDate(year: 2025, month: 1, day: 20)

        let todos = [
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid1,
                title: "Late Due",
                priority: .high,
                dueDate: lateDue,
                createdAt: baseDate
            ),
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid2,
                title: "Early Due",
                priority: .high,
                dueDate: earlyDue,
                createdAt: baseDate
            )
        ]

        let result = topThree(from: todos)

        XCTAssertEqual(result[0].title, "Early Due")
        XCTAssertEqual(result[1].title, "Late Due")
    }

    func test_topThree_nilDueDate_sortsAfterDatedItems() {
        let baseDate = TestCalendar.createDate(year: 2025, month: 1, day: 15)
        let dueDate = TestCalendar.createDate(year: 2025, month: 1, day: 20)

        let todos = [
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid1,
                title: "No Due Date",
                priority: .high,
                dueDate: nil,
                createdAt: baseDate
            ),
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid2,
                title: "Has Due Date",
                priority: .high,
                dueDate: dueDate,
                createdAt: baseDate
            )
        ]

        let result = topThree(from: todos)

        XCTAssertEqual(result[0].title, "Has Due Date")
        XCTAssertEqual(result[1].title, "No Due Date")
    }

    // MARK: - Created Date Sorting

    func test_topThree_samePriorityAndDueDate_sortsByCreatedAt() {
        let earlierCreated = TestCalendar.createDate(year: 2025, month: 1, day: 10)
        let laterCreated = TestCalendar.createDate(year: 2025, month: 1, day: 15)

        let todos = [
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid1,
                title: "Later Created",
                priority: .high,
                createdAt: laterCreated
            ),
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid2,
                title: "Earlier Created",
                priority: .high,
                createdAt: earlierCreated
            )
        ]

        let result = topThree(from: todos)

        XCTAssertEqual(result[0].title, "Earlier Created")
        XCTAssertEqual(result[1].title, "Later Created")
    }

    // MARK: - UUID Tie-Breaker

    func test_topThree_stableTieBreaker_usesUUID_lexicographic() {
        let sameDate = TestCalendar.createDate(year: 2025, month: 1, day: 15)

        let todos = [
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid3,
                title: "UUID 3",
                priority: .high,
                createdAt: sameDate
            ),
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid1,
                title: "UUID 1",
                priority: .high,
                createdAt: sameDate
            ),
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid2,
                title: "UUID 2",
                priority: .high,
                createdAt: sameDate
            )
        ]

        let result = topThree(from: todos)

        // Lexicographic order: uuid1 < uuid2 < uuid3
        XCTAssertEqual(result[0].title, "UUID 1")
        XCTAssertEqual(result[1].title, "UUID 2")
        XCTAssertEqual(result[2].title, "UUID 3")
    }

    // MARK: - Determinism Verification

    func test_topThree_multipleCallsReturnSameOrder() {
        let baseDate = TestCalendar.createDate(year: 2025, month: 1, day: 15)

        let todos = [
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid1,
                title: "Task A",
                priority: .high,
                createdAt: baseDate
            ),
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid2,
                title: "Task B",
                priority: .high,
                createdAt: baseDate
            ),
            TodoItemTestFactory.createWithFixedUUID(
                TodoItemTestFactory.FixedUUIDs.uuid3,
                title: "Task C",
                priority: .high,
                createdAt: baseDate
            )
        ]

        // Run multiple times
        for _ in 0..<100 {
            let result = topThree(from: todos)
            XCTAssertEqual(result[0].title, "Task A")
            XCTAssertEqual(result[1].title, "Task B")
            XCTAssertEqual(result[2].title, "Task C")
        }
    }

    func test_topThree_shuffledInput_returnsSameOrder() {
        let baseDate = TestCalendar.createDate(year: 2025, month: 1, day: 15)

        let todoA = TodoItemTestFactory.createWithFixedUUID(
            TodoItemTestFactory.FixedUUIDs.uuid1,
            title: "Task A",
            priority: .high,
            createdAt: baseDate
        )
        let todoB = TodoItemTestFactory.createWithFixedUUID(
            TodoItemTestFactory.FixedUUIDs.uuid2,
            title: "Task B",
            priority: .medium,
            createdAt: baseDate
        )
        let todoC = TodoItemTestFactory.createWithFixedUUID(
            TodoItemTestFactory.FixedUUIDs.uuid3,
            title: "Task C",
            priority: .low,
            createdAt: baseDate
        )

        // Different input orders
        let orders: [[TodoItem]] = [
            [todoA, todoB, todoC],
            [todoC, todoB, todoA],
            [todoB, todoC, todoA],
            [todoA, todoC, todoB]
        ]

        for todos in orders {
            let result = topThree(from: todos)
            XCTAssertEqual(result[0].title, "Task A", "High priority should be first")
            XCTAssertEqual(result[1].title, "Task B", "Medium priority should be second")
            XCTAssertEqual(result[2].title, "Task C", "Low priority should be third")
        }
    }

    // MARK: - Empty State

    func test_emptyList_returnsEmpty() {
        let result = topThree(from: [])
        XCTAssertTrue(result.isEmpty)
    }
}
