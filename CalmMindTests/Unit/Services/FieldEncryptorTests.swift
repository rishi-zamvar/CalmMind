import XCTest
@testable import CalmMind

final class FieldEncryptorTests: XCTestCase {

    var sut: FieldEncryptor!

    override func setUp() {
        super.setUp()
        sut = FieldEncryptor()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Key Generation

    func test_generateKey_creates256BitKey() {
        let key = sut.generateKey()

        XCTAssertNotNil(key)
        XCTAssertEqual(key?.count, 32) // 256 bits = 32 bytes
    }

    func test_generateKey_createsDifferentKeys() {
        let key1 = sut.generateKey()
        let key2 = sut.generateKey()

        XCTAssertNotNil(key1)
        XCTAssertNotNil(key2)
        XCTAssertNotEqual(key1, key2)
    }

    // MARK: - Encryption

    func test_encrypt_producesNonEmptyData() {
        let key = sut.generateKey()!
        let plaintext = "Secret message"

        let encrypted = sut.encrypt(plaintext, with: key)

        XCTAssertNotNil(encrypted)
        XCTAssertFalse(encrypted!.isEmpty)
    }

    func test_encrypt_producesDifferentOutput_forSameInput() {
        let key = sut.generateKey()!
        let plaintext = "Same message"

        let encrypted1 = sut.encrypt(plaintext, with: key)
        let encrypted2 = sut.encrypt(plaintext, with: key)

        // Due to random nonce, encrypted outputs should differ
        XCTAssertNotEqual(encrypted1, encrypted2)
    }

    func test_encrypt_handlesEmptyString() {
        let key = sut.generateKey()!

        let encrypted = sut.encrypt("", with: key)

        XCTAssertNotNil(encrypted)
    }

    func test_encrypt_handlesUnicodeCharacters() {
        let key = sut.generateKey()!
        let plaintext = "Hello 世界 🌍 émojis"

        let encrypted = sut.encrypt(plaintext, with: key)

        XCTAssertNotNil(encrypted)
    }

    // MARK: - Decryption

    func test_decrypt_recoversOriginalPlaintext() {
        let key = sut.generateKey()!
        let plaintext = "This is a secret message"

        let encrypted = sut.encrypt(plaintext, with: key)!
        let decrypted = sut.decrypt(encrypted, with: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    func test_decrypt_recoversUnicodeText() {
        let key = sut.generateKey()!
        let plaintext = "Unicode: 日本語 русский ελληνικά"

        let encrypted = sut.encrypt(plaintext, with: key)!
        let decrypted = sut.decrypt(encrypted, with: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    func test_decrypt_failsWithWrongKey() {
        let key1 = sut.generateKey()!
        let key2 = sut.generateKey()!
        let plaintext = "Secret message"

        let encrypted = sut.encrypt(plaintext, with: key1)!
        let decrypted = sut.decrypt(encrypted, with: key2)

        XCTAssertNil(decrypted)
    }

    func test_decrypt_failsWithCorruptedData() {
        let key = sut.generateKey()!
        var corruptedData = Data([1, 2, 3, 4, 5])

        let decrypted = sut.decrypt(corruptedData, with: key)

        XCTAssertNil(decrypted)
    }

    func test_decrypt_failsWithTamperedCiphertext() {
        let key = sut.generateKey()!
        let plaintext = "Tamper test"

        var encrypted = sut.encrypt(plaintext, with: key)!
        // Tamper with the ciphertext
        if encrypted.count > 20 {
            encrypted[20] ^= 0xFF
        }

        let decrypted = sut.decrypt(encrypted, with: key)

        XCTAssertNil(decrypted) // Authentication should fail
    }

    // MARK: - Data Encryption

    func test_encryptData_works() {
        let key = sut.generateKey()!
        let data = "Binary data test".data(using: .utf8)!

        let encrypted = sut.encryptData(data, with: key)

        XCTAssertNotNil(encrypted)
        XCTAssertNotEqual(encrypted, data)
    }

    func test_decryptData_recoversOriginal() {
        let key = sut.generateKey()!
        let originalData = "Test data for encryption".data(using: .utf8)!

        let encrypted = sut.encryptData(originalData, with: key)!
        let decrypted = sut.decryptData(encrypted, with: key)

        XCTAssertEqual(decrypted, originalData)
    }

    // MARK: - Edge Cases

    func test_encrypt_largeText() {
        let key = sut.generateKey()!
        let plaintext = String(repeating: "A", count: 100_000) // 100KB

        let encrypted = sut.encrypt(plaintext, with: key)
        let decrypted = sut.decrypt(encrypted!, with: key)

        XCTAssertEqual(decrypted, plaintext)
    }

    func test_roundTrip_multipleMessages() {
        let key = sut.generateKey()!
        let messages = [
            "First message",
            "Second message",
            "Third message with special chars: !@#$%^&*()"
        ]

        for message in messages {
            let encrypted = sut.encrypt(message, with: key)!
            let decrypted = sut.decrypt(encrypted, with: key)
            XCTAssertEqual(decrypted, message)
        }
    }
}
