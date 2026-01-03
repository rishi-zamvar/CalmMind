import SwiftUI
import SwiftData

/// Main chat interface view
struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            TypingIndicator()
                                .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastId = viewModel.lastMessageId {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input bar
            ChatInputBar(
                text: $viewModel.inputText,
                isLoading: viewModel.isLoading,
                canSend: viewModel.canSend,
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                }
            )
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .task {
            await viewModel.loadSession()
        }
    }
}

/// Typing indicator shown while waiting for response
struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .offset(y: animationOffset(for: index))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                animationOffset = -4
            }
        }
    }

    private func animationOffset(for index: Int) -> CGFloat {
        // Stagger the animation for each dot
        let delay = Double(index) * 0.15
        return animationOffset * (1 - delay)
    }
}

#Preview {
    // Preview would need proper setup with ModelContainer
    Text("Chat View Preview")
}
