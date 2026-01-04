import Foundation

/// Protocol for caching generated prompts
/// Prompts are cached by date to avoid regenerating during the same day
protocol PromptCacheProtocol {
    /// Retrieves a cached prompt for the given date
    /// - Parameter date: The date to look up (will use start of day)
    /// - Returns: The cached prompt, or nil if not found
    func get(for date: Date) -> String?

    /// Caches a prompt for the given date
    /// - Parameters:
    ///   - prompt: The prompt to cache
    ///   - date: The date to associate with the prompt
    func set(_ prompt: String, for date: Date)

    /// Clears all cached prompts
    func clear()
}

/// UserDefaults-based implementation for prompt caching
final class UserDefaultsPromptCache: PromptCacheProtocol {
    private let defaults: UserDefaults
    private let cacheKey = "cachedPrompts"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func get(for date: Date) -> String? {
        let key = cacheKeyForDate(date)
        return defaults.string(forKey: key)
    }

    func set(_ prompt: String, for date: Date) {
        let key = cacheKeyForDate(date)
        defaults.set(prompt, forKey: key)
    }

    func clear() {
        // Remove all cached prompts
        let keys = defaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix(cacheKey) {
            defaults.removeObject(forKey: key)
        }
    }

    private func cacheKeyForDate(_ date: Date) -> String {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let dateString = ISO8601DateFormatter().string(from: startOfDay)
        return "\(cacheKey)_\(dateString)"
    }
}
