import Foundation

/// Result of journal entry generation
struct GeneratedJournalEntry: Sendable {
    /// The journal entry text (first person)
    let text: String

    /// Extracted mood score (1-10, or nil if not determinable)
    let moodScore: Int?

    /// Date the entry is for
    let date: Date
}

/// Generates journal entries and summaries from conversations
final class JournalGenerator: Sendable {

    // MARK: - Configuration

    private static let maxEntryLength = 5000
    private static let model = "gpt-4o-mini"
    private static let maxTokens = 500

    // MARK: - Prompts

    private static let journalGenerationPrompt = """
    You are helping create a personal journal entry. Based on the conversation below, write a first-person journal entry that:

    1. Summarizes the key topics and feelings discussed
    2. Is written from the user's perspective (use "I")
    3. Captures the emotional tone of the conversation
    4. Is 2-4 paragraphs long
    5. Feels personal and reflective

    Write ONLY the journal entry text, nothing else. Do not include a date or title.
    """

    private static let summaryGenerationPrompt = """
    Create a brief summary of this journal entry. The summary should:

    1. Be 1-2 sentences only
    2. Capture the main topic and emotional tone
    3. Be written in third person (e.g., "User discussed...")
    4. Preserve key facts mentioned

    Write ONLY the summary, nothing else.
    """

    private static let moodExtractionPrompt = """
    Based on this journal entry, rate the overall mood on a scale of 1-10:
    1 = Very negative/distressed
    5 = Neutral
    10 = Very positive/happy

    Respond with ONLY a single number from 1 to 10.
    """

    // MARK: - Dependencies

    private let openAIService: OpenAIServiceProtocol

    // MARK: - Initialization

    init(openAIService: OpenAIServiceProtocol) {
        self.openAIService = openAIService
    }

    // MARK: - Generation

    /// Generate a journal entry from conversation messages
    func generateEntry(from messages: [RedactableMessage]) async throws -> GeneratedJournalEntry {
        // Handle empty conversation
        if messages.isEmpty {
            return GeneratedJournalEntry(text: "", moodScore: nil, date: Date())
        }

        // Build conversation context
        let conversationText = messages.map { msg in
            let role = msg.role == .user ? "User" : "Assistant"
            return "\(role): \(msg.content)"
        }.joined(separator: "\n")

        // Generate journal entry
        let journalMessages = [
            OpenAIMessage(role: .system, content: Self.journalGenerationPrompt),
            OpenAIMessage(role: .user, content: "Conversation:\n\(conversationText)")
        ]

        let response = try await openAIService.sendChatCompletion(
            messages: journalMessages,
            tools: nil,
            model: Self.model,
            maxTokens: Self.maxTokens
        )

        var entryText = response.content ?? ""

        // Truncate if too long
        if entryText.count > Self.maxEntryLength {
            let endIndex = entryText.index(entryText.startIndex, offsetBy: Self.maxEntryLength - 3)
            entryText = String(entryText[..<endIndex]) + "..."
        }

        // Extract mood score
        let moodScore = try? await extractMoodScore(from: entryText)

        return GeneratedJournalEntry(
            text: entryText,
            moodScore: moodScore,
            date: Date()
        )
    }

    /// Generate a summary for an existing journal entry
    func generateSummary(for fullText: String) async throws -> String {
        let messages = [
            OpenAIMessage(role: .system, content: Self.summaryGenerationPrompt),
            OpenAIMessage(role: .user, content: fullText)
        ]

        let response = try await openAIService.sendChatCompletion(
            messages: messages,
            tools: nil,
            model: Self.model,
            maxTokens: 100
        )

        return response.content ?? ""
    }

    // MARK: - Private

    private func extractMoodScore(from text: String) async throws -> Int? {
        let messages = [
            OpenAIMessage(role: .system, content: Self.moodExtractionPrompt),
            OpenAIMessage(role: .user, content: text)
        ]

        let response = try await openAIService.sendChatCompletion(
            messages: messages,
            tools: nil,
            model: Self.model,
            maxTokens: 5
        )

        guard let content = response.content else { return nil }

        // Parse the number
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let score = Int(trimmed), score >= 1, score <= 10 {
            return score
        }

        // Try to find a number in the response
        let numbers = trimmed.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 >= 1 && $0 <= 10 }

        return numbers.first
    }
}
