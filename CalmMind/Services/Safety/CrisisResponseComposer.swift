import Foundation

/// Response generated for crisis situations
struct CrisisResponse: Sendable {
    /// The compassionate message to display
    let message: String

    /// Crisis resources to show
    let resources: [CrisisResource]

    /// The original input that triggered this response
    let triggerInput: String
}

/// Composes crisis responses locally without any LLM involvement
/// CRITICAL: This component must NEVER call external services
/// All responses are pre-written and locally generated
final class CrisisResponseComposer: Sendable {

    // MARK: - Response Templates

    /// Empathetic opening phrases
    private static let openings: [String] = [
        "I hear you, and I want you to know that you matter.",
        "Thank you for sharing this with me. Your feelings are valid.",
        "I'm so sorry you're going through this. You're not alone.",
        "What you're feeling sounds incredibly painful. I'm here.",
        "It takes courage to share these feelings. I'm listening.",
    ]

    /// Supportive middle content
    private static let supports: [String] = [
        "These feelings can be overwhelming, but there are people who care about you and want to help.",
        "You don't have to face this alone. Support is available right now.",
        "Many people have felt this way and found their way through with help. You can too.",
        "Your life has value, even when it doesn't feel that way right now.",
        "Please consider reaching out to someone who can provide immediate support.",
    ]

    /// Call to action for resources
    private static let callsToAction: [String] = [
        "Please reach out to one of these resources - they're available 24/7:",
        "Here are some resources that can provide immediate support:",
        "These trained professionals are ready to help right now:",
        "Please consider calling or texting one of these services:",
    ]

    // MARK: - Initialization

    init() {}

    // MARK: - Response Generation

    /// Compose a crisis response for the given input
    /// - Parameter input: The user's message that triggered crisis classification
    /// - Returns: A complete crisis response with message and resources
    func compose(for input: String) -> CrisisResponse {
        // Select response components based on input hash for consistency
        let hash = abs(input.hashValue)

        let opening = Self.openings[hash % Self.openings.count]
        let support = Self.supports[hash % Self.supports.count]
        let callToAction = Self.callsToAction[hash % Self.callsToAction.count]

        let message = """
        \(opening)

        \(support)

        \(callToAction)

        📞 988 Suicide & Crisis Lifeline - Call or text 988 (available 24/7)
        💬 Crisis Text Line - Text HOME to 741741
        """

        // Always include primary resources
        let resources = CrisisResources.primaryResources

        return CrisisResponse(
            message: message,
            resources: resources,
            triggerInput: input
        )
    }

    /// Compose a response specifically for self-harm mentions
    func composeForSelfHarm(input: String) -> CrisisResponse {
        let message = """
        I hear that you're hurting, both physically and emotionally. I care about you and your wellbeing.

        Self-harm can feel like the only way to cope with overwhelming pain, but there are people who understand and can help you find other ways to manage these feelings.

        Please consider reaching out to one of these resources:
        """

        return CrisisResponse(
            message: message,
            resources: CrisisResources.primaryResources,
            triggerInput: input
        )
    }

    /// Compose a brief acknowledgment for cautionary messages
    func composeForCautionary(input: String) -> String {
        return """
        I hear that you're going through a difficult time. Your feelings are valid, and it's okay to not be okay sometimes.

        If you ever feel like things are becoming too much, please know that support is available. You can always reach the 988 Suicide & Crisis Lifeline by calling or texting 988.
        """
    }
}
