import Foundation
import SwiftData

/// A fact or bullet point about a Topic
@Model
final class Fact {
    @Attribute(.unique) var id: UUID = UUID()
    var content: String
    var embeddingData: Data?  // Packed floats for SwiftData compatibility
    var createdAt: Date = Date()
    var lastReferencedAt: Date?
    var relevanceScore: Float = 0

    // Non-optional relationship to Topic (inverse defined on Topic.facts)
    var topic: Topic

    // MARK: - Computed Properties

    /// Embedding as float array (nil if no embedding stored)
    var embedding: [Float]? {
        get { embeddingData.flatMap { Topic.unpackEmbedding($0) } }
        set { embeddingData = newValue.flatMap { Topic.packEmbedding($0) } }
    }

    // MARK: - Initialization

    init(content: String, topic: Topic) {
        self.content = content
        self.topic = topic
    }

    // MARK: - Relevance Management

    /// Increment relevance score and update last referenced timestamp
    /// - Parameter amount: Amount to increment (default 0.1)
    func incrementRelevance(by amount: Float = 0.1) {
        relevanceScore = min(1.0, relevanceScore + amount)
        lastReferencedAt = Date()
    }
}
