import Foundation

// MARK: - Configuration

/// Configuration for context management
struct ContextConfig: Sendable {
    /// Maximum tokens for entire context (system + conversation + context)
    let maxTotalTokens: Int

    /// Maximum conversation messages to include
    let maxConversationMessages: Int

    /// Token budget for system prompt
    let systemPromptTokenBudget: Int

    /// Token budget for additional context (journals, memories, todos)
    let additionalContextTokenBudget: Int

    init(
        maxTotalTokens: Int = 4000,
        maxConversationMessages: Int = 20,
        systemPromptTokenBudget: Int = 500,
        additionalContextTokenBudget: Int = 500
    ) {
        self.maxTotalTokens = maxTotalTokens
        self.maxConversationMessages = maxConversationMessages
        self.systemPromptTokenBudget = systemPromptTokenBudget
        self.additionalContextTokenBudget = additionalContextTokenBudget
    }
}

// MARK: - Built Context

/// The assembled context ready for OpenAI API
struct BuiltContext: Sendable {
    /// System prompt with persona and guidelines
    let systemPrompt: String

    /// Additional context (journals, memories, todos)
    let additionalContext: String

    /// Conversation messages (already redacted)
    let conversationMessages: [RedactableMessage]

    /// Convert to OpenAI message format
    func toOpenAIMessages() -> [OpenAIMessage] {
        var messages: [OpenAIMessage] = []

        // System message includes prompt and context
        var systemContent = systemPrompt
        if !additionalContext.isEmpty {
            systemContent += "\n\n--- Context ---\n" + additionalContext
        }
        messages.append(OpenAIMessage(role: .system, content: systemContent))

        // Add conversation messages
        for msg in conversationMessages {
            messages.append(OpenAIMessage(role: msg.role, content: msg.content))
        }

        return messages
    }
}

// MARK: - ContextManager

/// Manages context assembly and token budgeting for OpenAI calls
final class ContextManager: Sendable {

    // MARK: - Dependencies

    private let redactor: ContextRedactor
    private let config: ContextConfig

    // MARK: - System Prompt

    private static let systemPromptTemplate = """
    You are a compassionate, supportive mental health companion. Your role is to:

    - Listen actively and validate the user's feelings
    - Provide emotional support without judgment
    - Help users reflect on their thoughts and experiences
    - Suggest healthy coping strategies when appropriate
    - Encourage professional help when needed

    Guidelines:
    - Never dismiss or minimize feelings
    - Never provide medical diagnoses or prescribe treatments
    - Never give legal, financial, or professional advice
    - Always maintain a warm, supportive tone
    - If you detect signs of crisis, express care and suggest professional resources

    Today's date is {DATE}.

    You can help the user with:
    - Talking through their day and feelings
    - Tracking todos (you can add items for them)
    - Reflecting on journal entries
    - Remembering important things they've shared
    """

    // MARK: - Initialization

    init(redactor: ContextRedactor = ContextRedactor(), config: ContextConfig = ContextConfig()) {
        self.redactor = redactor
        self.config = config
    }

    // MARK: - Context Building

    /// Build complete context for an OpenAI request
    func buildContext(
        messages: [RedactableMessage],
        journals: [RedactableJournal],
        memories: [RedactableMemory],
        todos: [RedactableTodo]
    ) -> BuiltContext {
        // Redact all inputs
        let redacted = redactor.redact(
            messages: messages,
            journals: journals,
            memories: memories,
            todos: todos
        )

        // Build system prompt with date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        let dateString = dateFormatter.string(from: Date())
        let systemPrompt = Self.systemPromptTemplate.replacingOccurrences(of: "{DATE}", with: dateString)

        // Build additional context string
        let additionalContext = redacted.toContextString()

        // Limit messages to stay within budget
        let limitedMessages = limitMessagesToTokenBudget(
            messages: redacted.messages,
            systemTokens: estimateTokens(text: systemPrompt),
            contextTokens: estimateTokens(text: additionalContext)
        )

        return BuiltContext(
            systemPrompt: systemPrompt,
            additionalContext: additionalContext,
            conversationMessages: limitedMessages
        )
    }

    // MARK: - Token Estimation

    /// Estimate token count for messages
    func estimateTokens(for messages: [RedactableMessage]) -> Int {
        var total = 0
        for message in messages {
            // Rough estimate: ~4 characters per token + overhead for role
            total += (message.content.count / 4) + 4
        }
        return total
    }

    /// Estimate token count for text
    func estimateTokens(text: String) -> Int {
        // Rough estimate: ~4 characters per token
        return max(1, text.count / 4)
    }

    // MARK: - Private Helpers

    private func limitMessagesToTokenBudget(
        messages: [RedactableMessage],
        systemTokens: Int,
        contextTokens: Int
    ) -> [RedactableMessage] {
        let usedTokens = systemTokens + contextTokens
        let availableTokens = config.maxTotalTokens - usedTokens

        // Also respect message count limit
        let maxCount = config.maxConversationMessages

        var result: [RedactableMessage] = []
        var currentTokens = 0

        // Take from end (most recent) and work backwards
        let reversed = messages.reversed()

        for message in reversed {
            let messageTokens = estimateTokens(text: message.content) + 4  // +4 for role overhead
            if currentTokens + messageTokens > availableTokens {
                break
            }
            if result.count >= maxCount {
                break
            }
            result.insert(message, at: 0)  // Insert at beginning to maintain order
            currentTokens += messageTokens
        }

        return result
    }
}
