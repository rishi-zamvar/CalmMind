import Foundation

/// Classification levels for message safety
enum SafetyLevel: String, Codable, Sendable, Comparable {
    /// Message is safe - normal conversation
    case safe

    /// User seems distressed, be extra warm (LLM continues)
    case supportive

    /// Message shows concerning patterns - proceed with extra care
    case cautionary

    /// Message indicates crisis - bypass LLM, show resources immediately
    case crisis

    // MARK: - Comparable

    private var order: Int {
        switch self {
        case .safe: return 0
        case .supportive: return 1
        case .cautionary: return 2
        case .crisis: return 3
        }
    }

    static func < (lhs: SafetyLevel, rhs: SafetyLevel) -> Bool {
        lhs.order < rhs.order
    }
}

/// Context in which a concerning pattern was detected
enum SafetyContext: String, Codable, Sendable {
    /// User is speaking about themselves
    case direct

    /// "My friend said..."
    case quoted

    /// "If someone were to..."
    case hypothetical

    /// "I don't want to..."
    case negated

    /// "This exam makes me want to die"
    case idiomatic
}

/// Result of safety classification
struct SafetyClassificationResult: Sendable {
    /// The determined safety level
    let level: SafetyLevel

    /// Patterns that matched (for logging/debugging)
    let matchedPatterns: [String]

    /// Original input (for reference)
    let input: String

    /// Context in which patterns were found
    let context: SafetyContext

    /// Computed score for debugging
    let score: Int
}

/// Local, deterministic safety classifier for mental health messages
/// CRITICAL: This classifier runs locally and NEVER calls external services
///
/// DESIGN PHILOSOPHY: Very high threshold for crisis detection.
/// Only EXPLICIT self-harm statements trigger crisis bypass.
/// Normal emotional discussions (anxiety, sadness, breakups, stress) should NEVER trigger.
///
/// The AI is designed to be a helpful companion for ALL emotional topics.
/// Crisis mode is reserved for imminent self-harm risk only.
final class SafetyClassifier: Sendable {

    // MARK: - Crisis Patterns (VERY EXPLICIT ONLY)

    /// These patterns MUST be explicit statements of self-harm intent.
    /// Normal emotional distress should NEVER match these.
    private static let crisisPatterns: [String] = [
        // Direct self-harm statements
        "kill myself",
        "kill my self",
        "going to kill myself",
        "want to kill myself",
        "i'm going to end my life",
        "i want to end my life",
        "end my life",
        "take my own life",
        "going to take my own life",

        // Suicide-specific
        "commit suicide",
        "planning suicide",
        "going to commit suicide",

        // Active self-harm
        "cutting myself",
        "hurting myself on purpose",
        "self-harming",

        // Passive suicidal ideation
        "don't want to be alive",
        "wish i wasn't here",
        "nobody would miss me",
        "wouldn't miss me",

        // Self-harm plan
        "plan to hurt myself",
        "planning to hurt myself",

        // Overdose/method
        "take all my pills",
        "going to overdose",
    ]

    /// Cautionary patterns - serious situations that need care but not crisis bypass.
    /// These let the AI engage with safety planning rather than showing crisis resources.
    private static let cautionaryPatterns: [String] = [
        // Violence toward others (vague anger)
        "want to hurt someone",
        "going to hurt someone",

        // Domestic abuse (needs safety planning)
        "partner hits me",
        "partner beats me",
        "being abused",
        "abusing me",

        // Stalking/danger (needs practical help)
        "being stalked",
        "someone is following me",
    ]

    /// Exclusion patterns - DO NOT trigger crisis even if crisis pattern matches
    private static let exclusionPatterns: [String] = [
        // Past tense - discussing history (must be specific to avoid false positives)
        "used to",
        "in the past",
        "years ago",
        "when i was younger",
        "back when i",
        "i'm better now",
        "no longer",
        "not anymore",

        // Hypothetical/educational
        "if someone",
        "what would you",
        "how to help",
        "suicide prevention",
        "mental health awareness",
        "someone who",

        // Media/fictional
        "movie",
        "show",
        "song",
        "book",
        "article",
        "lyrics",
        "character",
        "game",
        "story",

        // Negation
        "don't want to kill",
        "not going to kill",
        "would never kill",
        "won't kill",
        "don't want to hurt",
        "not going to hurt",
    ]

    // MARK: - Initialization

    init() {}

    // MARK: - Classification

    /// Classify a message for safety level
    /// - Parameter message: The user's message to classify
    /// - Returns: Classification result with level and matched patterns
    func classify(_ message: String) -> SafetyClassificationResult {
        let lowercased = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Empty messages are safe
        guard !lowercased.isEmpty else {
            return SafetyClassificationResult(
                level: .safe,
                matchedPatterns: [],
                input: message,
                context: .direct,
                score: 0
            )
        }

        // Check for exclusion patterns FIRST
        let hasExclusion = Self.exclusionPatterns.contains { lowercased.contains($0) }

        // If exclusion pattern is present, message is safe (discussing past, hypothetical, etc.)
        if hasExclusion {
            return SafetyClassificationResult(
                level: .safe,
                matchedPatterns: [],
                input: message,
                context: .hypothetical,
                score: 0
            )
        }

        // Check for explicit crisis patterns
        var matchedPatterns: [String] = []
        for pattern in Self.crisisPatterns {
            if lowercased.contains(pattern) {
                matchedPatterns.append(pattern)
            }
        }

        // Only trigger crisis if we have an explicit match AND no exclusions
        if !matchedPatterns.isEmpty {
            return SafetyClassificationResult(
                level: .crisis,
                matchedPatterns: matchedPatterns,
                input: message,
                context: .direct,
                score: 100
            )
        }

        // Check for cautionary patterns (serious but not crisis bypass)
        var cautionaryMatches: [String] = []
        for pattern in Self.cautionaryPatterns {
            if lowercased.contains(pattern) {
                cautionaryMatches.append(pattern)
            }
        }

        if !cautionaryMatches.isEmpty {
            return SafetyClassificationResult(
                level: .cautionary,
                matchedPatterns: cautionaryMatches,
                input: message,
                context: .direct,
                score: 50
            )
        }

        // Everything else is SAFE - let the AI engage fully
        // Anxiety, depression, breakups, stress, sadness - ALL SAFE for AI to discuss
        return SafetyClassificationResult(
            level: .safe,
            matchedPatterns: [],
            input: message,
            context: .direct,
            score: 0
        )
    }
}
