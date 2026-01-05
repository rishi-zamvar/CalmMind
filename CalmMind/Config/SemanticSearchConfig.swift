import Foundation

/// Configuration for semantic search - all tunable values centralized
/// Follows the same pattern as AppConfig for consistency
struct SemanticSearchConfig {

    // MARK: - Defaults (easily adjustable)

    enum Defaults {
        // Search tuning
        static let semanticThreshold: Float = 0.7
        static let exactMatchBoost: Float = 0.3
        static let maxTopicsForSearch = 2000
        static let maxResultsDefault = 10

        // Embedding model
        static let embeddingModel = "text-embedding-3-small"
        static let embeddingDimensions = 1536
        static let embeddingEndpoint = "/v1/embeddings"

        // Context formatting
        static let maxFactsPerTopic = 5
        static let charsPerToken = 4  // Heuristic: 4 chars ≈ 1 token

        // Performance
        static let embeddingBatchSize = 20

        // Auto-enable context injection
        static let autoEnableThreshold = 5  // Min topics with embeddings
        static let maxContextTopics = 3      // Max topics in context
        static let maxContextFacts = 5       // Max facts per topic in context
    }

    // MARK: - Properties

    /// Minimum similarity score to include in results (0.0 - 1.0)
    let semanticThreshold: Float

    /// Boost applied to exact name matches in hybrid scoring
    let exactMatchBoost: Float

    /// Maximum topics to load for semantic search (performance ceiling)
    let maxTopicsForSearch: Int

    /// Default number of results to return
    let maxResultsDefault: Int

    /// OpenAI embedding model to use
    let embeddingModel: String

    /// Expected embedding vector dimensions
    let embeddingDimensions: Int

    /// OpenAI embeddings API endpoint
    let embeddingEndpoint: String

    /// Maximum facts to include per topic in context
    let maxFactsPerTopic: Int

    /// Characters per token estimate for budget calculations
    let charsPerToken: Int

    /// Batch size for embedding API calls
    let embeddingBatchSize: Int

    /// Minimum topics with embeddings to auto-enable context injection
    let autoEnableThreshold: Int

    /// Maximum topics to include in context
    let maxContextTopics: Int

    /// Maximum facts per topic in context
    let maxContextFacts: Int

    // MARK: - Bundle Initialization

    /// Initialize from bundle Info.plist with fallback to defaults
    init(bundle: Bundle = .main) {
        let plist = bundle.infoDictionary ?? [:]

        self.semanticThreshold = (plist["SEMANTIC_THRESHOLD"] as? Double).map { Float($0) }
            ?? Defaults.semanticThreshold

        self.exactMatchBoost = (plist["EXACT_MATCH_BOOST"] as? Double).map { Float($0) }
            ?? Defaults.exactMatchBoost

        self.maxTopicsForSearch = plist["MAX_TOPICS_FOR_SEARCH"] as? Int
            ?? Defaults.maxTopicsForSearch

        self.maxResultsDefault = plist["MAX_RESULTS_DEFAULT"] as? Int
            ?? Defaults.maxResultsDefault

        self.embeddingModel = plist["EMBEDDING_MODEL"] as? String
            ?? Defaults.embeddingModel

        self.embeddingDimensions = plist["EMBEDDING_DIMENSIONS"] as? Int
            ?? Defaults.embeddingDimensions

        self.embeddingEndpoint = plist["EMBEDDING_ENDPOINT"] as? String
            ?? Defaults.embeddingEndpoint

        self.maxFactsPerTopic = plist["MAX_FACTS_PER_TOPIC"] as? Int
            ?? Defaults.maxFactsPerTopic

        self.charsPerToken = plist["CHARS_PER_TOKEN"] as? Int
            ?? Defaults.charsPerToken

        self.embeddingBatchSize = plist["EMBEDDING_BATCH_SIZE"] as? Int
            ?? Defaults.embeddingBatchSize

        self.autoEnableThreshold = plist["AUTO_ENABLE_THRESHOLD"] as? Int
            ?? Defaults.autoEnableThreshold

        self.maxContextTopics = plist["MAX_CONTEXT_TOPICS"] as? Int
            ?? Defaults.maxContextTopics

        self.maxContextFacts = plist["MAX_CONTEXT_FACTS"] as? Int
            ?? Defaults.maxContextFacts
    }

    // MARK: - Direct Initialization (for testing)

    /// Initialize with specific values - useful for testing
    init(
        semanticThreshold: Float = Defaults.semanticThreshold,
        exactMatchBoost: Float = Defaults.exactMatchBoost,
        maxTopicsForSearch: Int = Defaults.maxTopicsForSearch,
        maxResultsDefault: Int = Defaults.maxResultsDefault,
        embeddingModel: String = Defaults.embeddingModel,
        embeddingDimensions: Int = Defaults.embeddingDimensions,
        embeddingEndpoint: String = Defaults.embeddingEndpoint,
        maxFactsPerTopic: Int = Defaults.maxFactsPerTopic,
        charsPerToken: Int = Defaults.charsPerToken,
        embeddingBatchSize: Int = Defaults.embeddingBatchSize,
        autoEnableThreshold: Int = Defaults.autoEnableThreshold,
        maxContextTopics: Int = Defaults.maxContextTopics,
        maxContextFacts: Int = Defaults.maxContextFacts
    ) {
        self.semanticThreshold = semanticThreshold
        self.exactMatchBoost = exactMatchBoost
        self.maxTopicsForSearch = maxTopicsForSearch
        self.maxResultsDefault = maxResultsDefault
        self.embeddingModel = embeddingModel
        self.embeddingDimensions = embeddingDimensions
        self.embeddingEndpoint = embeddingEndpoint
        self.maxFactsPerTopic = maxFactsPerTopic
        self.charsPerToken = charsPerToken
        self.embeddingBatchSize = embeddingBatchSize
        self.autoEnableThreshold = autoEnableThreshold
        self.maxContextTopics = maxContextTopics
        self.maxContextFacts = maxContextFacts
    }
}

// MARK: - Shared Instance

extension SemanticSearchConfig {
    /// Shared instance using main bundle
    static let shared = SemanticSearchConfig()
}
