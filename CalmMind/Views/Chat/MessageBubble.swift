import SwiftUI

/// A single message bubble in the chat
struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool {
        message.role == .user
    }

    private var bubbleColor: Color {
        isUser ? Color.blue : Color(.systemGray6)
    }

    private var textColor: Color {
        isUser ? .white : .primary
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .foregroundColor(textColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(bubbleColor)
                    .clipShape(ChatBubbleShape(isUser: isUser))

                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }

            if !isUser {
                Spacer(minLength: 60)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Custom bubble shape with tail
struct ChatBubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailSize: CGFloat = 6

        var path = Path()

        if isUser {
            // User bubble - tail on right
            path.addRoundedRect(
                in: CGRect(x: 0, y: 0, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )
            // Tail
            path.move(to: CGPoint(x: rect.width - tailSize, y: rect.height - 20))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - 10))
            path.addLine(to: CGPoint(x: rect.width - tailSize, y: rect.height - 10))
        } else {
            // Assistant bubble - tail on left
            path.addRoundedRect(
                in: CGRect(x: tailSize, y: 0, width: rect.width - tailSize, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )
            // Tail
            path.move(to: CGPoint(x: tailSize, y: rect.height - 20))
            path.addLine(to: CGPoint(x: 0, y: rect.height - 10))
            path.addLine(to: CGPoint(x: tailSize, y: rect.height - 10))
        }

        return path
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubble(message: ChatMessage(content: "Hello! How are you feeling today?", role: .assistant))
        MessageBubble(message: ChatMessage(content: "I'm feeling a bit stressed about work.", role: .user))
        MessageBubble(message: ChatMessage(content: "I understand. Work stress can be challenging. Would you like to talk about what's been causing the stress?", role: .assistant))
    }
    .padding()
}
