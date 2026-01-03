import Foundation
import SwiftData

/// Repository for managing MemoryItem entities
final class MemoryRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Create

    /// Creates a new memory item
    @discardableResult
    func create(content: String, isPrivate: Bool = false) throws -> MemoryItem {
        let memory = MemoryItem(content: content, isPrivate: isPrivate)
        context.insert(memory)
        try context.save()
        return memory
    }

    // MARK: - Update

    /// Updates the embedding for a memory
    func updateEmbedding(for memory: MemoryItem, embedding: [Float]) throws {
        memory.embedding = embedding
        try context.save()
    }

    /// Updates the privacy flag for a memory
    func updatePrivacy(for memory: MemoryItem, isPrivate: Bool) throws {
        memory.isPrivate = isPrivate
        try context.save()
    }

    /// Increments the reference count and updates last referenced date
    func incrementReferenceCount(for memory: MemoryItem) throws {
        memory.timesReferenced += 1
        memory.lastReferencedAt = Date()
        try context.save()
    }

    // MARK: - Fetch

    /// Fetches all memories
    func fetchAll() throws -> [MemoryItem] {
        let descriptor = FetchDescriptor<MemoryItem>(
            sortBy: [SortDescriptor(\.dateNoted, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetches only non-private memories (for AI context/egress)
    func fetchNonPrivate() throws -> [MemoryItem] {
        let descriptor = FetchDescriptor<MemoryItem>(
            predicate: #Predicate { !$0.isPrivate },
            sortBy: [SortDescriptor(\.dateNoted, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Delete

    /// Deletes a memory from the store
    func delete(_ memory: MemoryItem) throws {
        context.delete(memory)
        try context.save()
    }
}
