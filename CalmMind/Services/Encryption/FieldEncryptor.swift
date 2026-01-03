import Foundation
import CryptoKit

/// Provides field-level encryption using AES-GCM
/// Used for encrypting sensitive data like journal entries before storage
final class FieldEncryptor {

    // MARK: - Key Generation

    /// Generate a new 256-bit encryption key
    /// - Returns: The key data, or nil if generation fails
    func generateKey() -> Data? {
        let key = SymmetricKey(size: .bits256)
        return key.withUnsafeBytes { Data($0) }
    }

    // MARK: - String Encryption

    /// Encrypt a string using AES-GCM
    /// - Parameters:
    ///   - plaintext: The string to encrypt
    ///   - keyData: The 256-bit encryption key
    /// - Returns: The encrypted data (nonce + ciphertext + tag), or nil if encryption fails
    func encrypt(_ plaintext: String, with keyData: Data) -> Data? {
        guard let plaintextData = plaintext.data(using: .utf8) else {
            return nil
        }
        return encryptData(plaintextData, with: keyData)
    }

    /// Decrypt data to a string using AES-GCM
    /// - Parameters:
    ///   - encryptedData: The encrypted data (nonce + ciphertext + tag)
    ///   - keyData: The 256-bit encryption key
    /// - Returns: The decrypted string, or nil if decryption fails
    func decrypt(_ encryptedData: Data, with keyData: Data) -> String? {
        guard let decryptedData = decryptData(encryptedData, with: keyData) else {
            return nil
        }
        return String(data: decryptedData, encoding: .utf8)
    }

    // MARK: - Data Encryption

    /// Encrypt binary data using AES-GCM
    /// - Parameters:
    ///   - data: The data to encrypt
    ///   - keyData: The 256-bit encryption key
    /// - Returns: The encrypted data (nonce + ciphertext + tag), or nil if encryption fails
    func encryptData(_ data: Data, with keyData: Data) -> Data? {
        guard keyData.count == 32 else { // 256 bits = 32 bytes
            return nil
        }

        let key = SymmetricKey(data: keyData)

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)

            // Combine nonce + ciphertext + tag for storage
            guard let combined = sealedBox.combined else {
                return nil
            }
            return combined
        } catch {
            return nil
        }
    }

    /// Decrypt binary data using AES-GCM
    /// - Parameters:
    ///   - encryptedData: The encrypted data (nonce + ciphertext + tag)
    ///   - keyData: The 256-bit encryption key
    /// - Returns: The decrypted data, or nil if decryption fails
    func decryptData(_ encryptedData: Data, with keyData: Data) -> Data? {
        guard keyData.count == 32 else {
            return nil
        }

        let key = SymmetricKey(data: keyData)

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return decryptedData
        } catch {
            // Decryption failed - wrong key, tampered data, or corrupted
            return nil
        }
    }

    // MARK: - Key Storage Helpers

    /// Create a key identifier for storing in Keychain
    /// - Parameter purpose: Description of key's purpose (e.g., "journal")
    /// - Returns: The Keychain service name
    static func keychainService(for purpose: String) -> String {
        return "com.calmmind.encryption.\(purpose)"
    }

    /// Store an encryption key in Keychain
    /// - Parameters:
    ///   - key: The encryption key
    ///   - purpose: Description of key's purpose
    /// - Returns: True if storage succeeded
    @discardableResult
    func storeKey(_ key: Data, for purpose: String) -> Bool {
        let service = Self.keychainService(for: purpose)

        // Delete existing key first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new key
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve an encryption key from Keychain
    /// - Parameter purpose: Description of key's purpose
    /// - Returns: The key data, or nil if not found
    func retrieveKey(for purpose: String) -> Data? {
        let service = Self.keychainService(for: purpose)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            return data
        }
        return nil
    }

    /// Delete an encryption key from Keychain
    /// - Parameter purpose: Description of key's purpose
    /// - Returns: True if deletion succeeded
    @discardableResult
    func deleteKey(for purpose: String) -> Bool {
        let service = Self.keychainService(for: purpose)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Get or create an encryption key for a purpose
    /// - Parameter purpose: Description of key's purpose
    /// - Returns: The key data
    func getOrCreateKey(for purpose: String) -> Data? {
        // Try to retrieve existing key
        if let existingKey = retrieveKey(for: purpose) {
            return existingKey
        }

        // Generate and store new key
        guard let newKey = generateKey() else {
            return nil
        }

        if storeKey(newKey, for: purpose) {
            return newKey
        }

        return nil
    }
}
