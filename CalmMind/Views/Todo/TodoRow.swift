import SwiftUI

/// A single todo item row
struct TodoRow: View {
    let todo: TodoItem
    let onToggle: () -> Void

    private var isCompleted: Bool {
        todo.completedAt != nil
    }

    var body: some View {
        HStack(spacing: 12) {
            // Warm checkbox
            WarmCheckbox(isChecked: isCompleted) {
                onToggle()
            }

            // Title and metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(DesignTokens.Typography.body)
                    .strikethrough(isCompleted)
                    .foregroundColor(isCompleted ? DesignTokens.Colors.textTertiary : DesignTokens.Colors.textPrimary)

                HStack(spacing: 8) {
                    // Source badge
                    if todo.source == .ai {
                        AIBadge()
                    }

                    // Created date
                    Text(formatDate(todo.createdAt))
                        .font(DesignTokens.Typography.meta)
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(todo.title), \(isCompleted ? "completed" : "incomplete")")
        .accessibilityHint("Double tap to toggle")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Badge indicating AI-created todo (warm sage styling)
struct AIBadge: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "sparkles")
                .font(.caption2)
            Text("AI")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(DesignTokens.Colors.sage)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(DesignTokens.Colors.sage.opacity(0.15))
        .clipShape(Capsule())
    }
}

#Preview {
    List {
        TodoRow(
            todo: {
                let t = TodoItem(title: "Call doctor", source: .user)
                return t
            }(),
            onToggle: {}
        )

        TodoRow(
            todo: {
                let t = TodoItem(title: "Buy groceries", source: .ai)
                return t
            }(),
            onToggle: {}
        )

        TodoRow(
            todo: {
                let t = TodoItem(title: "Completed task", source: .user)
                t.completedAt = Date()
                return t
            }(),
            onToggle: {}
        )
    }
}
