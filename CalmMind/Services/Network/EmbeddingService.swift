import Foundation

/// Service for generating text embeddings via OpenAI API
// `@unchecked` because stored dependencies (SecretsStore, UserPreferences) are not
// statically Sendable; they are only accessed for reads, so the class is thread-safe.
final class EmbeddingService: EmbeddingServiceProtocol, @unchecked Sendable {

    // MARK: - Constants

    private static let baseURL = "https://api.openai.com"

    // MARK: - Dependencies

    private let config: SemanticSearchConfig
    private let urlSession: URLSessionProtocol
    private let secretsStore: SecretsStore
    private let userPreferences: UserPreferences

    // MARK: - EmbeddingServiceProtocol

    var dimensions: Int { config.embeddingDimensions }

    // MARK: - Initialization

    init(
        config: SemanticSearchConfig = .shared,
        urlSession: URLSessionProtocol = URLSession.shared,
        secretsStore: SecretsStore = KeychainSecretsStore.shared,
        userPreferences: UserPreferences = .shared
    ) {
        self.config = config
        self.urlSession = urlSession
        self.secretsStore = secretsStore
        self.userPreferences = userPreferences
    }

    // MARK: - Generate Embedding

    func generateEmbedding(for text: String) async throws -> [Float] {
        // Privacy gate - skip embedding when privacy mode on
        guard !userPreferences.privacyModeEnabled else {
            throw EmbeddingError.privacyModeEnabled
        }

        // Validate input
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmbeddingError.emptyInput
        }

        // Check API key
        guard let apiKey = secretsStore.getAPIKey() else {
            throw EmbeddingError.missingAPIKey
        }

        // Build request
        let request = try buildRequest(apiKey: apiKey, text: text)

        // Execute request
        let (data, response) = try await urlSession.data(for: request)

        // Handle response
        return try handleResponse(data: data, response: response)
    }

    func generateEmbeddings(for texts: [String]) async throws -> [[Float]] {
        // Use default implementation from protocol extension (sequential calls)
        var results: [[Float]] = []
        for text in texts {
            let embedding = try await generateEmbedding(for: text)
            results.append(embedding)
        }
        return results
    }

    // MARK: - Private Methods

    private func buildRequest(apiKey: String, text: String) throws -> URLRequest {
        guard let url = URL(string: Self.baseURL + config.embeddingEndpoint) else {
            throw EmbeddingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = EmbeddingRequest(
            input: text,
            model: config.embeddingModel
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw EmbeddingError.decodingFailed("Failed to encode request: \(error.localizedDescription)")
        }

        return request
    }

    private func handleResponse(data: Data, response: URLResponse) throws -> [Float] {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbeddingError.decodingFailed("Invalid response type")
        }

        // Handle error status codes
        if httpResponse.statusCode != 200 {
            throw errorForStatusCode(httpResponse.statusCode, data: data)
        }

        // Parse response
        do {
            let apiResponse = try JSONDecoder().decode(EmbeddingAPIResponse.self, from: data)
            guard let firstEmbedding = apiResponse.data.first?.embedding else {
                throw EmbeddingError.decodingFailed("No embedding in response")
            }
            return firstEmbedding
        } catch let error as EmbeddingError {
            throw error
        } catch {
            throw EmbeddingError.decodingFailed(error.localizedDescription)
        }
    }

    private func errorForStatusCode(_ statusCode: Int, data: Data?) -> EmbeddingError {
        switch statusCode {
        case 429:
            return .rateLimited(retryAfter: nil)
        case 500, 502, 503, 504:
            return .serverError(statusCode: statusCode)
        default:
            var message: String?
            if let data = data,
               let errorResponse = try? JSONDecoder().decode(EmbeddingErrorResponse.self, from: data) {
                message = errorResponse.error.message
            }
            return .httpError(statusCode: statusCode, message: message)
        }
    }
}

// MARK: - Request/Response Types

private struct EmbeddingRequest: Codable {
    let input: String
    let model: String
}

private struct EmbeddingAPIResponse: Codable {
    let object: String
    let data: [EmbeddingData]
    let model: String
    let usage: EmbeddingUsage

    struct EmbeddingData: Codable {
        let object: String
        let embedding: [Float]
        let index: Int
    }

    struct EmbeddingUsage: Codable {
        let promptTokens: Int
        let totalTokens: Int

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

private struct EmbeddingErrorResponse: Codable {
    let error: EmbeddingAPIError

    struct EmbeddingAPIError: Codable {
        let message: String
        let type: String
        let code: String?
    }
}
