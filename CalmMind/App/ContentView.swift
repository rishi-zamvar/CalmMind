import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Tab = .home
    @State private var chatAutoFocus = false
    @State private var todoAutoFocusAdd = false

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
        TabView(selection: $selectedTab) {
            // Home Tab (default)
            NavigationStack {
                HomeView(
                    todoRepository: todoRepository,
                    journalRepository: journalRepository
                )
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(Tab.home)

            // Chat Tab
            NavigationStack {
                ChatTabView(
                    sessionRepository: sessionRepository,
                    messageRepository: messageRepository,
                    todoRepository: todoRepository,
                    journalRepository: journalRepository,
                    autoFocus: chatAutoFocus
                )
            }
            .tabItem {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(Tab.chat)

            // Todos Tab
            NavigationStack {
                TodoTabView(
                    todoRepository: todoRepository,
                    autoFocusAdd: todoAutoFocusAdd
                )
            }
            .tabItem {
                Label("Todos", systemImage: "checklist")
            }
            .tag(Tab.todos)

            // Journal Tab
            NavigationStack {
                JournalTabView(journalRepository: journalRepository)
            }
            .tabItem {
                Label("Journal", systemImage: "book")
            }
            .tag(Tab.journal)

            // Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(Tab.settings)
        }
        .tint(DesignTokens.Colors.warmClay)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToTab)) { notification in
            if let tab = notification.object as? Tab {
                selectedTab = tab

                // Reset auto-focus flags
                chatAutoFocus = false
                todoAutoFocusAdd = false

                // Check for specific auto-focus flags
                if let userInfo = notification.userInfo {
                    if let autoFocus = userInfo["autoFocus"] as? Bool {
                        chatAutoFocus = autoFocus
                    }
                    if let autoFocusAdd = userInfo["autoFocusAdd"] as? Bool {
                        todoAutoFocusAdd = autoFocusAdd
                    }
                }
            }
        }
    }
}

// MARK: - Tab Views

/// Chat tab wrapper that creates ViewModel
struct ChatTabView: View {
    @Environment(\.modelContext) private var modelContext

    let sessionRepository: SessionRepository
    let messageRepository: MessageRepository
    let todoRepository: TodoRepository
    let journalRepository: JournalRepository
    var autoFocus: Bool = false

    @State private var viewModel: ChatViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                ChatView(viewModel: viewModel, autoFocus: autoFocus)
            } else {
                ProgressView("Loading...")
                    .tint(DesignTokens.Colors.warmClay)
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

        // Create journal persistence for auto-journaling
        let journalPersistence = JournalPersistenceActor(
            modelContainer: modelContext.container
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
            journalRepository: journalRepository,
            journalPersistence: journalPersistence
        )
    }
}

/// Todos tab wrapper that creates ViewModel
struct TodoTabView: View {
    let todoRepository: TodoRepository
    var autoFocusAdd: Bool = false

    @State private var viewModel: TodoViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                TodoListView(viewModel: viewModel, autoFocusAdd: autoFocusAdd)
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
