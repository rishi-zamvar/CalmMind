import XCTest
@testable import CalmMind

/// Tests for SemanticSearchConfig - all tunable values centralized
final class SemanticSearchConfigTests: XCTestCase {

    // MARK: - Default Values

    func test_defaults_semanticThreshold() {
        let config = SemanticSearchConfig()
        XCTAssertEqual(config.semanticThreshold, 0.7, accuracy: 0.001)
    }

    func test_defaults_exactMatchBoost() {
        let config = SemanticSearchConfig()
        XCTAssertEqual(config.exactMatchBoost, 0.3, accuracy: 0.001)
    }

    func test_defaults_maxTopicsForSearch() {
        let config = SemanticSearchConfig()
        XCTAssertEqual(config.maxTopicsForSearch, 2000)
    }

    func test_defaults_maxResultsDefault() {
        let config = SemanticSearchConfig()
        XCTAssertEqual(config.maxResultsDefault, 10)
    }

    func test_defaults_embeddingModel() {
        let config = SemanticSearchConfig()
        XCTAssertEqual(config.embeddingModel, "text-embedding-3-small")
    }

    func test_defaults_embeddingDimensions() {
        let config = SemanticSearchConfig()
        XCTAssertEqual(config.embeddingDimensions, 1536)
    }

    func test_defaults_embeddingEndpoint() {
        let config = SemanticSearchConfig()
        XCTAssertEqual(config.embeddingEndpoint, "/v1/embeddings")
    }

    func test_defaults_maxFactsPerTopic() {
        let config = SemanticSearchConfig()
        XCTAssertEqual(config.maxFactsPerTopic, 5)
    }

    func test_defaults_charsPerToken() {
        let config = SemanticSearchConfig()
        XCTAssertEqual(config.charsPerToken, 4)
    }

    func test_defaults_embeddingBatchSize() {
        let config = SemanticSearchConfig()
        XCTAssertEqual(config.embeddingBatchSize, 20)
    }

    // MARK: - Shared Instance

    func test_shared_returnsSameInstance() {
        let instance1 = SemanticSearchConfig.shared
        let instance2 = SemanticSearchConfig.shared
        // Static let is same reference
        XCTAssertEqual(instance1.semanticThreshold, instance2.semanticThreshold)
        XCTAssertEqual(instance1.embeddingDimensions, instance2.embeddingDimensions)
    }

    // MARK: - Direct Initialization (for testing)

    func test_directInit_overridesDefaults() {
        let config = SemanticSearchConfig(
            semanticThreshold: 0.8,
            exactMatchBoost: 0.5,
            maxTopicsForSearch: 1000,
            maxResultsDefault: 20,
            embeddingModel: "custom-model",
            embeddingDimensions: 768,
            embeddingEndpoint: "/custom/endpoint",
            maxFactsPerTopic: 10,
            charsPerToken: 3,
            embeddingBatchSize: 50
        )

        XCTAssertEqual(config.semanticThreshold, 0.8, accuracy: 0.001)
        XCTAssertEqual(config.exactMatchBoost, 0.5, accuracy: 0.001)
        XCTAssertEqual(config.maxTopicsForSearch, 1000)
        XCTAssertEqual(config.maxResultsDefault, 20)
        XCTAssertEqual(config.embeddingModel, "custom-model")
        XCTAssertEqual(config.embeddingDimensions, 768)
        XCTAssertEqual(config.embeddingEndpoint, "/custom/endpoint")
        XCTAssertEqual(config.maxFactsPerTopic, 10)
        XCTAssertEqual(config.charsPerToken, 3)
        XCTAssertEqual(config.embeddingBatchSize, 50)
    }

    func test_directInit_partialOverride() {
        let config = SemanticSearchConfig(
            semanticThreshold: 0.9
            // All others use defaults
        )

        XCTAssertEqual(config.semanticThreshold, 0.9, accuracy: 0.001)
        XCTAssertEqual(config.exactMatchBoost, SemanticSearchConfig.Defaults.exactMatchBoost, accuracy: 0.001)
        XCTAssertEqual(config.maxTopicsForSearch, SemanticSearchConfig.Defaults.maxTopicsForSearch)
    }

    // MARK: - Defaults Enum Access

    func test_defaultsEnum_accessible() {
        // Verify Defaults enum is accessible for reference
        XCTAssertEqual(SemanticSearchConfig.Defaults.semanticThreshold, 0.7, accuracy: 0.001)
        XCTAssertEqual(SemanticSearchConfig.Defaults.exactMatchBoost, 0.3, accuracy: 0.001)
        XCTAssertEqual(SemanticSearchConfig.Defaults.maxTopicsForSearch, 2000)
        XCTAssertEqual(SemanticSearchConfig.Defaults.maxResultsDefault, 10)
        XCTAssertEqual(SemanticSearchConfig.Defaults.embeddingModel, "text-embedding-3-small")
        XCTAssertEqual(SemanticSearchConfig.Defaults.embeddingDimensions, 1536)
        XCTAssertEqual(SemanticSearchConfig.Defaults.embeddingEndpoint, "/v1/embeddings")
        XCTAssertEqual(SemanticSearchConfig.Defaults.maxFactsPerTopic, 5)
        XCTAssertEqual(SemanticSearchConfig.Defaults.charsPerToken, 4)
        XCTAssertEqual(SemanticSearchConfig.Defaults.embeddingBatchSize, 20)
    }

    // MARK: - Bundle Initialization (for Info.plist override)

    func test_bundleInit_fallsBackToDefaults_whenNoInfoPlist() {
        // Create empty bundle mock
        let emptyBundle = Bundle(for: type(of: self))
        let config = SemanticSearchConfig(bundle: emptyBundle)

        // Should use defaults when plist values not present
        XCTAssertEqual(config.semanticThreshold, SemanticSearchConfig.Defaults.semanticThreshold, accuracy: 0.001)
        XCTAssertEqual(config.embeddingDimensions, SemanticSearchConfig.Defaults.embeddingDimensions)
    }
}
