import Foundation

/// Result of todo title normalization
struct TodoNormalizationResult {
    let original: String
    let title: String
    let extractedDueDate: Date?
    let wasTruncated: Bool
}

/// Normalizes and cleans up todo titles
/// Removes filler words, extracts dates, and formats consistently
struct TodoTitleNormalizer {

    /// Maximum title length
    static let maxLength = 50

    /// Common filler phrases to remove from the start
    private let fillerPhrases = [
        "i need to ",
        "i should probably ",
        "i should ",
        "i have to ",
        "i must ",
        "i want to ",
        "i'd like to ",
        "remember to ",
        "don't forget to ",
        "make sure to ",
        "be sure to ",
        "need to ",
        "have to ",
        "must ",
        "should ",
        "gotta "
    ]

    /// Date keywords that trigger extraction
    private let dateKeywords = [
        "today": 0,
        "tomorrow": 1,
        "next week": 7
    ]

    /// Normalize a todo title
    func normalize(_ input: String) -> TodoNormalizationResult {
        var title = input

        // Trim whitespace
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Collapse multiple spaces
        while title.contains("  ") {
            title = title.replacingOccurrences(of: "  ", with: " ")
        }

        // Extract date before removing keywords
        let extractedDate = extractDate(from: title)
        if extractedDate != nil {
            title = removeDateKeywords(from: title)
        }

        // Remove filler phrases
        title = removeFillerPhrases(from: title)

        // Remove trailing punctuation
        title = removeTrailingPunctuation(from: title)

        // Trim again after modifications
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Capitalize first letter
        title = capitalizeFirst(title)

        // Truncate if needed
        let wasTruncated = title.count > Self.maxLength
        if wasTruncated {
            // Truncate and add ellipsis
            title = String(title.prefix(Self.maxLength - 3)) + "..."
        }

        return TodoNormalizationResult(
            original: input,
            title: title,
            extractedDueDate: extractedDate,
            wasTruncated: wasTruncated
        )
    }

    // MARK: - Private Helpers

    private func removeFillerPhrases(from text: String) -> String {
        let lowercased = text.lowercased()

        for phrase in fillerPhrases {
            if lowercased.hasPrefix(phrase) {
                // Remove the phrase but preserve original case of remaining text
                return String(text.dropFirst(phrase.count))
            }
        }

        return text
    }

    private func removeTrailingPunctuation(from text: String) -> String {
        var result = text
        let trailingPunctuation: Set<Character> = [".", "!", "?"]

        while let last = result.last, trailingPunctuation.contains(last) {
            result = String(result.dropLast())
        }

        return result
    }

    private func capitalizeFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    private func extractDate(from text: String) -> Date? {
        let lowercased = text.lowercased()

        for (keyword, daysFromNow) in dateKeywords {
            if lowercased.contains(keyword) {
                return Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date())
            }
        }

        return nil
    }

    private func removeDateKeywords(from text: String) -> String {
        var result = text

        for keyword in dateKeywords.keys {
            // Case insensitive replacement
            if let range = result.range(of: keyword, options: .caseInsensitive) {
                result.removeSubrange(range)
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
