import Foundation
import Security

// MARK: - Protocol

/// Protocol for secure storage of sensitive data
protocol SecretsStore {
    /// Save the OpenAI API key
    func saveAPIKey(_ key: String) throws

    /// Retrieve the stored API key, or nil if not set
    func getAPIKey() -> String?

    /// Delete the stored API key
    func deleteAPIKey()

    /// Check if an API key is stored
    var hasAPIKey: Bool { get }

    // MARK: - Weather API Key

    /// Save the OpenWeatherMap API key
    func saveWeatherAPIKey(_ key: String) throws

    /// Retrieve the stored weather API key, or nil if not set
    func getWeatherAPIKey() -> String?

    /// Delete the stored weather API key
    func deleteWeatherAPIKey()

    /// Check if a weather API key is stored
    var hasWeatherAPIKey: Bool { get }
}

// MARK: - Errors

enum SecretsStoreError: Error, LocalizedError {
    case emptyKey
    case keychainError(OSStatus)
    case unexpectedData
    case deviceLocked
    case migrationFailed

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            return "API key cannot be empty"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .unexpectedData:
            return "Unexpected data format in keychain"
        case .deviceLocked:
            return "Device must be unlocked at least once"
        case .migrationFailed:
            return "Failed to migrate from old storage"
        }
    }

    /// Whether the error is recoverable (e.g., wait and retry)
    var isRecoverable: Bool {
        switch self {
        case .deviceLocked:
            return true  // Wait and retry
        default:
            return false
        }
    }
}

// MARK: - Keychain Implementation

/// Keychain-backed secrets storage
/// PRODUCTION REQUIREMENTS:
/// - Accessibility: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly (available after first unlock)
/// - iCloud Sync: DISABLED (API keys must not sync across devices)
/// - Error Handling: Explicit failure states with device locked detection
final class KeychainSecretsStore: SecretsStore {

    private let service: String
    private let apiKeyAccount = "openai-api-key"
    private let weatherAPIKeyAccount = "openweathermap-api-key"

    /// PRODUCTION: Available after first unlock, not synced to iCloud
    private let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    init(service: String = "com.calmmind.app") {
        self.service = service
    }

    // MARK: - SecretsStore

    func saveAPIKey(_ key: String) throws {
        guard !key.isEmpty else {
            throw SecretsStoreError.emptyKey
        }

        guard let data = key.data(using: .utf8) else {
            throw SecretsStoreError.unexpectedData
        }

        // Delete existing key first (if any)
        deleteAPIKey()

        // Add new key with production security settings
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility,
            kSecAttrSynchronizable as String: kCFBooleanFalse!  // NO iCloud sync
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        // Handle specific error cases
        if status == errSecNotAvailable || status == errSecInteractionNotAllowed {
            throw SecretsStoreError.deviceLocked
        }

        guard status == errSecSuccess else {
            throw SecretsStoreError.keychainError(status)
        }
    }

