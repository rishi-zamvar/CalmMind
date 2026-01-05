import Foundation

/// Builds natural language context from semantic search results
/// Formats topics and facts for AI system prompt injection
struct SemanticContextBuilder {

    /// Build context string from search results
    /// Returns nil if results are empty
    /// All limits from config, NO hardcoded values
    static func buildContext(
        from results: [TopicSearchResult],
        config: SemanticSearchConfig = .shared
    ) -> String? {
        guard !results.isEmpty else { return nil }

        var lines: [String] = ["Relevant context from your memory:"]

        // Use config values, NOT hardcoded numbers
        for result in results.prefix(config.maxContextTopics) {
            lines.append("")  // Blank line before topic
            lines.append("## \(result.topic.name)")

            for fact in result.matchedFacts.prefix(config.maxContextFacts) {
                lines.append("• \(fact.content)")
            }
        }

        // DETERMINISTIC: each line ends with \n, no trailing newline at end
        return lines.joined(separator: "\n")
    }
}
