import SwiftUI
import SwiftData

@main
struct CalmMindApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ChatMessage.self,
            DailySession.self,
            JournalEntry.self,
            JournalEvent.self,
            TodoItem.self,
            MemoryItem.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Log the actual error for debugging
            print("⚠️ ModelContainer creation failed: \(error)")
            print("⚠️ Attempting recovery with fresh database...")

            // Try to delete the existing store and create fresh
            let url = URL.applicationSupportDirectory.appending(path: "default.store")
            try? FileManager.default.removeItem(at: url)

            // Try again with fresh database
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                // If still failing, fall back to in-memory store
                print("⚠️ Recovery failed, using in-memory store: \(error)")
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                do {
                    return try ModelContainer(for: schema, configurations: [inMemoryConfig])
                } catch {
                    fatalError("Could not create ModelContainer even in-memory: \(error)")
                }
            }
        }
    }()

    /// Journal synthesizer for end-of-day narrative generation
    private var journalSynthesizer: JournalSynthesizer?

    init() {
        // Initialize journal synthesizer with dependencies
        let persistence = JournalPersistenceActor(modelContainer: sharedModelContainer)
        let openAIService = OpenAIService()
        let journalGenerator = JournalGenerator(openAIService: openAIService)
        journalSynthesizer = JournalSynthesizer(
            journalPersistence: persistence,
            journalGenerator: journalGenerator
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(DesignTokens.Colors.warmClay)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                // Trigger journal synthesis check (throttled internally)
                Task {
                    await journalSynthesizer?.synthesizeYesterdayIfNeeded()
                }
            }
        }
    }
}
