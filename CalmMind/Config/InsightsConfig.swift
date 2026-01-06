import Foundation

/// Configuration for AI Insights generation - all tunable values centralized
/// NO hardcoded model names in business logic - all values from config
/// Follows the same pattern as SemanticSearchConfig for consistency
struct InsightsConfig {

    // MARK: - Defaults (easily adjustable)

    enum Defaults {
        /// Default model - overridable via Info.plist INSIGHTS_MODEL key
        static let model = "gpt-4o-mini"

        /// Maximum input tokens (heuristic: 4 chars/token)
        static let maxInputTokens = 2000

        /// Maximum output tokens for insights response
        static let maxOutputTokens = 300

        /// Timeout in seconds for API calls
        static let timeoutSeconds: TimeInterval = 30

        /// Maximum retry attempts (0-3)
        static let maxRetries = 2

        /// Maximum patterns to extract
        static let maxPatterns = 2

        /// Maximum suggestions to provide
        static let maxSuggestions = 2

        /// Maximum characters per pattern/suggestion
        static let maxItemLength = 100

        /// Characters per token estimate for budget calculations
        static let charsPerToken = 4
    }

    // MARK: - Properties

    /// AI model to use for insights generation
    let model: String

    /// Maximum input tokens (entry text is truncated to fit)
    let maxInputTokens: Int

    /// Maximum output tokens in API response
    let maxOutputTokens: Int

    /// API call timeout in seconds
    let timeoutSeconds: TimeInterval

    /// Maximum retry attempts for failed requests
    let maxRetries: Int

    /// Maximum patterns to extract from entry
    let maxPatterns: Int

    /// Maximum wellness suggestions to provide
    let maxSuggestions: Int

    /// Maximum characters per individual item
    let maxItemLength: Int

    /// Characters per token estimate (heuristic for truncation)
    let charsPerToken: Int

    // MARK: - Bundle Initialization

    /// Initialize from bundle Info.plist with fallback to defaults
    init(bundle: Bundle = .main) {
        let plist = bundle.infoDictionary ?? [:]

        self.model = plist["INSIGHTS_MODEL"] as? String
            ?? Defaults.model

        self.maxInputTokens = plist["INSIGHTS_MAX_INPUT_TOKENS"] as? Int
            ?? Defaults.maxInputTokens

        self.maxOutputTokens = plist["INSIGHTS_MAX_OUTPUT_TOKENS"] as? Int
            ?? Defaults.maxOutputTokens

        self.timeoutSeconds = plist["INSIGHTS_TIMEOUT_SECONDS"] as? TimeInterval
            ?? Defaults.timeoutSeconds

        self.maxRetries = plist["INSIGHTS_MAX_RETRIES"] as? Int
            ?? Defaults.maxRetries

        self.maxPatterns = plist["INSIGHTS_MAX_PATTERNS"] as? Int
            ?? Defaults.maxPatterns

        self.maxSuggestions = plist["INSIGHTS_MAX_SUGGESTIONS"] as? Int
            ?? Defaults.maxSuggestions

        self.maxItemLength = plist["INSIGHTS_MAX_ITEM_LENGTH"] as? Int
            ?? Defaults.maxItemLength

        self.charsPerToken = plist["INSIGHTS_CHARS_PER_TOKEN"] as? Int
            ?? Defaults.charsPerToken
    }

    // MARK: - Direct Initialization (for testing)

    /// Initialize with specific values - useful for testing
    init(
        model: String = Defaults.model,
        maxInputTokens: Int = Defaults.maxInputTokens,
        maxOutputTokens: Int = Defaults.maxOutputTokens,
        timeoutSeconds: TimeInterval = Defaults.timeoutSeconds,
        maxRetries: Int = Defaults.maxRetries,
        maxPatterns: Int = Defaults.maxPatterns,
        maxSuggestions: Int = Defaults.maxSuggestions,
        maxItemLength: Int = Defaults.maxItemLength,
        charsPerToken: Int = Defaults.charsPerToken
    ) {
        self.model = model
        self.maxInputTokens = maxInputTokens
        self.maxOutputTokens = maxOutputTokens
        self.timeoutSeconds = timeoutSeconds
        self.maxRetries = maxRetries
        self.maxPatterns = maxPatterns
        self.maxSuggestions = maxSuggestions
        self.maxItemLength = maxItemLength
        self.charsPerToken = charsPerToken
    }

    // MARK: - Token Budget Enforcement

    /// Truncate input to stay within token budget
    /// - Parameter input: The text to truncate
    /// - Returns: Truncated text that fits within maxInputTokens * charsPerToken chars
    func truncateToTokenBudget(_ input: String) -> String {
        let maxChars = maxInputTokens * charsPerToken
        guard input.count > maxChars else { return input }
        return String(input.prefix(maxChars))
    }
}

// MARK: - Shared Instance

extension InsightsConfig {
    /// Shared instance using main bundle
    static let shared = InsightsConfig()
}
