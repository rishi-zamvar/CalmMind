import SwiftUI
import SwiftData

@main
struct CalmMindApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ChatMessage.self,
            DailySession.self,
            JournalEntry.self,
            TodoItem.self,
            MemoryItem.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
