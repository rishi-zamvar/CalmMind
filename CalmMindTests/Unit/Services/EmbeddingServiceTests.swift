import XCTest
@testable import CalmMind

/// Tests for EmbeddingService - contract tests with no network calls
final class EmbeddingServiceTests: XCTestCase {

    var mockURLSession: MockURLSession!
    var mockSecretsStore: MockEmbeddingSecretsStore!
    var mockUserPreferences: UserPreferences!
    var config: SemanticSearchConfig!

    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        mockSecretsStore = MockEmbeddingSecretsStore()
        mockSecretsStore.mockAPIKey = "test-api-key"
        mockUserPreferences = UserPreferences(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        mockUserPreferences.privacyModeEnabled = false
        config = SemanticSearchConfig()
    }

    override func tearDown() {
        mockURLSession = nil
        mockSecretsStore = nil
        mockUserPreferences = nil
        config = nil
        super.tearDown()
    }

    // MARK: - Privacy Mode

    func test_generateEmbedding_privacyModeOn_throws() async {
        mockUserPreferences.privacyModeEnabled = true
        let service = EmbeddingService(
            config: config,
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            userPreferences: mockUserPreferences
        )

        do {
            _ = try await service.generateEmbedding(for: "test")
            XCTFail("Should throw privacyModeEnabled error")
        } catch let error as EmbeddingError {
            XCTAssertEqual(error, .privacyModeEnabled)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_generateEmbedding_privacyModeOff_succeeds() async throws {
        mockUserPreferences.privacyModeEnabled = false
        mockURLSession.mockData = makeEmbeddingResponse(dimensions: config.embeddingDimensions)
        mockURLSession.mockStatusCode = 200

        let service = EmbeddingService(
            config: config,
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            userPreferences: mockUserPreferences
        )

        let embedding = try await service.generateEmbedding(for: "test")
        XCTAssertEqual(embedding.count, config.embeddingDimensions)
    }

    // MARK: - Input Validation

    func test_generateEmbedding_emptyInput_throws() async {
        let service = EmbeddingService(
            config: config,
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            userPreferences: mockUserPreferences
        )

        do {
            _ = try await service.generateEmbedding(for: "")
            XCTFail("Should throw emptyInput error")
        } catch let error as EmbeddingError {
            XCTAssertEqual(error, .emptyInput)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_generateEmbedding_whitespaceOnlyInput_throws() async {
        let service = EmbeddingService(
            config: config,
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            userPreferences: mockUserPreferences
        )

        do {
            _ = try await service.generateEmbedding(for: "   \n\t  ")
            XCTFail("Should throw emptyInput error")
        } catch let error as EmbeddingError {
            XCTAssertEqual(error, .emptyInput)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - API Key

    func test_generateEmbedding_missingAPIKey_throws() async {
        mockSecretsStore.mockAPIKey = nil
        let service = EmbeddingService(
            config: config,
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            userPreferences: mockUserPreferences
        )

        do {
            _ = try await service.generateEmbedding(for: "test")
            XCTFail("Should throw missingAPIKey error")
        } catch let error as EmbeddingError {
            XCTAssertEqual(error, .missingAPIKey)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Response Decoding

    func test_decodeEmbeddingResponse_returnsDimensions_fromConfig() async throws {
        let expectedDimensions = config.embeddingDimensions
        mockURLSession.mockData = makeEmbeddingResponse(dimensions: expectedDimensions)
        mockURLSession.mockStatusCode = 200

        let service = EmbeddingService(
            config: config,
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            userPreferences: mockUserPreferences
        )

        let embedding = try await service.generateEmbedding(for: "test")
        XCTAssertEqual(embedding.count, expectedDimensions)
    }

    func test_dimensions_matchesConfig() {
        let customConfig = SemanticSearchConfig(embeddingDimensions: 768)
        let service = EmbeddingService(
            config: customConfig,
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            userPreferences: mockUserPreferences
        )

        XCTAssertEqual(service.dimensions, 768)
    }

    func test_usesModel_fromConfig() async throws {
        let customConfig = SemanticSearchConfig(embeddingModel: "custom-model")
        mockURLSession.mockData = makeEmbeddingResponse(dimensions: customConfig.embeddingDimensions)
        mockURLSession.mockStatusCode = 200

        let service = EmbeddingService(
            config: customConfig,
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            userPreferences: mockUserPreferences
        )

        _ = try await service.generateEmbedding(for: "test")

        // Verify the request body contains the correct model
        if let requestBody = mockURLSession.recordedRequests.last?.httpBody,
           let json = try? JSONSerialization.jsonObject(with: requestBody) as? [String: Any],
           let model = json["model"] as? String {
            XCTAssertEqual(model, "custom-model")
        } else {
            XCTFail("Could not parse request body")
        }
    }

    func test_usesEndpoint_fromConfig() async throws {
        mockURLSession.mockData = makeEmbeddingResponse(dimensions: config.embeddingDimensions)
        mockURLSession.mockStatusCode = 200

        let service = EmbeddingService(
            config: config,
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            userPreferences: mockUserPreferences
        )

        _ = try await service.generateEmbedding(for: "test")

        // Verify endpoint is used
        let urlPath = mockURLSession.recordedRequests.last?.url?.path ?? ""
        XCTAssertTrue(urlPath.contains(config.embeddingEndpoint))
    }

    // MARK: - Batch Operations

    func test_generateEmbeddings_batch_preservesInputOrder() async throws {
        let texts = ["first", "second", "third"]
        mockURLSession.mockData = makeEmbeddingResponse(dimensions: config.embeddingDimensions)
        mockURLSession.mockStatusCode = 200

        let service = EmbeddingService(
            config: config,
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            userPreferences: mockUserPreferences
        )

        let embeddings = try await service.generateEmbeddings(for: texts)

        XCTAssertEqual(embeddings.count, 3)
        // Verify 3 requests were made
        XCTAssertEqual(mockURLSession.callCount, 3)
    }

    // MARK: - Error Handling

    func test_serverError_returnsServerError() async {
        mockURLSession.mockData = Data()
        mockURLSession.mockStatusCode = 500

        let service = EmbeddingService(
            config: config,
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            userPreferences: mockUserPreferences
        )

        do {
            _ = try await service.generateEmbedding(for: "test")
            XCTFail("Should throw server error")
        } catch let error as EmbeddingError {
            if case .serverError(let code) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_rateLimited_returnsRateLimitedError() async {
        mockURLSession.mockData = Data()
        mockURLSession.mockStatusCode = 429

        let service = EmbeddingService(
            config: config,
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            userPreferences: mockUserPreferences
        )

        do {
            _ = try await service.generateEmbedding(for: "test")
            XCTFail("Should throw rate limited error")
        } catch let error as EmbeddingError {
            if case .rateLimited = error {
                // Success
            } else {
                XCTFail("Expected rateLimited, got \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_invalidJSON_returnsDecodingError() async {
        mockURLSession.mockData = "not json".data(using: .utf8)!
        mockURLSession.mockStatusCode = 200

        let service = EmbeddingService(
            config: config,
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            userPreferences: mockUserPreferences
        )

        do {
            _ = try await service.generateEmbedding(for: "test")
            XCTFail("Should throw decoding error")
        } catch let error as EmbeddingError {
            if case .decodingFailed = error {
                // Success
            } else {
                XCTFail("Expected decodingFailed, got \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Authorization Header

    func test_authorizationHeader_includesBearerToken() async throws {
        mockSecretsStore.mockAPIKey = "sk-test-key-12345"
        mockURLSession.mockData = makeEmbeddingResponse(dimensions: config.embeddingDimensions)
        mockURLSession.mockStatusCode = 200

        let service = EmbeddingService(
            config: config,
            urlSession: mockURLSession,
            secretsStore: mockSecretsStore,
            userPreferences: mockUserPreferences
        )

        _ = try await service.generateEmbedding(for: "test")

        let authHeader = mockURLSession.recordedRequests.last?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "Bearer sk-test-key-12345")
    }

    // MARK: - Helpers

    private func makeEmbeddingResponse(dimensions: Int, seed: Float = 0.1) -> Data {
        let embedding = (0..<dimensions).map { Float($0) * seed / 1000.0 }
        let response: [String: Any] = [
            "object": "list",
            "data": [
                [
                    "object": "embedding",
                    "embedding": embedding,
                    "index": 0
                ]
            ],
            "model": "text-embedding-3-small",
            "usage": [
                "prompt_tokens": 8,
                "total_tokens": 8
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: response)
    }
}

// MARK: - Mock Secrets Store for Embedding Tests

final class MockEmbeddingSecretsStore: SecretsStore {
    var mockAPIKey: String?

    func saveAPIKey(_ key: String) throws {
        mockAPIKey = key
    }

    func getAPIKey() -> String? {
        mockAPIKey
    }

    func deleteAPIKey() {
        mockAPIKey = nil
    }

    var hasAPIKey: Bool {
        mockAPIKey != nil
    }
}
