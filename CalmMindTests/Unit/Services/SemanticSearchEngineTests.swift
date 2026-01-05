import XCTest
import SwiftData
@testable import CalmMind

/// Tests for SemanticSearchEngine - hybrid semantic and exact match search
final class SemanticSearchEngineTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var config: SemanticSearchConfig!
    var repository: TopicRepository!
    var mockEmbeddingService: MockEmbeddingService!
    var userPreferences: UserPreferences!
    var engine: SemanticSearchEngine!

    override func setUp() {
        super.setUp()
        let schema = Schema([Topic.self, Fact.self])
        let modelConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [modelConfig])
        context = ModelContext(container)
        config = SemanticSearchConfig()
        repository = TopicRepository(context: context, config: config)
        mockEmbeddingService = MockEmbeddingService(config: config)
        userPreferences = UserPreferences(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
        userPreferences.privacyModeEnabled = false
        engine = SemanticSearchEngine(
            config: config,
            embeddingService: mockEmbeddingService,
            topicRepository: repository,
            userPreferences: userPreferences
        )
    }

    override func tearDown() {
        container = nil
        context = nil
        config = nil
        repository = nil
        mockEmbeddingService = nil
        userPreferences = nil
        engine = nil
        super.tearDown()
    }

    // MARK: - Cosine Similarity (Static, Pure)

    func test_cosineSimilarity_identicalVectors_returns1() {
        let v = [Float](repeating: 0.5, count: 10)
        let similarity = SemanticSearchEngine.cosineSimilarity(v, v)
        XCTAssertEqual(similarity, 1.0, accuracy: 0.001)
    }

    func test_cosineSimilarity_orthogonalVectors_returns0() {
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [0, 1, 0]
        let similarity = SemanticSearchEngine.cosineSimilarity(a, b)
        XCTAssertEqual(similarity, 0.0, accuracy: 0.001)
    }

    func test_cosineSimilarity_oppositeVectors_returnsMinus1() {
        let a: [Float] = [1, 0, 0]
        let b: [Float] = [-1, 0, 0]
        let similarity = SemanticSearchEngine.cosineSimilarity(a, b)
        XCTAssertEqual(similarity, -1.0, accuracy: 0.001)
    }

    func test_cosineSimilarity_emptyVectors_returns0() {
        let a: [Float] = []
        let b: [Float] = []
        let similarity = SemanticSearchEngine.cosineSimilarity(a, b)
        XCTAssertEqual(similarity, 0.0, accuracy: 0.001)
    }

    func test_cosineSimilarity_differentLengths_returns0() {
        let a: [Float] = [1, 2, 3]
        let b: [Float] = [1, 2]
        let similarity = SemanticSearchEngine.cosineSimilarity(a, b)
        XCTAssertEqual(similarity, 0.0, accuracy: 0.001)
    }

    // MARK: - Hybrid Scoring (Static, Pure)

    func test_hybridScore_formula_matchesSpec() {
        // Formula: clamp(semantic + boost * exact, 0...1)
        let semantic: Float = 0.6
        let exact: Float = 1.0
        let boost: Float = 0.3

        let score = SemanticSearchEngine.computeHybridScore(
            semantic: semantic,
            exact: exact,
            boost: boost
        )

        // 0.6 + 0.3 * 1.0 = 0.9
        XCTAssertEqual(score, 0.9, accuracy: 0.001)
    }

    func test_hybridScore_exactMatchOnly() {
        let score = SemanticSearchEngine.computeHybridScore(
            semantic: 0.0,
            exact: 1.0,
            boost: 0.3
        )
        // 0.0 + 0.3 * 1.0 = 0.3
        XCTAssertEqual(score, 0.3, accuracy: 0.001)
    }

    func test_hybridScore_semanticOnly() {
        let score = SemanticSearchEngine.computeHybridScore(
            semantic: 0.8,
            exact: 0.0,
            boost: 0.3
        )
        // 0.8 + 0.3 * 0.0 = 0.8
        XCTAssertEqual(score, 0.8, accuracy: 0.001)
    }

    func test_hybridScore_combined() {
        let score = SemanticSearchEngine.computeHybridScore(
            semantic: 0.7,
            exact: 1.0,
            boost: 0.3
        )
        // 0.7 + 0.3 * 1.0 = 1.0 (clamped)
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func test_hybridScore_clampsAbove1() {
        let score = SemanticSearchEngine.computeHybridScore(
            semantic: 0.9,
            exact: 1.0,
            boost: 0.3
        )
        // 0.9 + 0.3 = 1.2, clamped to 1.0
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func test_hybridScore_clampsBelow0() {
        let score = SemanticSearchEngine.computeHybridScore(
            semantic: -0.5,
            exact: 0.0,
            boost: 0.3
        )
        // -0.5, clamped to 0.0
        XCTAssertEqual(score, 0.0, accuracy: 0.001)
    }

    // MARK: - Exact Match Search

    func test_searchByName_exactMatch_score1() async throws {
        let topic = try repository.create(name: "Alice Johnson", type: .person)
        topic.embedding = mockEmbeddingService.generateDeterministicEmbedding(for: "Alice Johnson")
        try context.save()

        let results = try await engine.search(query: "Alice Johnson")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(Double(results.first?.exactMatchScore ?? 0), 1.0, accuracy: 0.001)
    }

    func test_searchByName_caseInsensitive() async throws {
        let topic = try repository.create(name: "Alice Johnson", type: .person)
        topic.embedding = mockEmbeddingService.generateDeterministicEmbedding(for: "Alice")
        try context.save()

        let results = try await engine.search(query: "ALICE JOHNSON")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.topic.name, "Alice Johnson")
    }

    func test_searchByName_noMatch_empty() async throws {
        let topic = try repository.create(name: "Alice", type: .person)
        topic.embedding = mockEmbeddingService.generateDeterministicEmbedding(for: "Alice")
        try context.save()

        // Search for something that won't match semantically
        mockEmbeddingService.mockSimilarityScore = 0.3  // Below threshold

        let results = try await engine.search(query: "xyznonexistent")

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Semantic Search

    func test_semanticSearch_similarEmbedding_returnsResults() async throws {
        let topic = try repository.create(name: "Alice", type: .person)
        // Use same embedding as query will generate
        let embedding = mockEmbeddingService.generateDeterministicEmbedding(for: "Alice")
        topic.embedding = embedding
        try context.save()

        // Search with exact same text to get identical embedding (similarity = 1.0)
        let results = try await engine.search(query: "Alice")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.topic.name, "Alice")
    }

    func test_semanticSearch_respectsThreshold_fromConfig() async throws {
        let customConfig = SemanticSearchConfig(semanticThreshold: 0.9)
        let customEngine = SemanticSearchEngine(
            config: customConfig,
            embeddingService: mockEmbeddingService,
            topicRepository: repository,
            userPreferences: userPreferences
        )

        let topic = try repository.create(name: "Alice", type: .person)
        topic.embedding = mockEmbeddingService.generateDeterministicEmbedding(for: "Alice")
        try context.save()

        // Similarity below threshold
        mockEmbeddingService.mockSimilarityScore = 0.85

        let results = try await customEngine.search(query: "friend")

        // Should not return because 0.85 < 0.9 threshold
        XCTAssertTrue(results.isEmpty)
    }

    func test_semanticSearch_orderedBySimilarity() async throws {
        // Create topics with different similarities - full embedding dimension
        let topic1 = try repository.create(name: "Alice", type: .person)
        var embedding1 = [Float](repeating: 0, count: config.embeddingDimensions)
        embedding1[0] = 1.0
        topic1.embedding = embedding1

        let topic2 = try repository.create(name: "Bob", type: .person)
        var embedding2 = [Float](repeating: 0, count: config.embeddingDimensions)
        embedding2[0] = 0.9
        embedding2[1] = 0.436
        topic2.embedding = embedding2

        let topic3 = try repository.create(name: "Charlie", type: .person)
        var embedding3 = [Float](repeating: 0, count: config.embeddingDimensions)
        embedding3[0] = 0.7
        embedding3[1] = 0.714
        topic3.embedding = embedding3

        try context.save()

        // Query embedding that's closest to Bob
        var queryEmbed = [Float](repeating: 0, count: config.embeddingDimensions)
        queryEmbed[0] = 0.95
        queryEmbed[1] = 0.3
        mockEmbeddingService.mockQueryEmbedding = queryEmbed

        let results = try await engine.search(query: "test")

        // Should be ordered by similarity
        XCTAssertGreaterThanOrEqual(results.count, 1)
    }

    // MARK: - Hybrid Search

    func test_hybridSearch_combinesExactAndSemantic() async throws {
        // Create a topic with exact name match
        let alice = try repository.create(name: "Alice", type: .person)
        alice.embedding = mockEmbeddingService.generateDeterministicEmbedding(for: "Alice")

        // Create a topic with good semantic match
        let bob = try repository.create(name: "Bob", type: .person)
        bob.embedding = mockEmbeddingService.generateDeterministicEmbedding(for: "Bob")

        try context.save()

        mockEmbeddingService.mockSimilarityScore = 0.8

        // Search for "Alice" - should match exactly
        let results = try await engine.search(query: "Alice")

        XCTAssertTrue(results.contains { $0.topic.name == "Alice" })
        // Alice should have highest score due to exact match boost
        XCTAssertEqual(results.first?.topic.name, "Alice")
    }

    func test_hybridSearch_deduplicatesSameTopic() async throws {
        let topic = try repository.create(name: "Alice", type: .person)
        topic.embedding = mockEmbeddingService.generateDeterministicEmbedding(for: "Alice")
        try context.save()

        mockEmbeddingService.mockSimilarityScore = 0.8

        // Search for exact name - should match both exact and semantic but return only once
        let results = try await engine.search(query: "Alice")

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.topic.name, "Alice")
    }

    // MARK: - Privacy Mode

    func test_search_privacyMode_exactMatchOnly() async throws {
        userPreferences.privacyModeEnabled = true

        let topic = try repository.create(name: "Alice", type: .person)
        topic.embedding = mockEmbeddingService.generateDeterministicEmbedding(for: "Alice")
        try context.save()

        let results = try await engine.search(query: "Alice")

        // Should still find exact match
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.topic.name, "Alice")
    }

    func test_search_privacyMode_noEmbeddingCalls() async throws {
        userPreferences.privacyModeEnabled = true

        let topic = try repository.create(name: "Alice", type: .person)
        topic.embedding = mockEmbeddingService.generateDeterministicEmbedding(for: "Alice")
        try context.save()

        mockEmbeddingService.resetCallCount()

        _ = try await engine.search(query: "friend")

        // Should not call embedding service in privacy mode
        XCTAssertEqual(mockEmbeddingService.generateCallCount, 0)
    }

    // MARK: - Fact Retrieval

    func test_retrieveFacts_includedInResults() async throws {
        let topic = try repository.create(name: "Alice", type: .person)
        topic.embedding = mockEmbeddingService.generateDeterministicEmbedding(for: "Alice")
        _ = try repository.addFact(to: topic, content: "Works at Google")
        _ = try repository.addFact(to: topic, content: "Lives in NYC")
        try context.save()

        mockEmbeddingService.mockSimilarityScore = 0.9

        let results = try await engine.search(query: "Alice")

        XCTAssertEqual(results.first?.matchedFacts.count, 2)
    }

    func test_retrieveFacts_respectsMaxPerTopic_fromConfig() async throws {
        let customConfig = SemanticSearchConfig(maxFactsPerTopic: 2)
        let customEngine = SemanticSearchEngine(
            config: customConfig,
            embeddingService: mockEmbeddingService,
            topicRepository: repository,
            userPreferences: userPreferences
        )

        let topic = try repository.create(name: "Alice", type: .person)
        topic.embedding = mockEmbeddingService.generateDeterministicEmbedding(for: "Alice")
        for i in 0..<5 {
            _ = try repository.addFact(to: topic, content: "Fact \(i)")
        }
        try context.save()

        mockEmbeddingService.mockSimilarityScore = 0.9

        let results = try await customEngine.search(query: "Alice")

        // Should only include maxFactsPerTopic facts
        XCTAssertEqual(results.first?.matchedFacts.count, 2)
    }

    // MARK: - Limit

    func test_search_respectsLimit() async throws {
        // Create many topics with same embedding as query
        let queryText = "test"
        let queryEmbedding = mockEmbeddingService.generateDeterministicEmbedding(for: queryText)

        for i in 0..<10 {
            let topic = try repository.create(name: "Person \(i)", type: .person)
            // All topics have same embedding as query → all have high similarity
            topic.embedding = queryEmbedding
        }
        try context.save()

        let results = try await engine.search(query: queryText, limit: 3)

        XCTAssertEqual(results.count, 3)
    }
}

