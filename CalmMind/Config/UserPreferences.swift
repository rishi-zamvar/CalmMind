import Foundation

/// Privacy mode for notifications
/// Controls how much detail is shown in notification content
enum NotificationPrivacyMode: String, Codable {
    /// Show generic text only (lock screen safe)
    case minimal

    /// Can include todo titles, mood references
    case detailed
}

/// Typed wrapper for UserDefaults preferences
final class UserPreferences {

    // MARK: - Keys

    private enum Keys {
        static let morningNotificationsEnabled = "morningNotificationsEnabled"
        static let eveningNotificationsEnabled = "eveningNotificationsEnabled"
        static let privacyModeEnabled = "privacyModeEnabled"
        static let notificationPrivacyMode = "notificationPrivacyMode"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let lastNudgeMorningAt = "lastNudgeMorningAt"
        static let lastNudgeEveningAt = "lastNudgeEveningAt"
        static let deviceSalt = "deviceSalt"
    }

    // MARK: - Properties

    private let defaults: UserDefaults

    // MARK: - Initialization

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.morningNotificationsEnabled: true,
            Keys.eveningNotificationsEnabled: true,
            Keys.privacyModeEnabled: false,
            Keys.notificationPrivacyMode: NotificationPrivacyMode.detailed.rawValue,
            Keys.hasCompletedOnboarding: false
        ])
    }

    // MARK: - Notification Preferences

    /// Whether morning check-in nudges are enabled
    var morningNotificationsEnabled: Bool {
        get { defaults.bool(forKey: Keys.morningNotificationsEnabled) }
        set { defaults.set(newValue, forKey: Keys.morningNotificationsEnabled) }
    }

    /// Whether evening check-in nudges are enabled
    var eveningNotificationsEnabled: Bool {
        get { defaults.bool(forKey: Keys.eveningNotificationsEnabled) }
        set { defaults.set(newValue, forKey: Keys.eveningNotificationsEnabled) }
    }

    /// Overall privacy mode (affects various app behaviors)
    var privacyModeEnabled: Bool {
        get { defaults.bool(forKey: Keys.privacyModeEnabled) }
        set { defaults.set(newValue, forKey: Keys.privacyModeEnabled) }
    }

    /// Controls notification content detail level
    var notificationPrivacyMode: NotificationPrivacyMode {
        get {
            guard let rawValue = defaults.string(forKey: Keys.notificationPrivacyMode),
                  let mode = NotificationPrivacyMode(rawValue: rawValue) else {
                return .detailed
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.notificationPrivacyMode)
        }
    }

    // MARK: - Onboarding

    /// Whether the user has completed initial onboarding
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }

    // MARK: - Nudge Tracking (Anti-Duplicate)

    /// Last time a morning nudge was scheduled
    var lastNudgeMorningAt: Date? {
        get { defaults.object(forKey: Keys.lastNudgeMorningAt) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastNudgeMorningAt) }
    }

    /// Last time an evening nudge was scheduled
    var lastNudgeEveningAt: Date? {
        get { defaults.object(forKey: Keys.lastNudgeEveningAt) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastNudgeEveningAt) }
    }

    // MARK: - Device Salt (for seeded randomness)

    /// Unique device salt for deterministic nudge template selection
    /// Generated once on first access
    var deviceSalt: String {
        if let existing = defaults.string(forKey: Keys.deviceSalt) {
            return existing
        }
        let salt = UUID().uuidString
        defaults.set(salt, forKey: Keys.deviceSalt)
        return salt
    }

    // MARK: - Reset

    /// Reset all preferences to defaults
    func resetToDefaults() {
        let keys = [
            Keys.morningNotificationsEnabled,
            Keys.eveningNotificationsEnabled,
            Keys.privacyModeEnabled,
            Keys.notificationPrivacyMode,
            Keys.hasCompletedOnboarding,
            Keys.lastNudgeMorningAt,
            Keys.lastNudgeEveningAt
            // Note: deviceSalt is intentionally NOT reset
        ]
        keys.forEach { defaults.removeObject(forKey: $0) }
    }
}

// MARK: - Shared Instance

extension UserPreferences {
    /// Shared instance using standard UserDefaults
    static let shared = UserPreferences()
}
