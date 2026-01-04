import SwiftUI

/// Todo row for Home screen with priority dot
struct PriorityTodoRow: View {
    let todo: TodoItem
    let onComplete: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            WarmCheckbox(isChecked: todo.isCompleted, action: onComplete)

            Text(todo.title)
                .font(DesignTokens.Typography.body)
                .foregroundColor(
                    todo.isCompleted
                        ? DesignTokens.Colors.textTertiary
                        : DesignTokens.Colors.textPrimary
                )
                .lineLimit(1)
                .strikethrough(todo.isCompleted, color: DesignTokens.Colors.textTertiary)

            Spacer()

            if todo.priority != .none {
                Circle()
                    .fill(priorityColor(todo.priority))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.rowPadV)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private func priorityColor(_ priority: TodoPriority) -> Color {
        switch priority {
        case .high: return DesignTokens.Colors.warmClay
        case .medium: return DesignTokens.Colors.duskBlue
        case .low: return DesignTokens.Colors.sage
        case .none: return .clear
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        PriorityTodoRow(
            todo: {
                let todo = TodoItem(title: "Submit CYA form", priority: .high)
                return todo
            }(),
            onComplete: {},
            onTap: {}
        )

        PriorityTodoRow(
            todo: {
                let todo = TodoItem(title: "Finish lab notes", priority: .medium)
                return todo
            }(),
            onComplete: {},
            onTap: {}
        )

        PriorityTodoRow(
            todo: {
                let todo = TodoItem(title: "Book airport ride", priority: .low)
                return todo
            }(),
            onComplete: {},
            onTap: {}
        )
    }
    .padding()
    .background(DesignTokens.Colors.elevatedSurface)
    .cornerRadius(DesignTokens.Radii.card)
    .padding()
    .ambientBackground()
}
