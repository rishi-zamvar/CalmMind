import XCTest
import SwiftData
@testable import CalmMind

/// Tests for SemanticSearchGate - auto-enable semantic search context
/// TDD: These tests are written FIRST, implementation follows
final class SemanticSearchGateTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var topicRepository: TopicRepository!
    var userPreferences: UserPreferences!
    var config: SemanticSearchConfig!
    var gate: SemanticSearchGate!

    override func setUp() {
        super.setUp()

        // In-memory SwiftData container
        let schema = Schema([Topic.self, Fact.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)

        topicRepository = TopicRepository(context: context)
        userPreferences = UserPreferences(defaults: UserDefaults(suiteName: "test.\(UUID())")!)
        config = SemanticSearchConfig()  // Default config

        gate = SemanticSearchGate(
            topicRepository: topicRepository,
            config: config,
            userPreferences: userPreferences
        )
    }

    override func tearDown() {
        gate = nil
        config = nil
        userPreferences = nil
        topicRepository = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Helper

    private func createTopicWithEmbedding(name: String) throws {
        let topic = try topicRepository.create(name: name, type: .person)
        try topicRepository.updateEmbedding(for: topic, embedding: [0.1, 0.2, 0.3])
    }

    private func createTopicWithoutEmbedding(name: String) throws {
        _ = try topicRepository.create(name: name, type: .person)
    }

    // MARK: - shouldEnableContext Tests

    func test_shouldEnableContext_belowThreshold_returnsFalse() throws {
        // Create only 2 topics with embeddings (below default threshold of 5)
        try createTopicWithEmbedding(name: "Alice")
        try createTopicWithEmbedding(name: "Bob")

        let result = gate.shouldEnableContext()

        XCTAssertFalse(result)
    }

    func test_shouldEnableContext_atThreshold_returnsTrue() throws {
        // Create exactly 5 topics with embeddings (at threshold)
        for i in 1...5 {
            try createTopicWithEmbedding(name: "Person \(i)")
        }

        let result = gate.shouldEnableContext()

        XCTAssertTrue(result)
    }

    func test_shouldEnableContext_aboveThreshold_returnsTrue() throws {
        // Create 10 topics with embeddings (above threshold)
        for i in 1...10 {
            try createTopicWithEmbedding(name: "Person \(i)")
        }

        let result = gate.shouldEnableContext()

        XCTAssertTrue(result)
    }

    func test_shouldEnableContext_mixedTopics_countsOnlyWithEmbeddings() throws {
        // Create 3 with embeddings + 5 without = 3 with embeddings < 5 threshold
        try createTopicWithEmbedding(name: "Alice")
        try createTopicWithEmbedding(name: "Bob")
        try createTopicWithEmbedding(name: "Charlie")
        try createTopicWithoutEmbedding(name: "Dave")
        try createTopicWithoutEmbedding(name: "Eve")
        try createTopicWithoutEmbedding(name: "Frank")
        try createTopicWithoutEmbedding(name: "Grace")
        try createTopicWithoutEmbedding(name: "Heidi")

        let result = gate.shouldEnableContext()

        XCTAssertFalse(result, "Should only count topics WITH embeddings")
    }

    func test_shouldEnableContext_privacyMode_returnsFalse() throws {
        // Create 10 topics with embeddings
        for i in 1...10 {
            try createTopicWithEmbedding(name: "Person \(i)")
        }

        // Enable privacy mode
        userPreferences.privacyModeEnabled = true

        let result = gate.shouldEnableContext()

        XCTAssertFalse(result, "Privacy mode should disable semantic context")
    }

    func test_shouldEnableContext_emptyRepository_returnsFalse() {
        // No topics at all
        let result = gate.shouldEnableContext()

        XCTAssertFalse(result)
    }

    // MARK: - Threshold Configuration Tests

    func test_threshold_defaultIs5Topics() {
        let defaultConfig = SemanticSearchConfig()
        XCTAssertEqual(defaultConfig.autoEnableThreshold, 5)
    }

    func test_shouldEnableContext_customThreshold() throws {
        // Create custom config with threshold of 2
        let customConfig = SemanticSearchConfig(autoEnableThreshold: 2)
        let customGate = SemanticSearchGate(
            topicRepository: topicRepository,
            config: customConfig,
            userPreferences: userPreferences
        )

        // Create only 2 topics
        try createTopicWithEmbedding(name: "Alice")
        try createTopicWithEmbedding(name: "Bob")

        let result = customGate.shouldEnableContext()

        XCTAssertTrue(result, "Custom threshold of 2 should enable with 2 topics")
    }

    // MARK: - getStatus Tests

    func test_getStatus_returnsProgress() throws {
        // Create 3 topics with embeddings (3/5 = 0.6 progress)
        for i in 1...3 {
            try createTopicWithEmbedding(name: "Person \(i)")
        }

        let status = gate.getStatus()

        XCTAssertFalse(status.isEnabled)
        XCTAssertEqual(status.topicCount, 3)
        XCTAssertEqual(status.threshold, 5)
        XCTAssertEqual(status.progress, 0.6, accuracy: 0.01)
    }

    func test_getStatus_progressClampedTo1() throws {
        // Create 10 topics (10/5 = 2.0, but should clamp to 1.0)
        for i in 1...10 {
            try createTopicWithEmbedding(name: "Person \(i)")
        }

        let status = gate.getStatus()

        XCTAssertTrue(status.isEnabled)
        XCTAssertEqual(status.topicCount, 10)
        XCTAssertEqual(status.progress, 1.0, "Progress should be clamped to 1.0")
    }

    func test_getStatus_progressDescription_belowThreshold() throws {
        try createTopicWithEmbedding(name: "Alice")
        try createTopicWithEmbedding(name: "Bob")

        let status = gate.getStatus()

        XCTAssertEqual(status.progressDescription, "2/5 topics")
    }

    func test_getStatus_progressDescription_enabled() throws {
        for i in 1...7 {
            try createTopicWithEmbedding(name: "Person \(i)")
        }

        let status = gate.getStatus()

        XCTAssertEqual(status.progressDescription, "Active (7 topics)")
    }

    func test_getStatus_zeroTopics() {
        let status = gate.getStatus()

        XCTAssertFalse(status.isEnabled)
        XCTAssertEqual(status.topicCount, 0)
        XCTAssertEqual(status.threshold, 5)
        XCTAssertEqual(status.progress, 0.0)
        XCTAssertEqual(status.progressDescription, "0/5 topics")
    }

    // MARK: - Privacy Mode Status

    func test_getStatus_privacyMode_showsDisabled() throws {
        for i in 1...10 {
            try createTopicWithEmbedding(name: "Person \(i)")
        }

        userPreferences.privacyModeEnabled = true

        let status = gate.getStatus()

        // Status should still show topic count, but isEnabled should be false
        XCTAssertFalse(status.isEnabled, "Privacy mode should show disabled")
        XCTAssertEqual(status.topicCount, 10, "Topic count should still be accurate")
    }
}
