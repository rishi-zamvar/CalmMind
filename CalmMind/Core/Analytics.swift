import Foundation

/// Approved event types with TYPED payloads
/// Never accepts arbitrary [String: Any] - this prevents accidental content logging
///
/// HARD RULES:
/// 1. Safety events log ONLY: {label: SafetyLevel, timestamp: Date} - NEVER user text
/// 2. No "conversation replay" logging in production
/// 3. No device identifiers in prompts
/// 4. API key never included in analytics or logs
/// 5. Journal content never logged (even in debug builds)
///
/// BANNED Content (Compile-Time Prevention via typed enum):
/// - userMessage - Never logged
/// - journalContent - Never logged
/// - apiKey - Never logged
/// - toolArguments - Never logged (only tool name)
/// - modelResponse - Never logged
/// - stackTrace - Never logged (could contain content)
enum AnalyticsEvent: Sendable {
    /// Crisis detected - No payload, just counts
    case crisisDetected

    /// Session started
    case sessionStarted(sessionId: UUID)

    /// Todo created - Count only, no content
    case todoCreated(count: Int)

    /// Journal updated - Length only, no content
    case journalUpdated(wordCount: Int)

    /// Tool rejected by safety policy - Tool name only, no arguments
    case toolRejectedBySafety(toolName: String)

    /// Onboarding completed
    case onboardingCompleted(stepCount: Int)

    /// Message sent (length only, no content)
    case messageSent(characterCount: Int)

    /// Safety classification performed (label only, no input text)
    case safetyClassified(level: SafetyLevel)

    // MARK: - Approved Payloads

    /// Approved fields only - enforced by typed enum
    var payload: [String: Any] {
        switch self {
        case .crisisDetected:
            // EMPTY - no content ever
            return [:]

        case .sessionStarted(let sessionId):
            return ["session_id": sessionId.uuidString]

        case .todoCreated(let count):
            return ["count": count]

        case .journalUpdated(let wordCount):
            return ["word_count": wordCount]

        case .toolRejectedBySafety(let toolName):
            // No arguments, just name
            return ["tool": toolName]

        case .onboardingCompleted(let stepCount):
            return ["steps": stepCount]

        case .messageSent(let characterCount):
            return ["char_count": characterCount]

        case .safetyClassified(let level):
            // Label only, no input text
            return ["level": level.rawValue]
        }
    }

    /// Event name for logging
    var name: String {
        switch self {
        case .crisisDetected: return "crisis_detected"
        case .sessionStarted: return "session_started"
        case .todoCreated: return "todo_created"
        case .journalUpdated: return "journal_updated"
        case .toolRejectedBySafety: return "tool_rejected_by_safety"
        case .onboardingCompleted: return "onboarding_completed"
        case .messageSent: return "message_sent"
        case .safetyClassified: return "safety_classified"
        }
    }
}

// MARK: - Analytics Service

/// Analytics service with typed events only
/// BANNED: No method accepts [String: Any] directly
/// This is intentional - prevents accidental content logging
final class Analytics: AnalyticsProtocol, Sendable {

    // MARK: - Shared Instance

    static let shared = Analytics()

    // MARK: - Initialization

    private init() {}

    // MARK: - Logging

    /// Log a typed event - no arbitrary dictionaries accepted
    func log(event: AnalyticsEvent) {
        #if DEBUG
        print("[Analytics] \(event.name) payload=\(event.payload)")
        #endif

        // Production: send event.name and event.payload to analytics service
        // Example: AnalyticsBackend.shared.track(event.name, properties: event.payload)
    }

    /// Log crisis detection - no content, just timestamp
    func logCrisis() {
        log(event: .crisisDetected)
    }

    /// Log safety classification - level only, no input text
    func logSafetyClassification(_ result: SafetyClassificationResult) {
        log(event: .safetyClassified(level: result.level))
    }
}

// MARK: - Disabled Analytics (for testing)

/// No-op analytics for testing
final class DisabledAnalytics: AnalyticsProtocol, Sendable {
    func log(event: AnalyticsEvent) {
        // No-op
    }
}
