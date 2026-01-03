import SwiftUI

/// Input bar for composing and sending messages
struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    let canSend: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Text input
            TextField("Message", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($isFocused)
                .disabled(isLoading)
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }

            // Send button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(canSend ? .blue : .gray)
            }
            .disabled(!canSend)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

#Preview {
    VStack {
        Spacer()

        ChatInputBar(
            text: .constant(""),
            isLoading: false,
            canSend: false,
            onSend: {}
        )

        ChatInputBar(
            text: .constant("Hello"),
            isLoading: false,
            canSend: true,
            onSend: {}
        )

        ChatInputBar(
            text: .constant("Sending..."),
            isLoading: true,
            canSend: false,
            onSend: {}
        )
    }
}
