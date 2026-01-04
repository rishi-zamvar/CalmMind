import Foundation

/// Protocol for generating personalized prompts
/// Enables testing by injecting mock implementations
protocol PromptServiceProtocol {
    /// Generates a personalized prompt based on user context
    /// - Parameter context: Contextual information for personalization
    /// - Returns: A personalized prompt string
    /// - Throws: If prompt generation fails (e.g., network error)
    func generatePrompt(context: String) async throws -> String
}

/// Error types for prompt service
enum PromptServiceError: Error, Equatable {
    case networkError
    case timeout
    case apiError(String)
    case offline
}
