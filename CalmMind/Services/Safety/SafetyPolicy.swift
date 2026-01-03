import Foundation

/// Policy determining behavior based on safety level
/// Single decision point - one policy table, no scattered logic
enum SafetyPolicy: Sendable {
    /// Normal operation - all tools available
    case normal

    /// LLM ok, but tools disabled (cautionary messages)
    case restrictedTools

    /// Bypass LLM entirely - canned response only (crisis)
    case bypassLLM

    /// Map SafetyLevel to SafetyPolicy
    static func from(_ level: SafetyLevel) -> SafetyPolicy {
        switch level {
        case .safe, .supportive:
            return .normal
        case .cautionary:
            return .restrictedTools
        case .crisis:
            return .bypassLLM
        }
    }
}

// MARK: - Tool Allowlist

extension SafetyPolicy {
    /// Explicit allowlist per safety state
    /// INVARIANT: This is the ONLY place that determines which tools are allowed
    /// UPDATE THIS when adding new tools to the registry
    ///
    /// Current Tool Inventory (v1.0):
    /// | Tool           | Type  | Exists Now? |
    /// |----------------|-------|-------------|
    /// | add_todo       | Write | Yes         |
    /// | write_journal  | Write | Yes         |
    /// | complete_todo  | Write | Yes         |
    /// | read_journal   | Read  | No (future) |
    /// | get_todos      | Read  | No (future) |
    var allowedTools: Set<String> {
        switch self {
        case .normal:
            // All tools available
            return ["add_todo", "write_journal", "complete_todo", "create_journal_draft", "list_todos", "add_memory"]

        case .restrictedTools:
            // No write tools for cautionary messages
            // Future: Allow read-only tools when implemented
            return []

        case .bypassLLM:
            // NO tools at all - crisis bypasses everything
            return []
        }
    }

    /// Check if a specific tool is allowed under this policy
    func isToolAllowed(_ toolName: String) -> Bool {
        allowedTools.contains(toolName)
    }
}

// MARK: - Policy Decision

/// Result of applying safety policy to a message
struct SafetyPolicyDecision: Sendable {
    let policy: SafetyPolicy
    let classification: SafetyClassificationResult
    let allowedTools: Set<String>

    init(classification: SafetyClassificationResult) {
        self.classification = classification
        self.policy = SafetyPolicy.from(classification.level)
        self.allowedTools = policy.allowedTools
    }
}
