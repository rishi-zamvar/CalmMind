import Foundation
@testable import CalmMind

/// In-memory mock for SecretsStore, used in tests
final class MockSecretsStore: SecretsStore {

    // MARK: - State

    private var storedKey: String?

    // MARK: - Test Configuration

    /// Set to true to simulate save failures
    var shouldThrowOnSave = false

    /// Custom error to throw (if shouldThrowOnSave is true)
    var errorToThrow: Error = SecretsStoreError.keychainError(-1)

    // MARK: - Call Tracking

    private(set) var saveAPIKeyCallCount = 0
    private(set) var getAPIKeyCallCount = 0
    private(set) var deleteAPIKeyCallCount = 0
    private(set) var lastSavedKey: String?

    // MARK: - SecretsStore

    func saveAPIKey(_ key: String) throws {
        saveAPIKeyCallCount += 1
        lastSavedKey = key

        if shouldThrowOnSave {
            throw errorToThrow
        }

        guard !key.isEmpty else {
            throw SecretsStoreError.emptyKey
        }

        storedKey = key
    }

    func getAPIKey() -> String? {
        getAPIKeyCallCount += 1
        return storedKey
    }

    func deleteAPIKey() {
        deleteAPIKeyCallCount += 1
        storedKey = nil
    }

    var hasAPIKey: Bool {
        storedKey != nil
    }

    // MARK: - Test Helpers

    /// Reset all state and call counts
    func reset() {
        storedKey = nil
        shouldThrowOnSave = false
        saveAPIKeyCallCount = 0
        getAPIKeyCallCount = 0
        deleteAPIKeyCallCount = 0
        lastSavedKey = nil
    }

    /// Pre-populate with a key (without going through saveAPIKey)
    func setStoredKey(_ key: String?) {
        storedKey = key
    }
}
