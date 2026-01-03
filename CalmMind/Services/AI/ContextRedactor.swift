import Foundation

// MARK: - Redactable Types

/// A message that can be redacted for context
struct RedactableMessage: Sendable {
    let role: OpenAIRole
    let content: String
    let timestamp: Date
}

/// A journal entry that can be redacted for context
struct RedactableJournal: Sendable {
    /// Full text - NEVER sent to API
    let fullText: String

    /// Summary - safe to send
    let summary: String?

    /// Entry date
    let date: Date
}

/// A memory item that can be redacted for context
struct RedactableMemory: Sendable {
    /// Full content - NEVER sent to API
    let content: String

    /// Summary - safe to send (if not private)
    let summary: String?

    /// If true, excluded from ALL egress
    let isPrivate: Bool
}

/// A todo item that can be redacted for context
struct RedactableTodo: Sendable {
    /// Title - safe to send
    let title: String

    /// Notes - NEVER sent to API
    let notes: String?

    /// Completion status
    let isCompleted: Bool
}

// MARK: - Redacted Output

/// The result of redaction - safe to send to OpenAI
struct RedactedContext: Sendable {
    /// Recent messages (content may be truncated)
    let messages: [RedactableMessage]

    /// Journal summaries only (never full text)
    let journalContext: [String]

    /// Memory summaries only (excludes private)
    let memoryContext: [String]

    /// Todo titles only (never notes)
    let todoContext: [String]

    /// Convert to a string for context injection
    func toContextString() -> String {
        var parts: [String] = []

        if !journalContext.isEmpty {
            parts.append("Recent journal summaries: \(journalContext.joined(separator: "; "))")
        }

        if !memoryContext.isEmpty {
            parts.append("Relevant memories: \(memoryContext.joined(separator: "; "))")
        }

        if !todoContext.isEmpty {
            let incompleteTodos = todoContext.joined(separator: ", ")
            parts.append("Current todos: \(incompleteTodos)")
        }

        return parts.joined(separator: "\n")
    }
}

// MARK: - ContextRedactor

/// Redacts sensitive data before sending to OpenAI
/// CRITICAL: This is the data egress contract enforcement layer
/// - Full journal text NEVER leaves the device
/// - Full memory content NEVER leaves the device
/// - Private-flagged items are completely excluded
/// - Only summaries and titles are sent
final class ContextRedactor: Sendable {

    // MARK: - Configuration

    /// Maximum number of messages to include
    private let maxMessages: Int

    /// Maximum length of a single message
    private let maxMessageLength: Int

    /// Maximum number of journal summaries
    private let maxJournalSummaries: Int

    /// Maximum number of memory summaries
    private let maxMemorySummaries: Int

    /// Maximum number of todos
    private let maxTodos: Int

    // MARK: - Initialization

    init(
        maxMessages: Int = 20,
        maxMessageLength: Int = 2000,
        maxJournalSummaries: Int = 3,
        maxMemorySummaries: Int = 5,
        maxTodos: Int = 10
    ) {
        self.maxMessages = maxMessages
        self.maxMessageLength = maxMessageLength
        self.maxJournalSummaries = maxJournalSummaries
        self.maxMemorySummaries = maxMemorySummaries
        self.maxTodos = maxTodos
    }

    // MARK: - Redaction

    /// Redact all inputs to create safe context for API
    /// - Parameters:
    ///   - messages: Recent conversation messages
    ///   - journals: Journal entries (will use summaries only)
    ///   - memories: Memory items (will exclude private, use summaries only)
    ///   - todos: Todo items (will use titles only)
    /// - Returns: Redacted context safe for API consumption
    func redact(
        messages: [RedactableMessage],
        journals: [RedactableJournal],
        memories: [RedactableMemory],
        todos: [RedactableTodo]
    ) -> RedactedContext {
        return RedactedContext(
            messages: redactMessages(messages),
            journalContext: redactJournals(journals),
            memoryContext: redactMemories(memories),
            todoContext: redactTodos(todos)
        )
    }

    // MARK: - Private Redaction Methods

    private func redactMessages(_ messages: [RedactableMessage]) -> [RedactableMessage] {
        // Sort by timestamp descending, take most recent
        let sorted = messages.sorted { $0.timestamp > $1.timestamp }
        let limited = Array(sorted.prefix(maxMessages))

        // Truncate long messages and reverse to chronological order
        return limited.reversed().map { message in
            let truncatedContent = truncate(message.content, maxLength: maxMessageLength)
            return RedactableMessage(
                role: message.role,
                content: truncatedContent,
                timestamp: message.timestamp
            )
        }
    }

    private func redactJournals(_ journals: [RedactableJournal]) -> [String] {
        // Sort by date descending, take most recent
        let sorted = journals.sorted { $0.date > $1.date }
        let limited = Array(sorted.prefix(maxJournalSummaries))

        // ONLY use summaries - NEVER full text
        return limited.compactMap { journal in
            guard let summary = journal.summary, !summary.isEmpty else {
                return nil  // Skip journals without summaries
            }
            return summary
        }
    }

    private func redactMemories(_ memories: [RedactableMemory]) -> [String] {
        // Filter out private memories first
        let nonPrivate = memories.filter { !$0.isPrivate }

        // Take limited number
        let limited = Array(nonPrivate.prefix(maxMemorySummaries))

        // ONLY use summaries - NEVER full content
        return limited.compactMap { memory in
            guard let summary = memory.summary, !summary.isEmpty else {
                return nil  // Skip memories without summaries
            }
            return summary
        }
    }

    private func redactTodos(_ todos: [RedactableTodo]) -> [String] {
        // Filter to incomplete todos
        let incomplete = todos.filter { !$0.isCompleted }

        // Take limited number
        let limited = Array(incomplete.prefix(maxTodos))

        // ONLY use titles - NEVER notes
        return limited.map { $0.title }
    }

    // MARK: - Helpers

    private func truncate(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        let endIndex = text.index(text.startIndex, offsetBy: maxLength - 3)
        return String(text[..<endIndex]) + "..."
    }
}
