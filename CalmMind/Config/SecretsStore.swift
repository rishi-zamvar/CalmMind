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
            // Device locked - return nil, caller should handle
            return nil
        }

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

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
