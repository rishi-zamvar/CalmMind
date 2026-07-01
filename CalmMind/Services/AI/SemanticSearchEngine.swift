import Foundation
import SwiftData

/// Result of semantic search with scoring breakdown.
///
/// `@unchecked` because `topic` and `matchedFacts` are SwiftData model types that are
/// not statically Sendable; results are consumed synchronously on the caller's context.
struct TopicSearchResult: @unchecked Sendable {
    let topic: Topic
    let exactMatchScore: Float   // 0.0 or 1.0
    let semanticScore: Float     // 0.0 - 1.0
    let hybridScore: Float       // Computed via formula
    let matchedFacts: [Fact]
}

/// Hybrid semantic search engine - combines exact and semantic matching
final class SemanticSearchEngine {
    private let config: SemanticSearchConfig
    private let embeddingService: EmbeddingServiceProtocol
    private let topicRepository: TopicRepository
    private let userPreferences: UserPreferences

    init(
        config: SemanticSearchConfig = .shared,
        embeddingService: EmbeddingServiceProtocol,
        topicRepository: TopicRepository,
        userPreferences: UserPreferences = .shared
    ) {
        self.config = config
        self.embeddingService = embeddingService
        self.topicRepository = topicRepository
        self.userPreferences = userPreferences
    }

    // MARK: - Search

    /// Perform hybrid search (exact + semantic)
    func search(query: String, limit: Int? = nil) async throws -> [TopicSearchResult] {
        let effectiveLimit = limit ?? config.maxResultsDefault

        // Privacy mode → exact + recent only (no embedding calls)
        if userPreferences.privacyModeEnabled {
            return try await exactMatchPlusRecent(query: query, limit: effectiveLimit)
        }

        // Check if we have too many topics (performance ceiling)
        let topicsWithEmbeddings = try topicRepository.fetchTopicsWithEmbeddings()
        if topicsWithEmbeddings.count > config.maxTopicsForSearch {
            return try await exactMatchPlusRecent(query: query, limit: effectiveLimit)
        }

        // Full hybrid search
        return try await hybridSearch(query: query, limit: effectiveLimit)
    }

    // MARK: - Hybrid Search

    private func hybridSearch(query: String, limit: Int) async throws -> [TopicSearchResult] {
        // 1. Get query embedding
        let queryEmbedding = try await embeddingService.generateEmbedding(for: query)

        // 2. Exact match search
        var resultsByTopicId: [UUID: TopicSearchResult] = [:]

        if let exactMatch = try topicRepository.fetchByName(query) {
            let facts = Array(exactMatch.facts.prefix(config.maxFactsPerTopic))
            let semanticScore = computeSemanticScore(
                topicEmbedding: exactMatch.embedding,
                queryEmbedding: queryEmbedding
            )
            let hybridScore = Self.computeHybridScore(
                semantic: semanticScore,
                exact: 1.0,
                boost: config.exactMatchBoost
            )
            resultsByTopicId[exactMatch.id] = TopicSearchResult(
                topic: exactMatch,
                exactMatchScore: 1.0,
                semanticScore: semanticScore,
                hybridScore: hybridScore,
                matchedFacts: facts
            )
        }

        // 3. Semantic search
        let topicsWithEmbeddings = try topicRepository.fetchTopicsWithEmbeddings()
        for topic in topicsWithEmbeddings {
            guard resultsByTopicId[topic.id] == nil else { continue }  // Skip duplicates

            let semanticScore = computeSemanticScore(
                topicEmbedding: topic.embedding,
                queryEmbedding: queryEmbedding
            )

            guard semanticScore >= config.semanticThreshold else { continue }

            let facts = Array(topic.facts.prefix(config.maxFactsPerTopic))
            let hybridScore = Self.computeHybridScore(
                semantic: semanticScore,
                exact: 0.0,
                boost: config.exactMatchBoost
            )

            resultsByTopicId[topic.id] = TopicSearchResult(
                topic: topic,
                exactMatchScore: 0.0,
                semanticScore: semanticScore,
                hybridScore: hybridScore,
                matchedFacts: facts
            )
        }

        // 4. Sort by hybrid score and limit
        let sorted = resultsByTopicId.values.sorted { $0.hybridScore > $1.hybridScore }
        return Array(sorted.prefix(limit))
    }

    private func exactMatchPlusRecent(query: String, limit: Int) async throws -> [TopicSearchResult] {
        var results: [TopicSearchResult] = []

        // Exact match
        if let topic = try topicRepository.fetchByName(query) {
            let facts = Array(topic.facts.prefix(config.maxFactsPerTopic))
            results.append(TopicSearchResult(
                topic: topic,
                exactMatchScore: 1.0,
                semanticScore: 0.0,
                hybridScore: 1.0,
                matchedFacts: facts
            ))
        }

        // Fill with recent
        let recent = try topicRepository.fetchRecent(limit: limit)
        for topic in recent where !results.contains(where: { $0.topic.id == topic.id }) {
            let facts = Array(topic.facts.prefix(config.maxFactsPerTopic))
            results.append(TopicSearchResult(
                topic: topic,
                exactMatchScore: 0.0,
                semanticScore: 0.0,
                hybridScore: 0.0,
                matchedFacts: facts
            ))
            if results.count >= limit { break }
        }

        return results
    }

    // MARK: - Semantic Score

    private func computeSemanticScore(
        topicEmbedding: [Float]?,
        queryEmbedding: [Float]
    ) -> Float {
        guard let topicEmbedding = topicEmbedding else { return 0.0 }
        return max(0, Self.cosineSimilarity(topicEmbedding, queryEmbedding))
    }

    // MARK: - Static Helpers (Pure Functions)

    /// Cosine similarity between two vectors
    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? dot / denom : 0
    }

    /// Hybrid score: clamp(semantic + boost * exact, 0...1)
    static func computeHybridScore(
        semantic: Float,
        exact: Float,
        boost: Float
    ) -> Float {
        let raw = semantic + boost * exact
        return min(1.0, max(0.0, raw))
    }
}
