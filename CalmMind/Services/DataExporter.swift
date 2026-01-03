import Foundation
import SwiftData

/// Exports user data in a portable JSON format
final class DataExporter {

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Initialization

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Export all user data as JSON
    /// - Returns: JSON data containing all user data
    func exportAllData() throws -> Data {
        let sessions = try exportSessions()
        let messages = try exportMessages()
        let journals = try exportJournals()
        let todos = try exportTodos()
        let memories = try exportMemories()

        let exportData: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "version": "1.0",
            "sessions": sessions.map { sessionToDict($0) },
            "messages": messages.map { messageToDict($0) },
            "journals": journals.map { journalToDict($0) },
            "todos": todos.map { todoToDict($0) },
            "memories": memories.map { memoryToDict($0) }
        ]

        return try JSONSerialization.data(
            withJSONObject: exportData,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    /// Export all messages
    func exportMessages() throws -> [ChatMessage] {
        let descriptor = FetchDescriptor<ChatMessage>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Export all sessions
    func exportSessions() throws -> [DailySession] {
        let descriptor = FetchDescriptor<DailySession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Export all journal entries
    func exportJournals() throws -> [JournalEntry] {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Export all todos
    func exportTodos() throws -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Export all memories
    func exportMemories() throws -> [MemoryItem] {
        let descriptor = FetchDescriptor<MemoryItem>(
            sortBy: [SortDescriptor(\.dateNoted, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Entity to Dictionary Conversion

    private func sessionToDict(_ session: DailySession) -> [String: Any] {
        var dict: [String: Any] = [
            "id": session.id.uuidString,
            "date": ISO8601DateFormatter().string(from: session.date),
            "isJournalGenerated": session.isJournalGenerated
        ]
        return dict
    }

    private func messageToDict(_ message: ChatMessage) -> [String: Any] {
        return [
            "id": message.id.uuidString,
            "content": message.content,
            "role": message.role.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: message.timestamp),
            "isContextInjection": message.isContextInjection
        ]
    }

    private func journalToDict(_ entry: JournalEntry) -> [String: Any] {
        var dict: [String: Any] = [
            "id": entry.id.uuidString,
            "fullText": entry.fullText,
            "createdAt": ISO8601DateFormatter().string(from: entry.createdAt),
            "entryDate": ISO8601DateFormatter().string(from: entry.entryDate),
            "dateKey": entry.dateKey
        ]

        if let summary = entry.summary {
            dict["summary"] = summary
        }
        if let moodScore = entry.moodScore {
            dict["moodScore"] = moodScore
        }

        return dict
    }

    private func todoToDict(_ todo: TodoItem) -> [String: Any] {
        var dict: [String: Any] = [
            "id": todo.id.uuidString,
            "title": todo.title,
            "isCompleted": todo.isCompleted,
            "source": todo.source.rawValue,
            "createdAt": ISO8601DateFormatter().string(from: todo.createdAt)
        ]

        if let completedAt = todo.completedAt {
            dict["completedAt"] = ISO8601DateFormatter().string(from: completedAt)
        }
        if let dueDate = todo.dueDate {
            dict["dueDate"] = ISO8601DateFormatter().string(from: dueDate)
        }

        return dict
    }

    private func memoryToDict(_ memory: MemoryItem) -> [String: Any] {
        var dict: [String: Any] = [
            "id": memory.id.uuidString,
            "content": memory.content,
            "dateNoted": ISO8601DateFormatter().string(from: memory.dateNoted),
            "timesReferenced": memory.timesReferenced,
            "isPrivate": memory.isPrivate
        ]

        if let lastReferenced = memory.lastReferencedAt {
            dict["lastReferencedAt"] = ISO8601DateFormatter().string(from: lastReferenced)
        }

        return dict
    }
}
