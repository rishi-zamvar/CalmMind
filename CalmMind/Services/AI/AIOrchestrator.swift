import Foundation
import SwiftData

/// Errors that can occur during orchestration
enum OrchestratorError: Error, Equatable {
    case emptyMessage
    case missingAPIKey
    case networkError
    case invalidResponse
    case toolExecutionFailed(String)
}

/// Response from the AI orchestrator
struct OrchestratorResponse: Sendable {
    let content: String
    let isCrisisResponse: Bool
    let toolsExecuted: [String]
    let safetyLevel: SafetyLevel

    init(content: String, isCrisisResponse: Bool = false, toolsExecuted: [String] = [], safetyLevel: SafetyLevel = .safe) {
        self.content = content
        self.isCrisisResponse = isCrisisResponse
        self.toolsExecuted = toolsExecuted
        self.safetyLevel = safetyLevel
    }
}

/// Protocol for AI orchestration (enables testing with mocks)
@MainActor
protocol AIOrchestratorProtocol {
    func processMessage(_ userMessage: String) async throws -> OrchestratorResponse
}

/// Orchestrates the AI conversation flow
/// Responsibilities:
/// - Safety classification before LLM calls
/// - Context management and token budgeting
/// - Tool call execution via ToolExecutor
/// - Message persistence
@MainActor
final class AIOrchestrator: AIOrchestratorProtocol {

    // MARK: - Dependencies

    private let openAIService: OpenAIServiceProtocol
    private let contextManager: ContextManager
    private let safetyClassifier: SafetyClassifier
    private let crisisComposer: CrisisResponseComposer
    private let toolRegistry: ToolRegistry
    private let toolValidator: ToolValidator
    private let toolExecutor: ToolExecutor
    private let messageRepository: MessageRepository
    private let sessionRepository: SessionRepository
    private let todoRepository: TodoRepository
    private let journalRepository: JournalRepository
    private let preferences: UserPreferences
    private let clock: any DateClock
    private let analytics: AnalyticsProtocol?

    // MARK: - Initialization

    init(
        openAIService: OpenAIServiceProtocol,
        contextManager: ContextManager,
        safetyClassifier: SafetyClassifier,
        toolRegistry: ToolRegistry,
        toolValidator: ToolValidator,
        toolExecutor: ToolExecutor,
        messageRepository: MessageRepository,
        sessionRepository: SessionRepository,
        todoRepository: TodoRepository,
        journalRepository: JournalRepository,
        preferences: UserPreferences = .shared,
        clock: any DateClock = SystemClock(),
        analytics: AnalyticsProtocol? = nil
    ) {
        self.openAIService = openAIService
        self.contextManager = contextManager
        self.safetyClassifier = safetyClassifier
        self.crisisComposer = CrisisResponseComposer()
        self.toolRegistry = toolRegistry
        self.toolValidator = toolValidator
        self.toolExecutor = toolExecutor
        self.messageRepository = messageRepository
        self.sessionRepository = sessionRepository
        self.todoRepository = todoRepository
        self.journalRepository = journalRepository
        self.preferences = preferences
        self.clock = clock
        self.analytics = analytics
    }

    // MARK: - Message Processing

    func processMessage(_ userMessage: String) async throws -> OrchestratorResponse {
        // Validate input
        let trimmed = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw OrchestratorError.emptyMessage
        }

        // Get or create today's session
        let session = try sessionRepository.getOrCreate(for: clock.now)

        // CRITICAL: Save user message BEFORE any network call
        let userChatMessage = ChatMessage(content: trimmed, role: .user)
        try messageRepository.save(userChatMessage, to: session)

        // SINGLE DECISION POINT: Classify safety and get policy
        let safetyResult = safetyClassifier.classify(trimmed)
        let policy = SafetyPolicy.from(safetyResult.level)

        // Log safety classification (level only, no content)
        analytics?.log(event: .safetyClassified(level: safetyResult.level))

        // Handle crisis - bypass LLM entirely
        if policy == .bypassLLM {
            analytics?.log(event: .crisisDetected)
            return handleCrisisMessage(trimmed, session: session, safetyLevel: safetyResult.level)
        }

