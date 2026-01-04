import SwiftUI

/// Input bar for composing and sending messages
struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    let canSend: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Text input
            TextField("What's on your mind?", text: $text, axis: .vertical)
                .font(DesignTokens.Typography.body)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(DesignTokens.Colors.subtleSection)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radii.button))
                .focused(isFocused)
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
                    .foregroundColor(canSend ? DesignTokens.Colors.warmClay : DesignTokens.Colors.textTertiary)
            }
            .disabled(!canSend)
            .accessibilityLabel("Send message")
            .animation(DesignTokens.defaultAnimation, value: canSend)
        }
        .padding(.horizontal, DesignTokens.Spacing.screenPad)
        .padding(.vertical, DesignTokens.Spacing.rowPadV)
        .background(DesignTokens.Colors.appBackground)
    }
}

// Preview wrapper to provide FocusState
struct ChatInputBarPreview: View {
    @FocusState private var isFocused: Bool
    @State private var text = ""

    var body: some View {
        VStack {
            Spacer()
            ChatInputBar(
                text: $text,
                isLoading: false,
                canSend: !text.isEmpty,
                isFocused: $isFocused,
                onSend: {}
            )
        }
        .ambientBackground()
    }
}

#Preview {
    ChatInputBarPreview()
}
