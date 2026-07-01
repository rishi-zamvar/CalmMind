import Foundation
import SwiftData

/// Repository for Topic and Fact CRUD operations
final class TopicRepository {
    private let context: ModelContext
    private let config: SemanticSearchConfig

    init(context: ModelContext, config: SemanticSearchConfig = .shared) {
        self.context = context
        self.config = config
    }

    // MARK: - Create

    /// Create or update a topic (upsert by canonical name hash)
    @discardableResult
    func create(name: String, type: TopicType) throws -> Topic {
        // Check if exists by hash first (upsert pattern)
        if let existing = try fetchByName(name) {
            existing.lastMentionedAt = Date()
            try context.save()
            return existing
        }

        let topic = Topic(name: name, type: type)
        context.insert(topic)
        try context.save()
        return topic
    }

    /// Add a fact to a topic
    @discardableResult
    func addFact(to topic: Topic, content: String) throws -> Fact {
        let fact = Fact(content: content, topic: topic)
        context.insert(fact)
        try context.save()
        return fact
    }

    // MARK: - Read by Name

    /// Fetch topic by name (case-insensitive, whitespace-normalized)
    func fetchByName(_ name: String) throws -> Topic? {
        let hash = Topic.computeNameHash(name)
        let descriptor = FetchDescriptor<Topic>(
            predicate: #Predicate { $0.nameHash == hash }
        )
        return try context.fetch(descriptor).first
    }

    // MARK: - Read by Type

    /// Fetch all topics of a specific type, ordered by last mentioned
    func fetchByType(_ type: TopicType) throws -> [Topic] {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<Topic>(
            predicate: #Predicate { $0.topicTypeRaw == typeRaw },
            sortBy: [SortDescriptor(\Topic.lastMentionedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Read with Embeddings

    /// Fetch topics that have embeddings, respecting config limit
    func fetchTopicsWithEmbeddings(limit: Int? = nil) throws -> [Topic] {
        let effectiveLimit = limit ?? config.maxTopicsForSearch
        var descriptor = FetchDescriptor<Topic>(
            predicate: #Predicate { $0.embeddingData != nil },
            sortBy: [SortDescriptor(\Topic.lastMentionedAt, order: .reverse)]
        )
        descriptor.fetchLimit = effectiveLimit
        return try context.fetch(descriptor)
    }

    // MARK: - Read Recent

    /// Fetch most recently mentioned topics
    func fetchRecent(limit: Int = 10) throws -> [Topic] {
        var descriptor = FetchDescriptor<Topic>(
            sortBy: [SortDescriptor(\Topic.lastMentionedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    // MARK: - Read All

    /// Fetch all topics
    func fetchAll() throws -> [Topic] {
        let descriptor = FetchDescriptor<Topic>()
        return try context.fetch(descriptor)
    }

    // MARK: - Count

    /// Count total topics
    func count() throws -> Int {
        let descriptor = FetchDescriptor<Topic>()
        return try context.fetchCount(descriptor)
    }

    // MARK: - Update

    /// Update embedding for a topic
    func updateEmbedding(for topic: Topic, embedding: [Float]) throws {
        topic.embedding = embedding
        try context.save()
    }

    /// Update last mentioned timestamp
    func updateLastMentioned(for topic: Topic) throws {
        topic.lastMentionedAt = Date()
        try context.save()
    }

    // MARK: - Delete

    /// Delete a topic (cascades to its facts)
    func delete(_ topic: Topic) throws {
        context.delete(topic)
        try context.save()
    }

    /// Delete a single fact (does not delete its topic)
    func deleteFact(_ fact: Fact) throws {
        context.delete(fact)
        try context.save()
    }
}
