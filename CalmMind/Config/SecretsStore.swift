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

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            return "API key cannot be empty"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .unexpectedData:
            return "Unexpected data format in keychain"
        }
    }
}

// MARK: - Keychain Implementation

/// Keychain-backed secrets storage
/// Uses kSecAttrAccessibleWhenUnlockedThisDeviceOnly for security
final class KeychainSecretsStore: SecretsStore {

    private let service: String
    private let apiKeyAccount = "openai-api-key"

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

        // Add new key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

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
}

// MARK: - Shared Instance

extension KeychainSecretsStore {
    /// Shared instance for production use
    static let shared = KeychainSecretsStore()
}
