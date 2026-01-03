import Foundation

/// Stores widget snapshot data in App Group for cross-process sharing
/// Widget reads this JSON file to display current state
final class WidgetSnapshotStore {

    // MARK: - Constants

    private static let snapshotFileName = "widget_snapshot.json"
    private static let appGroupIdentifier = "group.com.calmmind.app"

    // MARK: - Dependencies

    private let fileManager: FileManager
    private let userPreferences: UserPreferences
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    // MARK: - Initialization

    init(
        fileManager: FileManager = .default,
        userPreferences: UserPreferences = .shared
    ) {
        self.fileManager = fileManager
        self.userPreferences = userPreferences
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.dateEncodingStrategy = .iso8601
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Public API

    /// Update the widget snapshot with current state
    func updateSnapshot(
        incompleteTodos: [String],
        didMorningCheckIn: Bool,
        didEveningCheckIn: Bool,
        lastInteraction: Date?
    ) {
        let isMinimal = userPreferences.notificationPrivacyMode == .minimal

        let snapshot = WidgetSnapshot(
            version: 1,
            incompleteTodos: isMinimal ? [] : incompleteTodos,
            incompleteTodoCount: incompleteTodos.count,
            didMorningCheckIn: didMorningCheckIn,
            didEveningCheckIn: didEveningCheckIn,
            lastInteractionAt: lastInteraction,
            lastSessionDate: formatDateKey(Date()),
            privacyMode: isMinimal ? "minimal" : "detailed"
        )

        writeSnapshot(snapshot)
    }

    /// Read the current snapshot (for widget provider)
    func readSnapshot() -> WidgetSnapshot? {
        guard let url = snapshotURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? jsonDecoder.decode(WidgetSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    /// Clear the widget snapshot
    func clear() {
        guard let url = snapshotURL else { return }
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Private Helpers

    private var snapshotURL: URL? {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        ) else {
            return nil
        }
        return containerURL.appendingPathComponent(Self.snapshotFileName)
    }

    private func writeSnapshot(_ snapshot: WidgetSnapshot) {
        guard let url = snapshotURL,
              let data = try? jsonEncoder.encode(snapshot) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

// MARK: - Widget Snapshot Model

/// Data model for widget snapshot
/// Stored as JSON in App Group container
struct WidgetSnapshot: Codable, Equatable {
    /// Schema version for forwards compatibility
    let version: Int

    /// Todo titles (empty if privacy mode is minimal)
    let incompleteTodos: [String]

    /// Number of incomplete todos (always included)
    let incompleteTodoCount: Int

    /// Whether morning check-in completed today
    let didMorningCheckIn: Bool

    /// Whether evening check-in completed today
    let didEveningCheckIn: Bool

    /// Timestamp of last app interaction
    let lastInteractionAt: Date?

    /// Date string of last session (YYYY-MM-DD)
    let lastSessionDate: String

    /// Privacy mode (minimal or detailed)
    let privacyMode: String
}
