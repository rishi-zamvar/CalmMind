import Foundation
import os

/// Generates AI insights with config-driven routing and allowlist enforcement
/// Errors propagate (never silently swallowed) and provenance is tracked
///
/// `@unchecked Sendable` is declared here (in the same file as the type) so the
/// `InsightsGeneratorProtocol: Sendable` conformance is not applied retroactively from
/// another file; all stored dependencies are immutable and thread-safe to read.
final class InsightsGenerator: @unchecked Sendable {

    private let openAIService: OpenAIServiceProtocol
    private let config: InsightsConfig
    private let parser: InsightsParser
    private let allowlist: WellnessAllowlist
    private let logger = Logger(subsystem: "com.calmmind", category: "InsightsGenerator")

    /// System prompt for insights generation
    /// Instructs the model to output in PATTERNS: / SUGGESTIONS: format
    private static let systemPrompt = """
    Analyze this journal entry and provide:

    PATTERNS: 1-2 brief observations about behavior, mood, or recurring themes

    SUGGESTIONS: 1-2 specific wellness techniques from this list only:
    - 4-7-8 breathing (inhale 4s, hold 7s, exhale 8s)
    - 5-minute walk or stretch break
    - Brief gratitude reflection
    - Progressive muscle relaxation
    - Short mindfulness meditation

    Format response exactly as:
    PATTERNS:
    - [observation]
    SUGGESTIONS:
    - [technique]

    Keep each item under 15 words. Be specific and actionable.
    """

    // MARK: - Initialization

    init(
        openAIService: OpenAIServiceProtocol,
        config: InsightsConfig = .shared,
        parser: InsightsParser? = nil,
        allowlist: WellnessAllowlist? = nil
    ) {
        self.openAIService = openAIService
        self.config = config
        self.parser = parser ?? InsightsParser(config: config)
        self.allowlist = allowlist ?? WellnessAllowlist()
    }

    // MARK: - Public API

    /// Generate insights with config-driven routing
    /// - Parameter entryText: Journal entry text to analyze
    /// - Throws: OpenAIError on failure (never silently swallows)
    /// - Returns: JournalInsights with provenance metadata
    func generate(for entryText: String) async throws -> JournalInsights {
        // Enforce input budget
        let truncatedInput = config.truncateToTokenBudget(entryText)
        let inputHash = JournalInsights.computeInputHash(truncatedInput)

        // Log event (redacted - no entry text)
        logger.info("Generating insights, inputLength=\(truncatedInput.count), hash=\(inputHash.prefix(8))")

        // Call OpenAI with config-driven parameters
        let response = try await openAIService.sendChatCompletion(
            messages: [
                OpenAIMessage(role: .system, content: Self.systemPrompt),
                OpenAIMessage(role: .user, content: truncatedInput)
            ],
            tools: nil,
            model: config.model,
            maxTokens: config.maxOutputTokens,
            temperature: 0.7
        )

        // Parse response with strict contract
        let content = response.content ?? ""
        let parsed = parser.parse(content)

        // Enforce allowlist on suggestions (code-level, not just prompt)
        let filteredSuggestions = allowlist.filter(parsed.suggestions)

        logger.info("Insights parsed: patterns=\(parsed.patterns.count), suggestions=\(filteredSuggestions.count)")

        return JournalInsights(
            patterns: parsed.patterns,
            suggestions: filteredSuggestions,
            inputHash: inputHash,
            providerModel: config.model,
            generatedAt: Date()
        )
    }
}
