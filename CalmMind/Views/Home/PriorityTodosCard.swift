import SwiftUI
import SwiftData

/// Card showing top 3 priority todos
struct PriorityTodosCard: View {
    let todos: [TodoItem]
    let onComplete: (TodoItem) -> Void
    let onTapTodo: () -> Void
    let onAddTodo: () -> Void

    /// Get top 3 todos with deterministic sorting
    private var topThree: [TodoItem] {
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

    var body: some View {
        AmbientCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                CardHeader(
                    title: WarmCopy.todosCardTitle,
                    subtitle: WarmCopy.todosCardSubtitle
                )

                // Todos or empty state
                if topThree.isEmpty {
                    emptyState
                } else {
                    todosList
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("priorityTodosCard")
    }

    private var todosList: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                ForEach(topThree) { todo in
                    PriorityTodoRow(
                        todo: todo,
                        onComplete: { onComplete(todo) },
                        onTap: onTapTodo
                    )
                }
            }

            // Footer CTAs
            footerCTAs
        }
    }

    private var footerCTAs: some View {
        HStack(spacing: 16) {
            Button(action: onTapTodo) {
                Text(WarmCopy.viewAllTodos)
            }
            Text("·")
                .foregroundColor(DesignTokens.Colors.textTertiary)
            Button(action: onAddTodo) {
                Text(WarmCopy.addTask)
            }
        }
        .font(DesignTokens.Typography.meta)
        .foregroundColor(DesignTokens.Colors.warmClay)
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        Button(action: onAddTodo) {
            Text(WarmCopy.emptyTodosHome)
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.cardPad)
        }
        .buttonStyle(ScalePressStyle())
    }
}

#Preview {
    VStack(spacing: 20) {
        // With todos
        PriorityTodosCard(
            todos: [
                TodoItem(title: "Submit CYA form", priority: .high),
                TodoItem(title: "Finish lab notes", priority: .medium),
                TodoItem(title: "Book airport ride", priority: .low)
            ],
            onComplete: { _ in },
            onTapTodo: {},
            onAddTodo: {}
        )

        // Empty state
        PriorityTodosCard(
            todos: [],
            onComplete: { _ in },
            onTapTodo: {},
            onAddTodo: {}
        )
    }
    .padding()
    .ambientBackground()
}