    func getAPIKey() -> String? {
        // First, try Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        // Handle device locked case gracefully
        if status == errSecNotAvailable || status == errSecInteractionNotAllowed {
            // Device locked - fall through to xcconfig fallback
        } else if status == errSecSuccess,
                  let data = result as? Data,
                  let key = String(data: data, encoding: .utf8) {
            return key
        }

        // DEBUG fallback: Try xcconfig file for development testing
        // Skip fallback when running tests (test bundle is loaded)
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            return readAPIKeyFromXCConfig()
        }
        #endif
        return nil
    }

    #if DEBUG
    /// Read API key from xcconfig for development testing
    private func readAPIKeyFromXCConfig() -> String? {
        // Try Bundle main path first (if Info.plist has it)
        if let bundleKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           !bundleKey.isEmpty,
           !bundleKey.hasPrefix("$(") {  // Not an unexpanded variable
            return bundleKey
        }

        // Try reading directly from xcconfig file
        guard let configPath = Bundle.main.path(forResource: "Secrets", ofType: "xcconfig") else {
            // Try project directory path for simulator
            let projectPath = "/Users/rishizamvar/Desktop/CalmMind/Config/Secrets.xcconfig"
            return parseXCConfig(at: projectPath)
        }
        return parseXCConfig(at: configPath)
    }

    private func parseXCConfig(at path: String) -> String? {
        guard FileManager.default.fileExists(atPath: path),
              let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("OPENAI_API_KEY") {
                let parts = trimmed.components(separatedBy: "=")
                if parts.count >= 2 {
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty && value != "sk-your-key-here" {
                        return value
                    }
                }
            }
        }
        return nil
    }
    #endif

    func deleteAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]

        SecItemDelete(query as CFDictionary)
    }

    var hasAPIKey: Bool {
        getAPIKey() != nil
    }

    // MARK: - Weather API Key

    func saveWeatherAPIKey(_ key: String) throws {
        guard !key.isEmpty else {
            throw SecretsStoreError.emptyKey
        }

        guard let data = key.data(using: .utf8) else {
            throw SecretsStoreError.unexpectedData
        }

        // Delete existing key first (if any)
        deleteWeatherAPIKey()

        // Add new key with production security settings
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: weatherAPIKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility,
            kSecAttrSynchronizable as String: kCFBooleanFalse!  // NO iCloud sync
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        // Handle specific error cases
        if status == errSecNotAvailable || status == errSecInteractionNotAllowed {
            throw SecretsStoreError.deviceLocked
        }

        guard status == errSecSuccess else {
            throw SecretsStoreError.keychainError(status)
        }
    }

    func getWeatherAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: weatherAPIKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        // Handle device locked case gracefully
        if status == errSecNotAvailable || status == errSecInteractionNotAllowed {
            return nil
        }

        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }

        // DEBUG fallback: Try xcconfig file for development testing
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            return readWeatherAPIKeyFromXCConfig()
        }
        #endif
        return nil
    }

    #if DEBUG
    private func readWeatherAPIKeyFromXCConfig() -> String? {
        // Try Bundle main path first
        if let bundleKey = Bundle.main.object(forInfoDictionaryKey: "OPENWEATHERMAP_API_KEY") as? String,
           !bundleKey.isEmpty,
           !bundleKey.hasPrefix("$(") {
            return bundleKey
        }

        // Try reading directly from xcconfig file
        let projectPath = "/Users/rishizamvar/Desktop/CalmMind/Config/Secrets.xcconfig"
        return parseWeatherKeyFromXCConfig(at: projectPath)
    }

    private func parseWeatherKeyFromXCConfig(at path: String) -> String? {
        guard FileManager.default.fileExists(atPath: path),
              let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("OPENWEATHERMAP_API_KEY") {
                let parts = trimmed.components(separatedBy: "=")
                if parts.count >= 2 {
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty && value != "your-openweathermap-key-here" {
                        return value
                    }
                }
            }
        }
        return nil
    }
    #endif

    func deleteWeatherAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: weatherAPIKeyAccount
        ]

        SecItemDelete(query as CFDictionary)
    }

    var hasWeatherAPIKey: Bool {
        getWeatherAPIKey() != nil
    }

    // MARK: - Migration

    /// Migrate API key from UserDefaults (one-time, then delete from defaults)
    /// Call this on app launch to migrate legacy storage
    func migrateFromUserDefaultsIfNeeded(defaults: UserDefaults = .standard) throws {
        let legacyKey = "openAIApiKey"

        // Check if there's a legacy key to migrate
        guard let oldValue = defaults.string(forKey: legacyKey), !oldValue.isEmpty else {
            return  // Nothing to migrate
        }

        // Check if we already have a key in Keychain
        if hasAPIKey {
            // Already migrated, just delete the old one
            defaults.removeObject(forKey: legacyKey)
            return
        }

        // Migrate to Keychain
        do {
            try saveAPIKey(oldValue)
            defaults.removeObject(forKey: legacyKey)
        } catch {
            throw SecretsStoreError.migrationFailed
        }
    }
}

// MARK: - Shared Instance

extension KeychainSecretsStore {
    /// Shared instance for production use
    static let shared = KeychainSecretsStore()
}
