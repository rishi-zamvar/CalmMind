import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var services: ServiceContainer

    /// Loading gate - ensures UserDefaults hydrated before showing content
    @State private var isReady = false

    /// Tracks onboarding completion to trigger view update
    /// Needed because UserPreferences doesn't trigger SwiftUI observation
    @State private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !isReady {
                // Loading gate: stable view until preferences hydrated
                ProgressView()
                    .tint(DesignTokens.Colors.warmClay)
                    .onAppear { checkReady() }
            } else if !hasCompletedOnboarding {
                // Onboarding flow
                OnboardingContainerView(
                    locationService: services.locationService,
                    userPreferences: services.userPreferences,
                    onComplete: {
                        // Trigger view update to show MainTabView
                        hasCompletedOnboarding = true
                    }
                )
            } else {
                // Main app
                MainTabView()
            }
        }
    }

    private func checkReady() {
        // Ensure UserDefaults is fully synchronized
        // In practice this is immediate, but gate ensures no flicker
        DispatchQueue.main.async {
            // Read persisted state on startup
            hasCompletedOnboarding = services.userPreferences.hasCompletedOnboardingV2
            isReady = true
        }
    }
}

// MARK: - Main Tab View

/// The main tab interface shown after onboarding is complete
struct MainTabView: View {
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
/// INVARIANT: One orchestrator per tab session, not per render
struct ChatTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var services: ServiceContainer

    let sessionRepository: SessionRepository
    let messageRepository: MessageRepository
    let todoRepository: TodoRepository
    let journalRepository: JournalRepository
    var autoFocus: Bool = false

    // Store orchestrator - created ONCE per session
    @State private var orchestrator: AIOrchestrator?
    @State private var viewModel: ChatViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                ChatView(viewModel: viewModel, autoFocus: autoFocus)
            } else {
                ProgressView("Loading...")
                    .tint(DesignTokens.Colors.warmClay)
            }
        }
        .task {
            // Create orchestrator ONCE on first appear
            if orchestrator == nil {
                orchestrator = createOrchestrator()
            }
            if viewModel == nil, let orc = orchestrator {
                viewModel = ChatViewModel(
                    orchestrator: orc,
                    sessionRepository: sessionRepository,
                    messageRepository: messageRepository
                )
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

        // Create semantic search components
        let topicRepository = TopicRepository(context: modelContext)
        let semanticSearchGate = SemanticSearchGate(
            topicRepository: topicRepository,
            userPreferences: services.userPreferences
        )
        let semanticSearchEngine = SemanticSearchEngine(
            embeddingService: services.embeddingService,
            topicRepository: topicRepository
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
            journalPersistence: journalPersistence,
            services: services,
            semanticSearchGate: semanticSearchGate,
            semanticSearchEngine: semanticSearchEngine
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

/// Journal tab wrapper that creates ViewModel with synthesis support
struct JournalTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var services: ServiceContainer

    let journalRepository: JournalRepository

    @State private var viewModel: JournalViewModel?
    @State private var journalSynthesizer: JournalSynthesizer?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                JournalListView(viewModel: viewModel, userPreferences: services.userPreferences)
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            if journalSynthesizer == nil {
                journalSynthesizer = createJournalSynthesizer()
            }
            if viewModel == nil {
                viewModel = JournalViewModel(
                    journalRepository: journalRepository,
                    journalSynthesizer: journalSynthesizer
                )
            }
        }
    }

    private func createJournalSynthesizer() -> JournalSynthesizer {
        let journalPersistence = JournalPersistenceActor(
            modelContainer: modelContext.container
        )
        let journalGenerator = JournalGenerator(openAIService: OpenAIService())

        return JournalSynthesizer(
            journalPersistence: journalPersistence,
            journalGenerator: journalGenerator,
            services: services
        )
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ChatMessage.self, DailySession.self, JournalEntry.self, TodoItem.self, MemoryItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ContentView()
        .modelContainer(container)
        .environmentObject(ServiceContainer(modelContainer: container))
}
