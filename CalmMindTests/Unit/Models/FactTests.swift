import XCTest
import SwiftData
@testable import CalmMind

/// Tests for Fact SwiftData model
final class FactTests: XCTestCase {

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

    func test_createFact_setsProperties() {
        let topic = Topic(name: "Alice", type: .person)
        let fact = Fact(content: "Works at Google", topic: topic)

        XCTAssertEqual(fact.content, "Works at Google")
        XCTAssertNotNil(fact.id)
        XCTAssertNotNil(fact.createdAt)
        XCTAssertNil(fact.lastReferencedAt)
        XCTAssertEqual(fact.relevanceScore, 0)
        XCTAssertNil(fact.embedding)
    }

    func test_fact_requiresTopic() {
        // Fact must be initialized with a topic (non-optional)
        let topic = Topic(name: "Alice", type: .person)
        let fact = Fact(content: "Test fact", topic: topic)

        // The topic property is non-optional, so it must be set
        XCTAssertEqual(fact.topic.name, "Alice")
    }

    // MARK: - Relevance Score

    func test_relevanceScore_defaultsToZero() {
        let topic = Topic(name: "Alice", type: .person)
        let fact = Fact(content: "Test", topic: topic)

        XCTAssertEqual(fact.relevanceScore, 0)
    }

    func test_relevanceScore_canBeUpdated() {
        let topic = Topic(name: "Alice", type: .person)
        let fact = Fact(content: "Test", topic: topic)

        fact.relevanceScore = 0.5
        XCTAssertEqual(fact.relevanceScore, 0.5, accuracy: 0.001)
    }

    func test_incrementRelevance_increasesScore() {
        let topic = Topic(name: "Alice", type: .person)
        let fact = Fact(content: "Test", topic: topic)

        fact.incrementRelevance()
        XCTAssertEqual(fact.relevanceScore, 0.1, accuracy: 0.001)

        fact.incrementRelevance()
        XCTAssertEqual(fact.relevanceScore, 0.2, accuracy: 0.001)
    }

    func test_incrementRelevance_customAmount() {
        let topic = Topic(name: "Alice", type: .person)
        let fact = Fact(content: "Test", topic: topic)

        fact.incrementRelevance(by: 0.25)
        XCTAssertEqual(fact.relevanceScore, 0.25, accuracy: 0.001)
    }

    func test_incrementRelevance_capsAt1() {
        let topic = Topic(name: "Alice", type: .person)
        let fact = Fact(content: "Test", topic: topic)
        fact.relevanceScore = 0.95

        fact.incrementRelevance(by: 0.2)
        XCTAssertEqual(fact.relevanceScore, 1.0, accuracy: 0.001)
    }

    func test_incrementRelevance_setsLastReferencedAt() {
        let topic = Topic(name: "Alice", type: .person)
        let fact = Fact(content: "Test", topic: topic)
        XCTAssertNil(fact.lastReferencedAt)

        let before = Date()
        fact.incrementRelevance()
        let after = Date()

        XCTAssertNotNil(fact.lastReferencedAt)
        XCTAssertGreaterThanOrEqual(fact.lastReferencedAt!, before)
        XCTAssertLessThanOrEqual(fact.lastReferencedAt!, after)
    }

    // MARK: - Embedding

    func test_embedding_roundTripsAsData() {
        let topic = Topic(name: "Alice", type: .person)
        let fact = Fact(content: "Test", topic: topic)

        let original: [Float] = [0.1, 0.2, 0.3, -0.5, 1.0]
        fact.embedding = original

        XCTAssertNotNil(fact.embedding)
        XCTAssertEqual(fact.embedding?.count, 5)
        for (o, u) in zip(original, fact.embedding ?? []) {
            XCTAssertEqual(o, u, accuracy: 0.0001)
        }
    }

    func test_embedding_nilByDefault() {
        let topic = Topic(name: "Alice", type: .person)
        let fact = Fact(content: "Test", topic: topic)
        XCTAssertNil(fact.embedding)
    }

    // MARK: - SwiftData Persistence

    func test_fact_persistsWithTopic() throws {
        let topic = Topic(name: "Alice", type: .person)
        context.insert(topic)

        let fact = Fact(content: "Works at Google", topic: topic)
        context.insert(fact)
        try context.save()

        let descriptor = FetchDescriptor<Fact>()
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.content, "Works at Google")
        XCTAssertEqual(fetched.first?.topic.name, "Alice")
    }

    func test_deleteFact_doesNotDeleteTopic() throws {
        let topic = Topic(name: "Alice", type: .person)
        context.insert(topic)

        let fact = Fact(content: "Works at Google", topic: topic)
        context.insert(fact)
        try context.save()

        // Delete fact
        context.delete(fact)
        try context.save()

        // Topic should still exist
        let topicDescriptor = FetchDescriptor<Topic>()
        let topics = try context.fetch(topicDescriptor)
        XCTAssertEqual(topics.count, 1)

        // Fact should be gone
        let factDescriptor = FetchDescriptor<Fact>()
        let facts = try context.fetch(factDescriptor)
        XCTAssertEqual(facts.count, 0)
    }

    // MARK: - Timestamps

    func test_createdAt_setOnInit() {
        let topic = Topic(name: "Alice", type: .person)
        let before = Date()
        let fact = Fact(content: "Test", topic: topic)
        let after = Date()

        XCTAssertGreaterThanOrEqual(fact.createdAt, before)
        XCTAssertLessThanOrEqual(fact.createdAt, after)
    }

    func test_lastReferencedAt_nilOnInit() {
        let topic = Topic(name: "Alice", type: .person)
        let fact = Fact(content: "Test", topic: topic)
        XCTAssertNil(fact.lastReferencedAt)
    }

    // MARK: - Unique ID

    func test_fact_uniqueId() throws {
        let topic = Topic(name: "Alice", type: .person)
        context.insert(topic)

        let fact1 = Fact(content: "Fact 1", topic: topic)
        let fact2 = Fact(content: "Fact 2", topic: topic)
        context.insert(fact1)
        context.insert(fact2)
        try context.save()

        XCTAssertNotEqual(fact1.id, fact2.id)
    }
}
