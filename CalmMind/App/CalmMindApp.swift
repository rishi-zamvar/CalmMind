import SwiftUI
import SwiftData

@main
struct CalmMindApp: App {
    @Environment(\.scenePhase) private var scenePhase

    // ModelContainer MUST be static for stored property initializer to reference it
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ChatMessage.self,
            DailySession.self,
            JournalEntry.self,
            JournalEvent.self,
            TodoItem.self,
            MemoryItem.self,
            Topic.self,
            Fact.self
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

    // SINGLE source of truth for all services
    @StateObject private var services = ServiceContainer(
        modelContainer: CalmMindApp.sharedModelContainer
    )

    /// Journal synthesizer for end-of-day narrative generation
    @State private var journalSynthesizer: JournalSynthesizer?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(services)
                .tint(DesignTokens.Colors.warmClay)
        }
        .modelContainer(CalmMindApp.sharedModelContainer)
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                // Trigger journal synthesis check (throttled internally)
                Task {
                    await journalSynthesizer?.synthesizeYesterdayIfNeeded()
                }
            }
        }
    }

    init() {
        // JournalSynthesizer needs to be created after services exists
        // Use a static to avoid issues with stored property initialization order
        let container = CalmMindApp.sharedModelContainer
        let persistence = JournalPersistenceActor(modelContainer: container)
        let openAIService = OpenAIService()
        let journalGenerator = JournalGenerator(openAIService: openAIService)

        // Create synthesizer - services will be passed when available
        _journalSynthesizer = State(initialValue: JournalSynthesizer(
            journalPersistence: persistence,
            journalGenerator: journalGenerator
        ))
    }
}
