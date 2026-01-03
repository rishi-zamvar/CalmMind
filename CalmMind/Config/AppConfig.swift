import Foundation

/// Typed wrapper for app configuration values from Info.plist
/// Provides sensible defaults for all values
struct AppConfig {

    // MARK: - Default Values

    enum Defaults {
        static let aiModel = "gpt-4"
        static let maxTokens = 4000
        static let contextWindow = 10
        static let morningNudgeHour = 8
        static let eveningNudgeHour = 21
        static let nudgeGraceWindowMinutes = 30
        static let maxMessageLength = 2000
        static let maxJournalLength = 5000
        static let maxTodoTitleLength = 50
    }

    // MARK: - Properties

    /// The AI model to use for chat completions (e.g., "gpt-4", "gpt-4-turbo")
    let aiModel: String

    /// Maximum tokens for AI responses
    let maxTokens: Int

    /// Number of recent messages to include in context
    let contextWindow: Int

    /// Hour (0-23) for morning check-in nudge
    let morningNudgeHour: Int

    /// Hour (0-23) for evening check-in nudge
    let eveningNudgeHour: Int

    /// Minutes after nudge time to still count as "checked in"
    let nudgeGraceWindowMinutes: Int

    /// Maximum length for user chat messages
    let maxMessageLength: Int

    /// Maximum length for journal entries
    let maxJournalLength: Int

    /// Maximum length for todo item titles
    let maxTodoTitleLength: Int

    // MARK: - Initialization

    init(bundle: Bundle = .main) {
        let infoPlist = bundle.infoDictionary ?? [:]

        self.aiModel = infoPlist["AI_MODEL"] as? String
            ?? Defaults.aiModel

        self.maxTokens = infoPlist["MAX_TOKENS"] as? Int
            ?? Defaults.maxTokens

        self.contextWindow = infoPlist["CONTEXT_WINDOW"] as? Int
            ?? Defaults.contextWindow

        self.morningNudgeHour = Self.clampHour(
            infoPlist["MORNING_NUDGE_HOUR"] as? Int ?? Defaults.morningNudgeHour
        )

        self.eveningNudgeHour = Self.clampHour(
            infoPlist["EVENING_NUDGE_HOUR"] as? Int ?? Defaults.eveningNudgeHour
        )

        self.nudgeGraceWindowMinutes = infoPlist["NUDGE_GRACE_WINDOW_MINUTES"] as? Int
            ?? Defaults.nudgeGraceWindowMinutes

        self.maxMessageLength = infoPlist["MAX_MESSAGE_LENGTH"] as? Int
            ?? Defaults.maxMessageLength

        self.maxJournalLength = infoPlist["MAX_JOURNAL_LENGTH"] as? Int
            ?? Defaults.maxJournalLength

        self.maxTodoTitleLength = infoPlist["MAX_TODO_TITLE_LENGTH"] as? Int
            ?? Defaults.maxTodoTitleLength
    }

    // MARK: - Helpers

    private static func clampHour(_ hour: Int) -> Int {
        max(0, min(23, hour))
    }
}

// MARK: - Shared Instance

extension AppConfig {
    /// Shared instance using main bundle
    static let shared = AppConfig()
}
