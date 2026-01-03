import XCTest
@testable import CalmMind

final class SecretsStoreTests: XCTestCase {

    var sut: KeychainSecretsStore!

    override func setUp() {
        super.setUp()
        // Use a test-specific service name to avoid conflicts
        sut = KeychainSecretsStore(service: "com.calmmind.tests")
        // Clean up any existing test data
        sut.deleteAPIKey()
    }

    override func tearDown() {
        // Clean up after tests
        sut.deleteAPIKey()
        sut = nil
        super.tearDown()
    }

    // MARK: - Storage

    func test_saveAPIKey_persistsToKeychain() throws {
        let testKey = "sk-test-key-12345"

        try sut.saveAPIKey(testKey)

        let retrieved = sut.getAPIKey()
        XCTAssertEqual(retrieved, testKey)
    }

    func test_getAPIKey_returnsStoredKey() throws {
        let testKey = "sk-another-test-key"
        try sut.saveAPIKey(testKey)

        let result = sut.getAPIKey()

        XCTAssertEqual(result, testKey)
    }

    func test_deleteAPIKey_removesFromKeychain() throws {
        let testKey = "sk-delete-me"
        try sut.saveAPIKey(testKey)

        sut.deleteAPIKey()

        XCTAssertNil(sut.getAPIKey())
    }

    func test_getAPIKey_returnsNil_whenNotSet() {
        // Ensure no key exists
        sut.deleteAPIKey()

        let result = sut.getAPIKey()

        XCTAssertNil(result)
    }

    // MARK: - Update

    func test_saveAPIKey_overwritesExistingKey() throws {
        let firstKey = "sk-first-key"
        let secondKey = "sk-second-key"

        try sut.saveAPIKey(firstKey)
        try sut.saveAPIKey(secondKey)

        XCTAssertEqual(sut.getAPIKey(), secondKey)
    }

    // MARK: - Validation

    func test_hasAPIKey_returnsTrueWhenSet() throws {
        try sut.saveAPIKey("sk-test-key")

        XCTAssertTrue(sut.hasAPIKey)
    }

    func test_hasAPIKey_returnsFalseWhenNotSet() {
        sut.deleteAPIKey()

        XCTAssertFalse(sut.hasAPIKey)
    }

    // MARK: - Error Handling

    func test_saveAPIKey_throwsOnEmptyKey() {
        XCTAssertThrowsError(try sut.saveAPIKey("")) { error in
            XCTAssertTrue(error is SecretsStoreError)
        }
    }
}

// MARK: - Mock Tests

final class MockSecretsStoreTests: XCTestCase {

    func test_mockStore_worksInMemory() throws {
        let mock = MockSecretsStore()

        try mock.saveAPIKey("test-key")

        XCTAssertEqual(mock.getAPIKey(), "test-key")
    }

    func test_mockStore_canSimulateMissingKey() {
        let mock = MockSecretsStore()

        XCTAssertNil(mock.getAPIKey())
        XCTAssertFalse(mock.hasAPIKey)
    }

    func test_mockStore_canDeleteKey() throws {
        let mock = MockSecretsStore()
        try mock.saveAPIKey("to-delete")

        mock.deleteAPIKey()

        XCTAssertNil(mock.getAPIKey())
    }

    func test_mockStore_canSimulateError() {
        let mock = MockSecretsStore()
        mock.shouldThrowOnSave = true

        XCTAssertThrowsError(try mock.saveAPIKey("test"))
    }
}
