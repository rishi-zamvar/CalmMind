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
        static let hasCompletedOnboardingV2 = "hasCompletedOnboardingV2"
        static let lastNudgeMorningAt = "lastNudgeMorningAt"
        static let lastNudgeEveningAt = "lastNudgeEveningAt"
        static let deviceSalt = "deviceSalt"
        static let userName = "userName"
        static let autoCreateTodos = "autoCreateTodos"
        static let autoJournalingEnabled = "autoJournalingEnabled"
        static let installedVersion = "installedBuildVersion"
        static let weatherEnabled = "weatherEnabled"
        static let locationPermissionInteracted = "locationPermissionInteracted"
        static let notificationPermissionInteracted = "notificationPermissionInteracted"
        static let aiInsightsEnabled = "aiInsightsEnabled"
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
            Keys.hasCompletedOnboarding: false,
            Keys.hasCompletedOnboardingV2: false,
            Keys.autoCreateTodos: true,
            Keys.weatherEnabled: true,
            Keys.locationPermissionInteracted: false,
            Keys.notificationPermissionInteracted: false
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

    /// Whether the user has completed V2 onboarding (with name collection)
    /// Force V2 onboarding for ALL users exactly once
    var hasCompletedOnboardingV2: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboardingV2) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboardingV2) }
    }

    // MARK: - User Profile

    /// User's name for personalized responses
    /// - Trims whitespace on set
    /// - Returns nil for empty/whitespace-only strings
    var userName: String? {
        get { defaults.string(forKey: Keys.userName) }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespaces)
            defaults.set(trimmed?.isEmpty == false ? trimmed : nil, forKey: Keys.userName)
        }
    }

    // MARK: - Behavior Preferences

    /// Whether todos should be auto-created from conversation
    /// Defaults to true (opt-out, not opt-in)
    var autoCreateTodos: Bool {
        get {
            // If key doesn't exist, return true (default)
            if defaults.object(forKey: Keys.autoCreateTodos) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.autoCreateTodos)
        }
        set { defaults.set(newValue, forKey: Keys.autoCreateTodos) }
    }

    /// Whether to auto-capture messages to journal
    /// Defaults to FALSE (opt-in, not opt-out) - requires explicit consent
    var autoJournalingEnabled: Bool {
        get {
            // Default to false - requires explicit opt-in
            defaults.bool(forKey: Keys.autoJournalingEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.autoJournalingEnabled) }
    }

    /// Whether weather feature is enabled
    /// Defaults to true (opt-out, not opt-in)
    var weatherEnabled: Bool {
        get {
            // If key doesn't exist, return true (default enabled)
            if defaults.object(forKey: Keys.weatherEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.weatherEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.weatherEnabled) }
    }

    /// Whether AI Insights feature is enabled for journal entries
    /// Defaults to FALSE (opt-in, not opt-out) - requires explicit consent
    var aiInsightsEnabled: Bool {
        get {
            // Default to false - requires explicit opt-in
            defaults.bool(forKey: Keys.aiInsightsEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.aiInsightsEnabled) }
    }

    // MARK: - Permission Interaction Tracking

    /// Whether user has interacted with location permission (grant or deny)
    /// Used to enable "Get Started" button in onboarding
    var locationPermissionInteracted: Bool {
        get { defaults.bool(forKey: Keys.locationPermissionInteracted) }
        set { defaults.set(newValue, forKey: Keys.locationPermissionInteracted) }
    }

    /// Whether user has interacted with notification permission (grant or deny)
    /// Used to enable "Get Started" button in onboarding
    var notificationPermissionInteracted: Bool {
        get { defaults.bool(forKey: Keys.notificationPermissionInteracted) }
        set { defaults.set(newValue, forKey: Keys.notificationPermissionInteracted) }
    }

    // MARK: - Version Tracking

    /// Stamp the installed version on first launch (for migrations)
    func stampInstallVersionIfNeeded(currentVersion: String) {
        if defaults.string(forKey: Keys.installedVersion) == nil {
            defaults.set(currentVersion, forKey: Keys.installedVersion)
        }
    }

    /// The version that was first installed
    var installedVersion: String? {
        defaults.string(forKey: Keys.installedVersion)
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
            Keys.hasCompletedOnboardingV2,
            Keys.lastNudgeMorningAt,
            Keys.lastNudgeEveningAt,
            Keys.userName,
            Keys.autoCreateTodos,
            Keys.autoJournalingEnabled,
            Keys.weatherEnabled,
            Keys.locationPermissionInteracted,
            Keys.notificationPermissionInteracted,
            Keys.aiInsightsEnabled
            // Note: deviceSalt and installedVersion are intentionally NOT reset
        ]
        keys.forEach { defaults.removeObject(forKey: $0) }
    }
}

// MARK: - Shared Instance

extension UserPreferences {
    /// Shared instance using standard UserDefaults
    static let shared = UserPreferences()
}
