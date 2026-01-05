import Foundation

/// Protocol for embedding generation - allows swapping providers
protocol EmbeddingServiceProtocol: Sendable {
    /// Generate embedding for single text
    /// - Parameter text: The text to embed
    /// - Returns: Float array representing the embedding vector
    /// - Throws: EmbeddingError on failure
    func generateEmbedding(for text: String) async throws -> [Float]

    /// Generate embeddings for batch of texts (preserves input order)
    /// - Parameter texts: Array of texts to embed
    /// - Returns: Array of embeddings in same order as input
    /// - Throws: EmbeddingError on failure
    func generateEmbeddings(for texts: [String]) async throws -> [[Float]]

    /// Expected embedding dimensions
    var dimensions: Int { get }
}

// MARK: - Errors

/// Errors from embedding service operations
enum EmbeddingError: Error, Equatable {
    case emptyInput
    case privacyModeEnabled
    case missingAPIKey
    case networkError(String)
    case decodingFailed(String)
    case dimensionMismatch(expected: Int, got: Int)
    case serverError(statusCode: Int)
    case rateLimited(retryAfter: TimeInterval?)
    case httpError(statusCode: Int, message: String?)
    case invalidURL
    case timeout
    case cancelled
}

// MARK: - Default Implementation

extension EmbeddingServiceProtocol {
    /// Default batch implementation calls single embedding sequentially
    func generateEmbeddings(for texts: [String]) async throws -> [[Float]] {
        var results: [[Float]] = []
        for text in texts {
            let embedding = try await generateEmbedding(for: text)
            results.append(embedding)
        }
        return results
    }
}
