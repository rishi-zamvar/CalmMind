import XCTest
import SwiftData
@testable import CalmMind

/// Tests for SemanticContextBuilder - formats search results for AI context
/// TDD: These tests are written FIRST, implementation follows
final class SemanticContextBuilderTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var config: SemanticSearchConfig!

    override func setUp() {
        super.setUp()

        // In-memory SwiftData container
        let schema = Schema([Topic.self, Fact.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)

        config = SemanticSearchConfig()  // Default config
    }

    override func tearDown() {
        config = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func createTopic(name: String) -> Topic {
        let topic = Topic(name: name, type: .person)
        context.insert(topic)
        try! context.save()
        return topic
    }

    private func createFact(content: String, topic: Topic) -> Fact {
        let fact = Fact(content: content, topic: topic)
        context.insert(fact)
        try! context.save()
        return fact
    }

    private func createSearchResult(
        topic: Topic,
        matchedFacts: [Fact],
        semanticScore: Float = 0.9
    ) -> TopicSearchResult {
        TopicSearchResult(
            topic: topic,
            exactMatchScore: 0.0,
            semanticScore: semanticScore,
            hybridScore: semanticScore,
            matchedFacts: matchedFacts
        )
    }

    // MARK: - Empty Results

    func test_buildContext_emptyResults_returnsNil() {
        let result = SemanticContextBuilder.buildContext(from: [], config: config)

        XCTAssertNil(result)
    }

    // MARK: - Basic Formatting

    func test_buildContext_formatsAsBulletPoints() {
        let topic = createTopic(name: "Alice")
        let fact1 = createFact(content: "Works at Google", topic: topic)
        let fact2 = createFact(content: "Lives in San Francisco", topic: topic)

        let results = [createSearchResult(topic: topic, matchedFacts: [fact1, fact2])]

        let context = SemanticContextBuilder.buildContext(from: results, config: config)

        XCTAssertNotNil(context)
        XCTAssertTrue(context!.contains("• Works at Google"))
        XCTAssertTrue(context!.contains("• Lives in San Francisco"))
    }

    func test_buildContext_includesHeader() {
        let topic = createTopic(name: "Alice")
        let fact = createFact(content: "Works at Google", topic: topic)

        let results = [createSearchResult(topic: topic, matchedFacts: [fact])]

        let context = SemanticContextBuilder.buildContext(from: results, config: config)

        XCTAssertTrue(context!.contains("Relevant context from your memory:"))
    }

    func test_buildContext_includesTopicName() {
        let topic = createTopic(name: "Alice Smith")
        let fact = createFact(content: "Works at Google", topic: topic)

        let results = [createSearchResult(topic: topic, matchedFacts: [fact])]

        let context = SemanticContextBuilder.buildContext(from: results, config: config)

        XCTAssertTrue(context!.contains("## Alice Smith"))
    }

    // MARK: - Limits

    func test_buildContext_respectsMaxTopics() {
        // Create 5 topics (more than default maxContextTopics of 3)
        var results: [TopicSearchResult] = []
        for i in 1...5 {
            let topic = createTopic(name: "Person \(i)")
            let fact = createFact(content: "Fact about person \(i)", topic: topic)
            results.append(createSearchResult(topic: topic, matchedFacts: [fact]))
        }

        let context = SemanticContextBuilder.buildContext(from: results, config: config)

        // Should only include first 3 (maxContextTopics default)
        XCTAssertTrue(context!.contains("## Person 1"))
        XCTAssertTrue(context!.contains("## Person 2"))
        XCTAssertTrue(context!.contains("## Person 3"))
        XCTAssertFalse(context!.contains("## Person 4"))
        XCTAssertFalse(context!.contains("## Person 5"))
    }

    func test_buildContext_respectsMaxFacts() {
        let topic = createTopic(name: "Alice")
        // Create 7 facts (more than default maxContextFacts of 5)
        var facts: [Fact] = []
        for i in 1...7 {
            facts.append(createFact(content: "Fact \(i)", topic: topic))
        }

        let results = [createSearchResult(topic: topic, matchedFacts: facts)]

        let context = SemanticContextBuilder.buildContext(from: results, config: config)

        // Should only include first 5 facts
        XCTAssertTrue(context!.contains("• Fact 1"))
        XCTAssertTrue(context!.contains("• Fact 5"))
        XCTAssertFalse(context!.contains("• Fact 6"))
        XCTAssertFalse(context!.contains("• Fact 7"))
    }

    func test_buildContext_customConfigLimits() {
        // Custom config with lower limits
        let customConfig = SemanticSearchConfig(maxContextTopics: 1, maxContextFacts: 2)

        let topic1 = createTopic(name: "Alice")
        let topic2 = createTopic(name: "Bob")
        let facts = [
            createFact(content: "Fact A", topic: topic1),
            createFact(content: "Fact B", topic: topic1),
            createFact(content: "Fact C", topic: topic1)
        ]

        let results = [
            createSearchResult(topic: topic1, matchedFacts: facts),
            createSearchResult(topic: topic2, matchedFacts: [])
        ]

        let context = SemanticContextBuilder.buildContext(from: results, config: customConfig)

        // Should only include 1 topic
        XCTAssertTrue(context!.contains("## Alice"))
        XCTAssertFalse(context!.contains("## Bob"))

        // Should only include 2 facts
        XCTAssertTrue(context!.contains("• Fact A"))
        XCTAssertTrue(context!.contains("• Fact B"))
        XCTAssertFalse(context!.contains("• Fact C"))
    }

    // MARK: - Deterministic Output

    func test_buildContext_deterministicNewlines() {
        let topic = createTopic(name: "Alice")
        let fact = createFact(content: "Works at Google", topic: topic)

        let results = [createSearchResult(topic: topic, matchedFacts: [fact])]

        let context = SemanticContextBuilder.buildContext(from: results, config: config)!

        // Should NOT end with a trailing newline
        XCTAssertFalse(context.hasSuffix("\n"))

        // Each line should be separated by \n
        let lines = context.components(separatedBy: "\n")
        XCTAssertTrue(lines.count >= 3)  // Header, topic header, fact
    }

    // MARK: - Multiple Topics

    func test_buildContext_multipleTopics_formattedWithBlankLines() {
        let topic1 = createTopic(name: "Alice")
        let topic2 = createTopic(name: "Bob")
        let fact1 = createFact(content: "Alice works at Google", topic: topic1)
        let fact2 = createFact(content: "Bob works at Apple", topic: topic2)

        let results = [
            createSearchResult(topic: topic1, matchedFacts: [fact1]),
            createSearchResult(topic: topic2, matchedFacts: [fact2])
        ]

        let context = SemanticContextBuilder.buildContext(from: results, config: config)!

        // Topics should be separated by blank line
        XCTAssertTrue(context.contains("\n\n## Alice"))
        XCTAssertTrue(context.contains("\n\n## Bob"))
    }

    // MARK: - Edge Cases

    func test_buildContext_topicWithNoFacts_stillShowsTopic() {
        let topic = createTopic(name: "Alice")
        let results = [createSearchResult(topic: topic, matchedFacts: [])]

        let context = SemanticContextBuilder.buildContext(from: results, config: config)

        // Topic should still appear even with no facts
        XCTAssertNotNil(context)
        XCTAssertTrue(context!.contains("## Alice"))
    }

    func test_buildContext_specialCharactersInContent() {
        let topic = createTopic(name: "Alice's Work")
        let fact = createFact(content: "She works at Google & Amazon (tech companies)", topic: topic)

        let results = [createSearchResult(topic: topic, matchedFacts: [fact])]

        let context = SemanticContextBuilder.buildContext(from: results, config: config)

        XCTAssertTrue(context!.contains("## Alice's Work"))
        XCTAssertTrue(context!.contains("Google & Amazon"))
    }
}
