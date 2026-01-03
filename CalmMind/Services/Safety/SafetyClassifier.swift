import Foundation

/// Classification levels for message safety
enum SafetyLevel: String, Codable, Sendable {
    /// Message is safe - normal conversation
    case safe

    /// Message shows concerning patterns - proceed with extra care
    case cautionary

    /// Message indicates crisis - bypass LLM, show resources immediately
    case crisis
}

/// Result of safety classification
struct SafetyClassificationResult: Sendable {
    /// The determined safety level
    let level: SafetyLevel

    /// Patterns that matched (for logging/debugging)
    let matchedPatterns: [String]

    /// Original input (for reference)
    let input: String
}

/// Local, deterministic safety classifier for mental health messages
/// CRITICAL: This classifier runs locally and NEVER calls external services
/// Crisis messages must bypass the LLM entirely
final class SafetyClassifier: Sendable {

    // MARK: - Crisis Patterns (Must Never Miss)

    /// Direct statements of suicidal intent
    private static let crisisPatterns: [String] = [
        // Suicidal ideation - direct
        "want to die",
        "want to end my life",
        "want to kill myself",
        "going to kill myself",
        "thinking about suicide",
        "planning to end it",
        "end it all",
        "take my own life",
        "no reason to live",
        "no point in living",
        "better off dead",
        "wish i was dead",
        "wish i were dead",

        // Self-harm - active
        "cutting myself",
        "hurting myself",
        "harming myself",
        "burning myself",

        // Overdose indicators
        "take all my pills",
        "taking all my pills",
        "overdose",

        // Hopelessness with finality
        "can't go on anymore",
        "can't take it anymore",
        "everyone would be better off without me",
        "no one would miss me",
        "giving away .* won't need",
        "saying goodbye",

        // Methods
        "jump off",
        "hang myself",
        "shoot myself",
    ]

    /// Exclusion patterns - contexts that indicate non-crisis despite keywords
    private static let exclusionPatterns: [String] = [
        // Past tense - discussing history
        "used to",
        "i was",
        "in the past",
        "years ago",
        "when i was",
        "i had been",
        "i'm better now",

        // Hypothetical/educational
        "if someone",
        "what would you tell",
        "how to help",
        "suicide prevention",
        "mental health awareness",

        // Media references
        "movie",
        "show",
        "song",
        "book",
        "article",
        "lyrics",
        "character",

        // Metaphorical usage
        "killing me .* work",
        "killing me .* deadline",
        "died .* game",
        "died laughing",
        "kill me softly",
        "killing it",
        "slaying",
    ]

    // MARK: - Cautionary Patterns

    /// Patterns indicating concern but not immediate crisis
    private static let cautionaryPatterns: [String] = [
        "feel hopeless",
        "feeling hopeless",
        "feel worthless",
        "feeling worthless",
        "feeling .* down",
        "really down",
        "feel down",
        "so overwhelmed",
        "don't know what to do",
        "can't cope",
        "falling apart",
        "breaking down",
        "depressed",
        "depression",
        "anxiety is",
        "panic attack",
        "can't sleep",
        "haven't slept",
        "not eating",
        "drinking too much",
        "using drugs",
        "feel alone",
        "no one understands",
        "no one cares",
        "feel empty",
        "numb inside",
        "lost all motivation",
        "don't see the point",
    ]

    // MARK: - Initialization

    init() {}

    // MARK: - Classification

    /// Classify a message for safety level
    /// - Parameter message: The user's message to classify
    /// - Returns: Classification result with level and matched patterns
    func classify(_ message: String) -> SafetyClassificationResult {
        let normalizedMessage = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty messages are safe
        guard !normalizedMessage.isEmpty else {
            return SafetyClassificationResult(level: .safe, matchedPatterns: [], input: message)
        }

        // Check for exclusion patterns first
        let hasExclusion = Self.exclusionPatterns.contains { pattern in
            matchesPattern(normalizedMessage, pattern: pattern)
        }

        // Check for crisis patterns
        var matchedCrisisPatterns: [String] = []
        for pattern in Self.crisisPatterns {
            if matchesPattern(normalizedMessage, pattern: pattern) {
                matchedCrisisPatterns.append(pattern)
            }
        }

        // If crisis patterns found and no exclusions, it's a crisis
        if !matchedCrisisPatterns.isEmpty && !hasExclusion {
            return SafetyClassificationResult(
                level: .crisis,
                matchedPatterns: matchedCrisisPatterns,
                input: message
            )
        }

        // Check for cautionary patterns
        var matchedCautionaryPatterns: [String] = []
        for pattern in Self.cautionaryPatterns {
            if matchesPattern(normalizedMessage, pattern: pattern) {
                matchedCautionaryPatterns.append(pattern)
            }
        }

        // If crisis patterns with exclusions, or cautionary patterns, it's cautionary
        if (!matchedCrisisPatterns.isEmpty && hasExclusion) || !matchedCautionaryPatterns.isEmpty {
            let allMatched = matchedCrisisPatterns + matchedCautionaryPatterns
            return SafetyClassificationResult(
                level: .cautionary,
                matchedPatterns: allMatched,
                input: message
            )
        }

        // Otherwise safe
        return SafetyClassificationResult(level: .safe, matchedPatterns: [], input: message)
    }

    // MARK: - Private Helpers

    /// Check if message matches a pattern (supports .* for wildcards)
    private func matchesPattern(_ message: String, pattern: String) -> Bool {
        // Convert simple wildcard pattern to regex
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "\\.*", with: ".*")  // Restore .* wildcards

        guard let regex = try? NSRegularExpression(
            pattern: regexPattern,
            options: [.caseInsensitive]
        ) else {
            // Fallback to simple contains if regex fails
            return message.contains(pattern)
        }

        let range = NSRange(message.startIndex..., in: message)
        return regex.firstMatch(in: message, options: [], range: range) != nil
    }
}
