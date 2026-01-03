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
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)

            // Title and metadata
            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .strikethrough(isCompleted)
                    .foregroundColor(isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    // Source badge
                    if todo.source == .ai {
                        AIBadge()
                    }

                    // Created date
                    Text(formatDate(todo.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
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

/// Badge indicating AI-created todo
struct AIBadge: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "sparkles")
                .font(.caption2)
            Text("AI")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.purple)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.purple.opacity(0.15))
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
