import Foundation

/// Gate for auto-enabling semantic search context
/// Returns false (disabled) when:
/// - Privacy mode is enabled
/// - Topic count with embeddings is below threshold
/// - Repository throws an error (graceful failure)
final class SemanticSearchGate {

    // MARK: - Dependencies

    private let topicRepository: TopicRepository
    private let config: SemanticSearchConfig
    private let userPreferences: UserPreferences

    // MARK: - Computed Properties

    private var threshold: Int { config.autoEnableThreshold }

    // MARK: - Initialization

    init(
        topicRepository: TopicRepository,
        config: SemanticSearchConfig = .shared,
        userPreferences: UserPreferences = .shared
    ) {
        self.topicRepository = topicRepository
        self.config = config
        self.userPreferences = userPreferences
    }

    // MARK: - Public API

    /// Check if semantic context should be enabled
    /// Non-throwing: returns false on privacy mode OR repo error
    func shouldEnableContext() -> Bool {
        // Privacy mode → always disabled
        guard !userPreferences.privacyModeEnabled else { return false }

        // Graceful failure: repo error → disabled (non-critical feature)
        guard let count = try? topicRepository.fetchTopicsWithEmbeddings().count else {
            return false
        }

        return count >= threshold
    }

    /// Get current semantic search status for UI display
    func getStatus() -> SemanticSearchStatus {
        let count = (try? topicRepository.fetchTopicsWithEmbeddings().count) ?? 0
        let isEnabled = !userPreferences.privacyModeEnabled && count >= threshold

        return SemanticSearchStatus(
            isEnabled: isEnabled,
            topicCount: count,
            threshold: threshold,
            progress: min(1.0, Float(count) / Float(threshold))  // Clamped to 1.0
        )
    }
}

// MARK: - Status Model

/// Status of semantic search auto-enable
struct SemanticSearchStatus: Sendable, Equatable {
    /// Whether semantic context is currently enabled
    let isEnabled: Bool

    /// Number of topics with embeddings
    let topicCount: Int

    /// Threshold required for auto-enable
    let threshold: Int

    /// Progress toward threshold (0.0 - 1.0, clamped)
    let progress: Float

    /// Human-readable progress description
    var progressDescription: String {
        isEnabled ? "Active (\(topicCount) topics)" : "\(topicCount)/\(threshold) topics"
    }
}
