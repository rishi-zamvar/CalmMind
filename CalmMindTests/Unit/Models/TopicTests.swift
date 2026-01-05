import XCTest
import SwiftData
import CryptoKit
@testable import CalmMind

/// Tests for Topic SwiftData model
final class TopicTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([Topic.self, Fact.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Creation

    func test_createTopic_setsProperties() {
        let topic = Topic(name: "Alice Johnson", type: .person)

        XCTAssertEqual(topic.name, "Alice Johnson")
        XCTAssertEqual(topic.topicType, .person)
        XCTAssertNotNil(topic.id)
        XCTAssertNotNil(topic.createdAt)
        XCTAssertNil(topic.lastMentionedAt)
        XCTAssertNil(topic.embedding)
        XCTAssertTrue(topic.facts.isEmpty)
    }

    func test_createTopic_setsNameHash() {
        let topic = Topic(name: "Alice Johnson", type: .person)
        XCTAssertFalse(topic.nameHash.isEmpty)
    }

    func test_createTopic_differentTypes() {
        let person = Topic(name: "Bob", type: .person)
        let event = Topic(name: "Birthday Party", type: .event)
        let place = Topic(name: "Coffee Shop", type: .place)

        XCTAssertEqual(person.topicType, .person)
        XCTAssertEqual(event.topicType, .event)
        XCTAssertEqual(place.topicType, .place)
    }

    // MARK: - Name Hash

    func test_nameHash_caseInsensitive() {
        let hash1 = Topic.computeNameHash("Alice")
        let hash2 = Topic.computeNameHash("ALICE")
        let hash3 = Topic.computeNameHash("alice")

        XCTAssertEqual(hash1, hash2)
        XCTAssertEqual(hash2, hash3)
    }

    func test_nameHash_consistentForSameName() {
        let hash1 = Topic.computeNameHash("John Smith")
        let hash2 = Topic.computeNameHash("John Smith")

        XCTAssertEqual(hash1, hash2)
    }

    func test_nameHash_canonicalizes_whitespace() {
        let hash1 = Topic.computeNameHash("John Smith")
        let hash2 = Topic.computeNameHash("  John   Smith  ")
        let hash3 = Topic.computeNameHash("\tJohn\nSmith\t")

        XCTAssertEqual(hash1, hash2)
        XCTAssertEqual(hash2, hash3)
    }

    func test_nameHash_differentNamesAreDifferent() {
        let hash1 = Topic.computeNameHash("Alice")
        let hash2 = Topic.computeNameHash("Bob")

        XCTAssertNotEqual(hash1, hash2)
    }

    // MARK: - Canonicalize

    func test_canonicalize_lowercases() {
        XCTAssertEqual(Topic.canonicalize("ALICE"), "alice")
        XCTAssertEqual(Topic.canonicalize("Alice"), "alice")
    }

    func test_canonicalize_trims() {
        XCTAssertEqual(Topic.canonicalize("  alice  "), "alice")
        XCTAssertEqual(Topic.canonicalize("\talice\n"), "alice")
    }

    func test_canonicalize_collapsesWhitespace() {
        XCTAssertEqual(Topic.canonicalize("john   smith"), "john smith")
        XCTAssertEqual(Topic.canonicalize("john\t\nsmith"), "john smith")
    }

    func test_canonicalize_combined() {
        XCTAssertEqual(Topic.canonicalize("  John   SMITH  "), "john smith")
    }

    // MARK: - Embedding Pack/Unpack

    func test_embedding_roundTripsAsData() {
        let original: [Float] = [0.1, 0.2, 0.3, -0.5, 1.0]
        let packed = Topic.packEmbedding(original)
        let unpacked = Topic.unpackEmbedding(packed)

        XCTAssertEqual(original.count, unpacked.count)
        for (o, u) in zip(original, unpacked) {
            XCTAssertEqual(o, u, accuracy: 0.0001)
        }
    }

    func test_embedding_emptyArray() {
        let original: [Float] = []
        let packed = Topic.packEmbedding(original)
        let unpacked = Topic.unpackEmbedding(packed)

        XCTAssertEqual(unpacked.count, 0)
    }

    func test_embedding_largeArray() {
        // 1536 dimensions like text-embedding-3-small
        let config = SemanticSearchConfig()
        let original = (0..<config.embeddingDimensions).map { Float($0) / 1000.0 }
        let packed = Topic.packEmbedding(original)
        let unpacked = Topic.unpackEmbedding(packed)

        XCTAssertEqual(original.count, unpacked.count)
        XCTAssertEqual(original.count, config.embeddingDimensions)
    }

    func test_embedding_propertyAccessors() {
        let topic = Topic(name: "Test", type: .person)
        XCTAssertNil(topic.embedding)

        let floats: [Float] = [0.1, 0.2, 0.3]
        topic.embedding = floats

        XCTAssertNotNil(topic.embedding)
        XCTAssertEqual(topic.embedding?.count, 3)
        XCTAssertEqual(topic.embedding?[0] ?? 0, 0.1, accuracy: 0.0001)
    }

    // MARK: - TopicType Computed Property

    func test_topicType_getsFromRaw() {
        let topic = Topic(name: "Test", type: .event)
        XCTAssertEqual(topic.topicType, .event)
        XCTAssertEqual(topic.topicTypeRaw, "event")
    }

    func test_topicType_setsRaw() {
        let topic = Topic(name: "Test", type: .person)
        topic.topicType = .place
        XCTAssertEqual(topic.topicType, .place)
        XCTAssertEqual(topic.topicTypeRaw, "place")
    }

    func test_topicType_invalidRaw_defaultsToPerson() {
        let topic = Topic(name: "Test", type: .person)
        topic.topicTypeRaw = "invalid"
        // Should default to person for safety
        XCTAssertEqual(topic.topicType, .person)
    }

    // MARK: - SwiftData Persistence

    func test_topic_persistsToContext() throws {
        let topic = Topic(name: "Persisted Topic", type: .event)
        context.insert(topic)
        try context.save()

        let descriptor = FetchDescriptor<Topic>()
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Persisted Topic")
    }

    func test_topic_uniqueId() throws {
        let topic1 = Topic(name: "Topic 1", type: .person)
        let topic2 = Topic(name: "Topic 2", type: .person)
        context.insert(topic1)
        context.insert(topic2)
        try context.save()

        XCTAssertNotEqual(topic1.id, topic2.id)
    }

    // MARK: - Facts Relationship

    func test_facts_initiallyEmpty() {
        let topic = Topic(name: "Test", type: .person)
        XCTAssertTrue(topic.facts.isEmpty)
    }

    func test_facts_canAddFact() throws {
        let topic = Topic(name: "Test", type: .person)
        context.insert(topic)

        let fact = Fact(content: "Works at Google", topic: topic)
        context.insert(fact)
        try context.save()

        XCTAssertEqual(topic.facts.count, 1)
        XCTAssertEqual(topic.facts.first?.content, "Works at Google")
    }

    func test_facts_cascadeDeletesOnTopicDelete() throws {
        let topic = Topic(name: "Test", type: .person)
        context.insert(topic)

        let fact1 = Fact(content: "Fact 1", topic: topic)
        let fact2 = Fact(content: "Fact 2", topic: topic)
        context.insert(fact1)
        context.insert(fact2)
        try context.save()

        // Verify facts exist
        let factDescriptor = FetchDescriptor<Fact>()
        let factsBeforeDelete = try context.fetch(factDescriptor)
        XCTAssertEqual(factsBeforeDelete.count, 2)

        // Delete topic
        context.delete(topic)
        try context.save()

        // Facts should be deleted too
        let factsAfterDelete = try context.fetch(factDescriptor)
        XCTAssertEqual(factsAfterDelete.count, 0)
    }

    // MARK: - Timestamps

    func test_createdAt_setOnInit() {
        let before = Date()
        let topic = Topic(name: "Test", type: .person)
        let after = Date()

        XCTAssertGreaterThanOrEqual(topic.createdAt, before)
        XCTAssertLessThanOrEqual(topic.createdAt, after)
    }

    func test_lastMentionedAt_nilOnInit() {
        let topic = Topic(name: "Test", type: .person)
        XCTAssertNil(topic.lastMentionedAt)
    }

    func test_lastMentionedAt_canBeSet() {
        let topic = Topic(name: "Test", type: .person)
        let now = Date()
        topic.lastMentionedAt = now
        XCTAssertEqual(topic.lastMentionedAt, now)
    }
}
