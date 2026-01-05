import XCTest
import SwiftData
@testable import CalmMind

/// Tests for TopicRepository - CRUD operations for Topic and Fact
final class TopicRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var repository: TopicRepository!
    var config: SemanticSearchConfig!

    override func setUp() {
        super.setUp()
        let schema = Schema([Topic.self, Fact.self])
        let modelConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [modelConfig])
        context = ModelContext(container)
        config = SemanticSearchConfig()
        repository = TopicRepository(context: context, config: config)
    }

    override func tearDown() {
        container = nil
        context = nil
        repository = nil
        config = nil
        super.tearDown()
    }

    // MARK: - Create

    func test_createTopic_persistsToStore() throws {
        let topic = try repository.create(name: "Alice Johnson", type: .person)

        let descriptor = FetchDescriptor<Topic>()
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Alice Johnson")
        XCTAssertEqual(fetched.first?.id, topic.id)
    }

    func test_createTopic_generatesCanonicalNameHash() throws {
        let topic = try repository.create(name: "  Alice   JOHNSON  ", type: .person)

        // Should be hashed as "alice johnson"
        let expectedHash = Topic.computeNameHash("alice johnson")
        XCTAssertEqual(topic.nameHash, expectedHash)
    }

    func test_createTopic_duplicateName_updatesExisting() throws {
        let topic1 = try repository.create(name: "Alice", type: .person)
        let originalId = topic1.id

        // Create again with same name (different case)
        let topic2 = try repository.create(name: "ALICE", type: .person)

        // Should return same topic, not create duplicate
        XCTAssertEqual(topic2.id, originalId)

        // Should have updated lastMentionedAt
        XCTAssertNotNil(topic2.lastMentionedAt)

        // Only one topic in store
        let descriptor = FetchDescriptor<Topic>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
    }

    // MARK: - Read by Name

    func test_fetchByName_exactMatch() throws {
        _ = try repository.create(name: "Alice", type: .person)
        _ = try repository.create(name: "Bob", type: .person)

        let found = try repository.fetchByName("Alice")

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Alice")
    }

    func test_fetchByName_caseInsensitive() throws {
        _ = try repository.create(name: "Alice Johnson", type: .person)

        let found = try repository.fetchByName("ALICE JOHNSON")

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Alice Johnson")
    }

    func test_fetchByName_whitespaceNormalized() throws {
        _ = try repository.create(name: "Alice Johnson", type: .person)

        let found = try repository.fetchByName("  alice   johnson  ")

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Alice Johnson")
    }

    func test_fetchByName_notFound_returnsNil() throws {
        _ = try repository.create(name: "Alice", type: .person)

        let found = try repository.fetchByName("Bob")

        XCTAssertNil(found)
    }

    // MARK: - Read by Type

    func test_fetchByType_filtersByType() throws {
        _ = try repository.create(name: "Alice", type: .person)
        _ = try repository.create(name: "Bob", type: .person)
        _ = try repository.create(name: "Birthday Party", type: .event)
        _ = try repository.create(name: "Coffee Shop", type: .place)

        let people = try repository.fetchByType(.person)
        let events = try repository.fetchByType(.event)
        let places = try repository.fetchByType(.place)

        XCTAssertEqual(people.count, 2)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(places.count, 1)
    }

    func test_fetchByType_orderedByLastMentioned() throws {
        let topic1 = try repository.create(name: "Alice", type: .person)
        let topic2 = try repository.create(name: "Bob", type: .person)
        let topic3 = try repository.create(name: "Charlie", type: .person)

        // Update mention times
        topic1.lastMentionedAt = Date(timeIntervalSinceNow: -100)
        topic2.lastMentionedAt = Date(timeIntervalSinceNow: -50)  // Most recent
        topic3.lastMentionedAt = Date(timeIntervalSinceNow: -200)
        try context.save()

        let people = try repository.fetchByType(.person)

        // Should be ordered by most recent first
        XCTAssertEqual(people.first?.name, "Bob")
    }

    // MARK: - Read with Embeddings

    func test_fetchTopicsWithEmbeddings_excludesNil() throws {
        let topic1 = try repository.create(name: "Alice", type: .person)
        topic1.embedding = [0.1, 0.2, 0.3]

        let topic2 = try repository.create(name: "Bob", type: .person)
        // No embedding set

        let topic3 = try repository.create(name: "Charlie", type: .person)
        topic3.embedding = [0.4, 0.5, 0.6]

        try context.save()

        let withEmbeddings = try repository.fetchTopicsWithEmbeddings()

        XCTAssertEqual(withEmbeddings.count, 2)
        XCTAssertTrue(withEmbeddings.contains { $0.name == "Alice" })
        XCTAssertTrue(withEmbeddings.contains { $0.name == "Charlie" })
        XCTAssertFalse(withEmbeddings.contains { $0.name == "Bob" })
    }

    func test_fetchTopicsWithEmbeddings_respectsLimit_fromConfig() throws {
        // Create more topics than the limit
        let customConfig = SemanticSearchConfig(maxTopicsForSearch: 2)
        let customRepo = TopicRepository(context: context, config: customConfig)

        for i in 0..<5 {
            let topic = try customRepo.create(name: "Topic \(i)", type: .person)
            topic.embedding = [Float(i)]
            topic.lastMentionedAt = Date(timeIntervalSinceNow: Double(-i * 10))
        }
        try context.save()

        let withEmbeddings = try customRepo.fetchTopicsWithEmbeddings()

        XCTAssertEqual(withEmbeddings.count, 2)
    }

    // MARK: - Read Recent

    func test_fetchRecent_orderedByLastMentioned() throws {
        let topic1 = try repository.create(name: "Alice", type: .person)
        let topic2 = try repository.create(name: "Bob", type: .person)
        let topic3 = try repository.create(name: "Charlie", type: .person)

        topic1.lastMentionedAt = Date(timeIntervalSinceNow: -100)
        topic2.lastMentionedAt = Date(timeIntervalSinceNow: -10)  // Most recent
        topic3.lastMentionedAt = Date(timeIntervalSinceNow: -50)
        try context.save()

        let recent = try repository.fetchRecent(limit: 10)

        XCTAssertEqual(recent.first?.name, "Bob")
    }

    func test_fetchRecent_respectsLimit() throws {
        for i in 0..<10 {
            let topic = try repository.create(name: "Topic \(i)", type: .person)
            topic.lastMentionedAt = Date(timeIntervalSinceNow: Double(-i * 10))
        }
        try context.save()

        let recent = try repository.fetchRecent(limit: 3)

        XCTAssertEqual(recent.count, 3)
    }

    // MARK: - Update

    func test_updateEmbedding_setsEmbeddingData() throws {
        let topic = try repository.create(name: "Alice", type: .person)
        XCTAssertNil(topic.embedding)

        let embedding: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        try repository.updateEmbedding(for: topic, embedding: embedding)

        XCTAssertNotNil(topic.embedding)
        XCTAssertEqual(topic.embedding?.count, 5)
        XCTAssertEqual(topic.embedding?[0] ?? 0, 0.1, accuracy: 0.001)
    }

    func test_addFact_associatesWithTopic() throws {
        let topic = try repository.create(name: "Alice", type: .person)
        XCTAssertEqual(topic.facts.count, 0)

        let fact = try repository.addFact(to: topic, content: "Works at Google")

        XCTAssertEqual(topic.facts.count, 1)
        XCTAssertEqual(fact.content, "Works at Google")
        XCTAssertEqual(fact.topic.id, topic.id)
    }

    func test_updateLastMentioned_setsTimestamp() throws {
        let topic = try repository.create(name: "Alice", type: .person)
        XCTAssertNil(topic.lastMentionedAt)

        let before = Date()
        try repository.updateLastMentioned(for: topic)
        let after = Date()

        XCTAssertNotNil(topic.lastMentionedAt)
        XCTAssertGreaterThanOrEqual(topic.lastMentionedAt!, before)
        XCTAssertLessThanOrEqual(topic.lastMentionedAt!, after)
    }

    // MARK: - Delete

    func test_deleteTopic_cascadesDeleteToFacts() throws {
        let topic = try repository.create(name: "Alice", type: .person)
        _ = try repository.addFact(to: topic, content: "Fact 1")
        _ = try repository.addFact(to: topic, content: "Fact 2")

        // Verify facts exist
        let factDescriptor = FetchDescriptor<Fact>()
        let factsBefore = try context.fetch(factDescriptor)
        XCTAssertEqual(factsBefore.count, 2)

        // Delete topic
        try repository.delete(topic)

        // Facts should be deleted too
        let factsAfter = try context.fetch(factDescriptor)
        XCTAssertEqual(factsAfter.count, 0)
    }

    func test_deleteFact_doesNotDeleteTopic() throws {
        let topic = try repository.create(name: "Alice", type: .person)
        let fact = try repository.addFact(to: topic, content: "Test fact")

        try repository.deleteFact(fact)

        // Topic should still exist
        let topicDescriptor = FetchDescriptor<Topic>()
        let topics = try context.fetch(topicDescriptor)
        XCTAssertEqual(topics.count, 1)

        // Fact should be gone
        let factDescriptor = FetchDescriptor<Fact>()
        let facts = try context.fetch(factDescriptor)
        XCTAssertEqual(facts.count, 0)
    }

    // MARK: - Search All

    func test_fetchAll_returnsAllTopics() throws {
        _ = try repository.create(name: "Alice", type: .person)
        _ = try repository.create(name: "Bob", type: .person)
        _ = try repository.create(name: "Party", type: .event)

        let all = try repository.fetchAll()

        XCTAssertEqual(all.count, 3)
    }

    // MARK: - Count

    func test_count_returnsCorrectCount() throws {
        XCTAssertEqual(try repository.count(), 0)

        _ = try repository.create(name: "Alice", type: .person)
        XCTAssertEqual(try repository.count(), 1)

        _ = try repository.create(name: "Bob", type: .person)
        XCTAssertEqual(try repository.count(), 2)
    }
}
