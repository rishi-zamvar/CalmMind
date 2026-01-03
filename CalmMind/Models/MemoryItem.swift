import Foundation
import SwiftData

/// A long-term memory about the user
@Model
final class MemoryItem {

    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique)
    var id: UUID

    /// The full memory content
    var content: String

    /// Short summary for context injection
    var summary: String?

    /// When this memory was noted
    var dateNoted: Date

    /// Vector embedding for similarity search (optional)
    var embedding: [Float]?

    /// Number of times this memory has been referenced in context
    var timesReferenced: Int

    /// When this memory was last referenced
    var lastReferencedAt: Date?

    /// Whether this memory is private (excluded from AI context)
    var isPrivate: Bool

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        content: String,
        summary: String? = nil,
        embedding: [Float]? = nil,
        isPrivate: Bool = false
    ) {
        self.id = id
        self.content = content
        self.summary = summary
        self.dateNoted = Date()
        self.embedding = embedding
        self.timesReferenced = 0
        self.lastReferencedAt = nil
        self.isPrivate = isPrivate
    }

    // MARK: - Actions

    /// Increment the reference count and update last referenced date
    func incrementReferenceCount() {
        timesReferenced += 1
        lastReferencedAt = Date()
    }
}
