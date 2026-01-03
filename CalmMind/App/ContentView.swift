import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    // Repositories
    private var sessionRepository: SessionRepository {
        SessionRepository(context: modelContext)
    }
    private var messageRepository: MessageRepository {
        MessageRepository(context: modelContext)
    }
    private var todoRepository: TodoRepository {
        TodoRepository(context: modelContext)
    }
    private var journalRepository: JournalRepository {
        JournalRepository(context: modelContext)
    }

    var body: some View {
        TabView {
            // Chat Tab
            NavigationStack {
                ChatTabView(
                    sessionRepository: sessionRepository,
                    messageRepository: messageRepository,
                    todoRepository: todoRepository,
                    journalRepository: journalRepository
                )
            }
            .tabItem {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
            }

            // Todos Tab
            NavigationStack {
                TodoTabView(todoRepository: todoRepository)
            }
            .tabItem {
                Label("Todos", systemImage: "checklist")
            }

            // Journal Tab
            NavigationStack {
                JournalTabView(journalRepository: journalRepository)
            }
            .tabItem {
                Label("Journal", systemImage: "book")
            }

            // Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

// MARK: - Tab Views

/// Chat tab wrapper that creates ViewModel
struct ChatTabView: View {
    let sessionRepository: SessionRepository
    let messageRepository: MessageRepository
    let todoRepository: TodoRepository
    let journalRepository: JournalRepository

    @State private var viewModel: ChatViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                ChatView(viewModel: viewModel)
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        // Create orchestrator with all required dependencies
                        let orchestrator = createOrchestrator()
                        viewModel = ChatViewModel(
                            orchestrator: orchestrator,
                            sessionRepository: sessionRepository,
                            messageRepository: messageRepository
                        )
                    }
            }
        }
    }

    private func createOrchestrator() -> AIOrchestrator {
        // Create with all required dependencies
        let toolRegistry = ToolRegistry()
        let toolValidator = ToolValidator(registry: toolRegistry)

        // Create tool executor with journal and todo tools
        let journalTools = JournalTools(
            journalRepository: journalRepository,
            sessionRepository: sessionRepository
        )
        let todoTools = TodoTools(todoRepository: todoRepository)
        let toolExecutor = ToolExecutor(
            journalTools: journalTools,
            todoTools: todoTools
        )

        return AIOrchestrator(
            openAIService: OpenAIService(),
            contextManager: ContextManager(),
            safetyClassifier: SafetyClassifier(),
            toolRegistry: toolRegistry,
            toolValidator: toolValidator,
            toolExecutor: toolExecutor,
            messageRepository: messageRepository,
            sessionRepository: sessionRepository,
            todoRepository: todoRepository,
            journalRepository: journalRepository
        )
    }
}

/// Todos tab wrapper that creates ViewModel
struct TodoTabView: View {
    let todoRepository: TodoRepository

    @State private var viewModel: TodoViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                TodoListView(viewModel: viewModel)
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        viewModel = TodoViewModel(todoRepository: todoRepository)
                    }
            }
        }
    }
}

/// Journal tab wrapper that creates ViewModel
struct JournalTabView: View {
    let journalRepository: JournalRepository

    @State private var viewModel: JournalViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                JournalListView(viewModel: viewModel)
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        viewModel = JournalViewModel(journalRepository: journalRepository)
                    }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            ChatMessage.self,
            DailySession.self,
            JournalEntry.self,
            TodoItem.self,
            MemoryItem.self
        ], inMemory: true)
}