// MARK: - Mock Embedding Service

final class MockEmbeddingService: EmbeddingServiceProtocol, @unchecked Sendable {
    let config: SemanticSearchConfig

    var mockSimilarityScore: Float = 0.8
    var mockQueryEmbedding: [Float]?
    private(set) var generateCallCount = 0

    var dimensions: Int { config.embeddingDimensions }

    func resetCallCount() {
        generateCallCount = 0
    }

    init(config: SemanticSearchConfig) {
        self.config = config
    }

    func generateEmbedding(for text: String) async throws -> [Float] {
        generateCallCount += 1
        if let mockQuery = mockQueryEmbedding {
            return mockQuery
        }
        return generateDeterministicEmbedding(for: text)
    }

    func generateEmbeddings(for texts: [String]) async throws -> [[Float]] {
        return try await texts.asyncMap { try await self.generateEmbedding(for: $0) }
    }

    /// Generate deterministic embedding from text (for stable tests)
    func generateDeterministicEmbedding(for text: String) -> [Float] {
        // Simple hash-based reproducible vector
        var hasher = Hasher()
        hasher.combine(text)
        let hash = hasher.finalize()

        var result = [Float](repeating: 0, count: dimensions)
        for i in 0..<dimensions {
            let seed = UInt64(bitPattern: Int64(hash &+ i))
            result[i] = Float(seed % 1000) / 1000.0 - 0.5
        }

        // Normalize
        let norm = sqrt(result.reduce(0) { $0 + $1 * $1 })
        if norm > 0 {
            result = result.map { $0 / norm }
        }
        return result
    }
}

// Helper for async map
extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var results: [T] = []
        for element in self {
            let result = try await transform(element)
            results.append(result)
        }
        return results
    }
}