        // Build context for OpenAI using pure function
        let recentMessages = try messageRepository.fetchMessages(for: session)
        let todos = try todoRepository.fetchIncomplete()
        let todoTitles = todos.map { $0.title }

        // Get today's journal summary (if any)
        let todaysJournal: String?
        if let entry = try journalRepository.fetchEntry(for: clock.now) {
            // Use summary if available, otherwise truncate full text
            todaysJournal = entry.summary ?? String(entry.fullText.prefix(200))
        } else {
            todaysJournal = nil
        }

        // Build system prompt with all explicit parameters (pure function)
        let systemPrompt = SystemPromptBuilder.build(
            userName: preferences.userName,
            autoCreateTodos: preferences.autoCreateTodos,
            recentTodos: todoTitles,
            todaysJournal: todaysJournal,
            memories: [],  // TODO: Add memory retrieval
            currentDate: clock.now
        )

        // Prepare messages for OpenAI
        var openAIMessages: [OpenAIMessage] = [
            OpenAIMessage(role: .system, content: systemPrompt, toolCallId: nil, toolCalls: nil)
        ]

        // Add recent conversation (limit to avoid token overflow)
        for message in recentMessages.suffix(20) {
            let role: OpenAIRole = {
                switch message.role {
                case .user: return .user
                case .assistant: return .assistant
                case .system: return .system
                }
            }()
            openAIMessages.append(OpenAIMessage(
                role: role,
                content: message.content,
                toolCallId: nil,
                toolCalls: nil
            ))
        }

        // Make the API call
        let response: ChatCompletionResponse
        do {
            response = try await openAIService.sendChatCompletion(
                messages: openAIMessages,
                tools: toolRegistry.openAIToolDefinitions,
                model: AppConfig.shared.aiModel,
                maxTokens: AppConfig.shared.maxTokens
            )
        } catch let error as OpenAIError {
            // Map specific OpenAI errors to orchestrator errors
            switch error {
            case .missingAPIKey:
                throw OrchestratorError.missingAPIKey
            case .invalidResponse, .decodingError:
                throw OrchestratorError.invalidResponse
            default:
                throw OrchestratorError.networkError
            }
        } catch {
            throw OrchestratorError.networkError
        }

        // Handle tool calls with PRE-DISPATCH FILTERING via ToolExecutor
        var executedTools: [String] = []
        if let toolCalls = response.toolCalls {
            // Reset rate limits for this message
            await toolExecutor.resetRateLimits()

            // Convert OpenAI tool calls to our ToolCall type
            let calls = toolCalls.map { openAICall in
                let arguments = toolValidator.parseArguments(openAICall.function.arguments) ?? [:]
                return ToolCall(
                    id: openAICall.id,
                    name: openAICall.function.name,
                    arguments: arguments
                )
            }

            // Execute with policy-based filtering (happens inside ToolExecutor)
            let results = await toolExecutor.execute(calls, policy: policy)

            // Collect executed tool names
            executedTools = results.filter { $0.wasAllowed }.map { $0.toolName }
        }

        // Get the response content - avoid generic fallback
        let responseContent = response.content ?? ""

        // Save assistant response
        if !responseContent.isEmpty {
            let assistantMessage = ChatMessage(content: responseContent, role: .assistant)
            try messageRepository.save(assistantMessage, to: session)
        }

        return OrchestratorResponse(
            content: responseContent,
            isCrisisResponse: false,
            toolsExecuted: executedTools,
            safetyLevel: safetyResult.level
        )
    }

    // MARK: - Crisis Handling

    private func handleCrisisMessage(_ message: String, session: DailySession, safetyLevel: SafetyLevel) -> OrchestratorResponse {
        // Generate crisis response WITHOUT calling LLM
        let crisisResponse = crisisComposer.compose(for: message)
        let responseText = crisisResponse.message

        // Save the response
        do {
            let assistantMessage = ChatMessage(content: responseText, role: .assistant)
            try messageRepository.save(assistantMessage, to: session)
        } catch {
            // Log error but don't fail - the crisis response is more important
        }

        return OrchestratorResponse(
            content: responseText,
            isCrisisResponse: true,
            toolsExecuted: [],
            safetyLevel: safetyLevel
        )
    }
}
