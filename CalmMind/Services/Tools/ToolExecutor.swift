import Foundation

// MARK: - Tool Call

/// Represents a tool call from the LLM.
///
/// Conforms to `Sendable` via the `@unchecked` extension below because `arguments`
/// holds a `[String: Any]` that cannot be proven Sendable at compile time; it is
/// treated as immutable after construction.
struct ToolCall {
    let id: String
    let name: String
    let arguments: [String: Any]

    /// Coerce append argument from string if needed (LLMs sometimes send "true" as string)
    func getBoolArgument(_ key: String, default defaultValue: Bool = false) -> Bool {
        if let boolValue = arguments[key] as? Bool {
            return boolValue
        } else if let stringValue = arguments[key] as? String {
            return stringValue.lowercased() == "true"
        }
        return defaultValue
    }

    func getStringArgument(_ key: String) -> String? {
        arguments[key] as? String
    }
}

extension ToolCall: @unchecked Sendable {}

// MARK: - Tool Result

/// Result of tool execution
struct ToolResult: Sendable {
    let toolCallId: String
    let toolName: String
    let output: String
    let wasAllowed: Bool

    static func success(callId: String, name: String, output: String) -> ToolResult {
        ToolResult(toolCallId: callId, toolName: name, output: output, wasAllowed: true)
    }

    static func blocked(callId: String, name: String) -> ToolResult {
        ToolResult(
            toolCallId: callId,
            toolName: name,
            output: "Tool blocked by safety policy",
            wasAllowed: false
        )
    }
}

// MARK: - Tool Executor

/// INVARIANT: ToolExecutor is the SOLE serializer for tool execution.
/// JournalTools and TodoTools do NOT additionally serialize.
///
/// Concurrency Authority:
/// - Serializes ALL tool calls via actor isolation
/// - Handles thread hops (main → background → main)
/// - Enforces safety policy allowlisting (pre-dispatch)
/// - Enforces rate limits (max 3 journals, max 3 todos per message)
actor ToolExecutor {

    // MARK: - Rate Limits

    private static let maxJournalWritesPerMessage = 3
    private static let maxTodoAddsPerMessage = 3

    // MARK: - Dependencies

    private let journalTools: JournalTools
    private let todoTools: TodoTools
    private let preferences: UserPreferences
    private let analytics: AnalyticsProtocol?

    // MARK: - Per-Message State

    private var journalWriteCount = 0
    private var todoAddCount = 0

    // MARK: - Initialization

    init(
        journalTools: JournalTools,
        todoTools: TodoTools,
        preferences: UserPreferences = .shared,
        analytics: AnalyticsProtocol? = nil
    ) {
        self.journalTools = journalTools
        self.todoTools = todoTools
        self.preferences = preferences
        self.analytics = analytics
    }

    // MARK: - Public API

    /// Reset per-message rate limit counters
    /// Call this at the start of each new message processing
    func resetRateLimits() {
        journalWriteCount = 0
        todoAddCount = 0
    }

    /// Execute tool calls with pre-dispatch safety filtering
    /// - Parameters:
    ///   - calls: Array of tool calls from the LLM
    ///   - policy: Safety policy determining which tools are allowed
    /// - Returns: Array of results for each tool call
    func execute(_ calls: [ToolCall], policy: SafetyPolicy) async -> [ToolResult] {
        let allowedTools = policy.allowedTools

        var results: [ToolResult] = []

        for call in calls {
            // PRE-DISPATCH FILTERING - filter before execution, not after
            if !allowedTools.contains(call.name) {
                // Log rejected call (no content, just tool name)
                analytics?.log(event: .toolRejectedBySafety(toolName: call.name))

                results.append(.blocked(callId: call.id, name: call.name))
                continue
            }

            // Execute allowed tool
            let result = await executeSingleTool(call)
            results.append(result)
        }

        return results
    }

    /// Execute a single tool call (internal, already past policy check)
    private func executeSingleTool(_ call: ToolCall) async -> ToolResult {
        do {
            let output = try await executeToolLogic(call)
            return .success(callId: call.id, name: call.name, output: output)
        } catch {
            return ToolResult(
                toolCallId: call.id,
                toolName: call.name,
                output: "Tool execution failed: \(error.localizedDescription)",
                wasAllowed: true
            )
        }
    }

    /// Core tool execution logic
    private func executeToolLogic(_ call: ToolCall) async throws -> String {
        switch call.name {
        case "write_journal":
            // Rate limit check
            guard journalWriteCount < Self.maxJournalWritesPerMessage else {
                return "Rate limit exceeded: Maximum \(Self.maxJournalWritesPerMessage) journal writes per message"
            }
            journalWriteCount += 1

            let content = call.getStringArgument("content") ?? ""
            let append = call.getBoolArgument("append", default: true)

            let result = try journalTools.writeToTodaysJournal(content: content, append: append)
            return result.message ?? "Journal updated"

        case "add_todo":
            // Rate limit check
            guard todoAddCount < Self.maxTodoAddsPerMessage else {
                return "Rate limit exceeded: Maximum \(Self.maxTodoAddsPerMessage) todos per message"
            }
            todoAddCount += 1

            // Check user preference for auto-creation
            guard preferences.autoCreateTodos else {
                return "Todo auto-creation is disabled. User can enable in Settings."
            }

            let title = call.getStringArgument("title") ?? ""
            let result = try todoTools.addTodo(title: title)

            if result.success {
                analytics?.log(event: .todoCreated(count: 1))
            }

            return result.message ?? "Todo added"

        case "complete_todo":
            let title = call.getStringArgument("title")
            let id = call.getStringArgument("id")
            let result = try todoTools.completeTodo(title: title, id: id)
            return result.message ?? "Todo completed"

        case "list_todos":
            let includeCompleted = call.getBoolArgument("include_completed", default: false)
            let result = try todoTools.listTodos(includeCompleted: includeCompleted)
            return "Found \(result.totalCount) todos"

        case "create_journal_draft":
            // This requires a session ID which we don't have in this context
            return "Journal draft creation requires session context"

        case "add_memory":
            // Memory tool - not yet implemented in this executor
            return "Memory tool not yet available"

        default:
            return "Unknown tool: \(call.name)"
        }
    }
}

// MARK: - Analytics Protocol

/// Protocol for analytics logging (allows mocking)
protocol AnalyticsProtocol: Sendable {
    func log(event: AnalyticsEvent)
}
