import Foundation
import SwiftData

/// Deletes all user content from the app
/// Only deletes SwiftData entities - preserves settings, API keys, and preferences
final class DataDeleter {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Delete all user content from the app
    /// This removes only user-generated content:
    /// - Chat messages
    /// - Daily sessions
    /// - Journal entries (and events)
    /// - Todo items
    /// - Memory items
    /// - Topics (and facts)
    ///
    /// Preserved (not deleted):
    /// - User preferences and settings
    /// - API keys
    /// - Onboarding state
    /// - Notification settings
    /// - Encryption keys
    func deleteAllData() throws {
        try deleteAllEntities()
    }

    // MARK: - Private Methods

    private func deleteAllEntities() throws {
        // Delete messages
        try deleteAll(ChatMessage.self)

        // Delete sessions
        try deleteAll(DailySession.self)

        // Delete journal entries (JournalEvents cascade-delete)
        try deleteAll(JournalEntry.self)

        // Delete todos
        try deleteAll(TodoItem.self)

        // Delete memories
        try deleteAll(MemoryItem.self)

        // Delete topics (Facts cascade-delete via relationship)
        try deleteAll(Topic.self)

        // Save changes
        try modelContext.save()
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let items = try modelContext.fetch(descriptor)
        for item in items {
            modelContext.delete(item)
        }
    }
}

// MARK: - Widget Snapshot Store Protocol

protocol WidgetSnapshotStoreProtocol {
    func updateSnapshot(
        incompleteTodos: [String],
        didMorningCheckIn: Bool,
        didEveningCheckIn: Bool,
        lastInteraction: Date?
    )
    func clear()
}

extension WidgetSnapshotStore: WidgetSnapshotStoreProtocol {}
