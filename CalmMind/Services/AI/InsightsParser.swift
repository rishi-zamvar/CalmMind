import Foundation

/// Deterministic parser for AI insights responses
/// Strict contract: extracts PATTERNS: and SUGGESTIONS: sections
/// Never crashes on malformed input - returns empty arrays
struct InsightsParser {

    /// Parsed insights result
    struct ParsedInsights: Equatable {
        let patterns: [String]
        let suggestions: [String]
    }

    private let config: InsightsConfig

    init(config: InsightsConfig = .shared) {
        self.config = config
    }

    /// Parse LLM response into structured insights
    /// - Parameter text: Raw LLM response text
    /// - Returns: ParsedInsights with capped, normalized arrays (never crashes)
    func parse(_ text: String) -> ParsedInsights {
        let patterns = extractSection(from: text, header: "PATTERNS:")
        let suggestions = extractSection(from: text, header: "SUGGESTIONS:")

        return ParsedInsights(
            patterns: Array(patterns.prefix(config.maxPatterns)),
            suggestions: Array(suggestions.prefix(config.maxSuggestions))
        )
    }

    // MARK: - Private Helpers

    private func extractSection(from text: String, header: String) -> [String] {
        // Case-insensitive header search
        guard let headerRange = text.range(of: header, options: .caseInsensitive) else {
            return []
        }

        let afterHeader = text[headerRange.upperBound...]

        // Find the next section header or end of string
        let nextHeaders = ["PATTERNS:", "SUGGESTIONS:"]
        var endIndex = afterHeader.endIndex

        for nextHeader in nextHeaders where nextHeader.uppercased() != header.uppercased() {
            if let range = afterHeader.range(of: nextHeader, options: .caseInsensitive) {
                if range.lowerBound < endIndex {
                    endIndex = range.lowerBound
                }
            }
        }

        let sectionContent = String(afterHeader[..<endIndex])
        return parseListItems(sectionContent)
    }

    private func parseListItems(_ content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)

        return lines.compactMap { line -> String? in
            var cleaned = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            guard !cleaned.isEmpty else { return nil }

            // Strip bullet markers: -, *, •
            if cleaned.hasPrefix("-") || cleaned.hasPrefix("*") || cleaned.hasPrefix("•") {
                cleaned = String(cleaned.dropFirst()).trimmingCharacters(in: .whitespaces)
            }

            // Strip numbered markers: 1. 1) 1:
            if let match = cleaned.range(of: #"^\d+[\.\)\:]"#, options: .regularExpression) {
                cleaned = String(cleaned[match.upperBound...]).trimmingCharacters(in: .whitespaces)
            }

            // Skip if empty after stripping markers
            guard !cleaned.isEmpty else { return nil }

            // Normalize internal whitespace (collapse multiple spaces to single)
            cleaned = cleaned.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            // Truncate to max length with ellipsis
            if cleaned.count > config.maxItemLength {
                let truncateAt = config.maxItemLength - 3
                cleaned = String(cleaned.prefix(truncateAt)) + "..."
            }

            return cleaned
        }
    }
}
