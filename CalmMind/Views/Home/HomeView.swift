import SwiftUI
import SwiftData

/// Home screen - daily anchor, not a feed
/// Exactly 3 blocks, always visible without scrolling on iPhone 13/14/15 Pro
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    let todoRepository: TodoRepository
    let journalRepository: JournalRepository

    // Navigation state
    @State private var selectedTab: Tab = .home
    @State private var showingJournalDetail = false
    @State private var todayJournalEntry: JournalEntry?
    @State private var navigateToChat = false
    @State private var chatAutoFocus = false

    // Data
    @State private var todos: [TodoItem] = []

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.sectionGap) {
                // 1. Date & Time anchor
                DateTimeHeader(onTap: openTodayJournal)

                // 2. Today's Focus (top 3 todos)
                PriorityTodosCard(
                    todos: todos,
                    onComplete: completeTodo,
                    onTapTodo: navigateToTodos,
                    onAddTodo: navigateToTodosWithAddFocus
                )

                // 3. Reflective prompt (AI invitation)
                ReflectivePromptCard(
                    onTap: openChatWithFocus,
                    generatePrompt: generateWarmPrompt
                )
            }
            .padding(.horizontal, DesignTokens.Spacing.screenPad)
            .padding(.top, DesignTokens.Spacing.screenPad)
        }
        .ambientBackground()
        .navigationTitle("")
        .navigationBarHidden(true)
        .task {
            await loadTodos()
        }
        .sheet(isPresented: $showingJournalDetail) {
            if let entry = todayJournalEntry {
                NavigationStack {
                    JournalDetailView(
                        entry: entry,
                        viewModel: JournalViewModel(journalRepository: journalRepository)
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func openTodayJournal() {
        DesignTokens.Haptics.softTap()

        // Get or create today's entry
        let today = Calendar.current.startOfDay(for: Date())

        if let existing = journalRepository.fetchEntry(for: today) {
            todayJournalEntry = existing
        } else {
            // Create new entry and open in edit mode
            if let newEntry = journalRepository.createEntry(date: today, text: "") {
                todayJournalEntry = newEntry
            }
        }

        showingJournalDetail = true
    }

    private func completeTodo(_ todo: TodoItem) {
        todo.markCompleted()
        try? modelContext.save()
    }

    private func navigateToTodos() {
        // This will be handled by parent TabView through binding
        NotificationCenter.default.post(name: .navigateToTab, object: Tab.todos)
    }

    private func navigateToTodosWithAddFocus() {
        // Navigate to todos with add field auto-focused
        NotificationCenter.default.post(
            name: .navigateToTab,
            object: Tab.todos,
            userInfo: ["autoFocusAdd": true]
        )
    }

    private func openChatWithFocus() {
        DesignTokens.Haptics.softTap()
        // Navigate to chat with autoFocus
        NotificationCenter.default.post(
            name: .navigateToTab,
            object: Tab.chat,
            userInfo: ["autoFocus": true]
        )
    }

    private func loadTodos() async {
        todos = (try? todoRepository.fetchAll()) ?? []
    }

    private func generateWarmPrompt() async -> String? {
        // In a real implementation, this would call the AI service
        // For now, return a warm fallback
        // The prompt should reference themes, not specific details

        // Check if there's recent activity
        let recentTodos = todos.filter { !$0.isCompleted }
        let hasActivity = !recentTodos.isEmpty

        if hasActivity {
            return "Looks like you have a few things on your plate. Want to talk through what feels most pressing?"
        } else {
            return nil // Will use fallback
        }
    }
}

// MARK: - Tab Navigation

enum Tab: Int, CaseIterable {
    case home = 0
    case chat = 1
    case todos = 2
    case journal = 3
    case settings = 4
}

extension Notification.Name {
    static let navigateToTab = Notification.Name("navigateToTab")
}

#Preview {
    NavigationStack {
        HomeView(
            todoRepository: TodoRepository(context: ModelContext(try! ModelContainer(for: TodoItem.self, JournalEntry.self))),
            journalRepository: JournalRepository(context: ModelContext(try! ModelContainer(for: TodoItem.self, JournalEntry.self)))
        )
    }
}
