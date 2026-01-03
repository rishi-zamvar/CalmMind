import Foundation
import SwiftData

/// Repository for managing ChatMessage entities
final class MessageRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Save

    /// Saves a message to the specified session atomically
    func save(_ message: ChatMessage, to session: DailySession) throws {
        message.session = session
        session.messages.append(message)
        context.insert(message)
        try context.save()
    }

    // MARK: - Fetch

    /// Fetches all messages for a session ordered by timestamp
    func fetchMessages(for session: DailySession) throws -> [ChatMessage] {
        let sessionId = session.id
        var descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.session?.id == sessionId },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        descriptor.fetchLimit = nil
        return try context.fetch(descriptor)
    }

    /// Fetches the most recent messages for a session
    func fetchRecentMessages(for session: DailySession, limit: Int) throws -> [ChatMessage] {
        let sessionId = session.id
        var descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.session?.id == sessionId },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        descriptor.fetchLimit = nil
        let allMessages = try context.fetch(descriptor)

        // Return last N messages
        if allMessages.count <= limit {
            return allMessages
        }
        return Array(allMessages.suffix(limit))
    }

    // MARK: - Delete

    /// Deletes a message from the store
    func delete(_ message: ChatMessage) throws {
        context.delete(message)
        try context.save()
    }

    // MARK: - Count

    /// Counts messages in a session
    func countMessages(for session: DailySession) throws -> Int {
        let sessionId = session.id
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.session?.id == sessionId }
        )
        return try context.fetchCount(descriptor)
    }
}
