import Foundation
import SwiftData

/// Deletes all user data from the app
/// Performs comprehensive cleanup of all data stores
final class DataDeleter {

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let secretsStore: SecretsStore
    private let notificationScheduler: NotificationSchedulerProtocol
    private let widgetSnapshotStore: WidgetSnapshotStoreProtocol
    private let userDefaults: UserDefaults
    private let fieldEncryptor: FieldEncryptor

    // MARK: - Initialization

    init(
        modelContext: ModelContext,
        secretsStore: SecretsStore = KeychainSecretsStore(),
        notificationScheduler: NotificationSchedulerProtocol = NotificationScheduler(),
        widgetSnapshotStore: WidgetSnapshotStoreProtocol = WidgetSnapshotStore(),
        userDefaults: UserDefaults = .standard,
        fieldEncryptor: FieldEncryptor = FieldEncryptor()
    ) {
        self.modelContext = modelContext
        self.secretsStore = secretsStore
        self.notificationScheduler = notificationScheduler
        self.widgetSnapshotStore = widgetSnapshotStore
        self.userDefaults = userDefaults
        self.fieldEncryptor = fieldEncryptor
    }

    // MARK: - Public API

    /// Delete all user data from the app
    /// This is a comprehensive cleanup that removes:
    /// - All SwiftData entities
    /// - API key from Keychain
    /// - All UserDefaults
    /// - All pending notifications
    /// - Widget snapshot
    /// - Encryption keys
    func deleteAllData() throws {
        // 1. Delete all SwiftData entities
        try deleteAllEntities()

        // 2. Clear Keychain (API key)
        secretsStore.deleteAPIKey()

        // 3. Cancel all notifications
        notificationScheduler.cancelAllPending()

        // 4. Clear widget snapshot
        widgetSnapshotStore.clear()

        // 5. Clear UserDefaults
        clearUserDefaults()

        // 6. Clear encryption keys
        clearEncryptionKeys()
    }

    // MARK: - Private Methods

    private func deleteAllEntities() throws {
        // Delete messages
        try deleteAll(ChatMessage.self)

        // Delete sessions
        try deleteAll(DailySession.self)

        // Delete journal entries
        try deleteAll(JournalEntry.self)

        // Delete todos
        try deleteAll(TodoItem.self)

        // Delete memories
        try deleteAll(MemoryItem.self)

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

    private func clearUserDefaults() {
        // Get all keys and remove them
        let domain = Bundle.main.bundleIdentifier ?? ""
        if !domain.isEmpty {
            userDefaults.removePersistentDomain(forName: domain)
        }

        // Also clear known keys as backup
        let knownKeys = [
            "morningNotificationsEnabled",
            "eveningNotificationsEnabled",
            "privacyModeEnabled",
            "notificationPrivacyMode",
            "deviceSalt",
            "lastNudgeMorningAt",
            "lastNudgeEveningAt",
            "hasCompletedOnboarding"
        ]

        for key in knownKeys {
            userDefaults.removeObject(forKey: key)
        }

        userDefaults.synchronize()
    }

    private func clearEncryptionKeys() {
        // Clear all known encryption key purposes
        let keyPurposes = [
            "journal",
            "memory",
            "notes"
        ]

        for purpose in keyPurposes {
            fieldEncryptor.deleteKey(for: purpose)
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
