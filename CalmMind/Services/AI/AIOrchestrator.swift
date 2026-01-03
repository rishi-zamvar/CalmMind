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

    init(content: String, isCrisisResponse: Bool = false, toolsExecuted: [String] = []) {
        self.content = content
        self.isCrisisResponse = isCrisisResponse
        self.toolsExecuted = toolsExecuted
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
/// - Tool call execution
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
    private let messageRepository: MessageRepository
    private let sessionRepository: SessionRepository
    private let todoRepository: TodoRepository
    private let journalRepository: JournalRepository

    // MARK: - Initialization

    init(
        openAIService: OpenAIServiceProtocol,
        contextManager: ContextManager,
        safetyClassifier: SafetyClassifier,
        toolRegistry: ToolRegistry,
        toolValidator: ToolValidator,
        messageRepository: MessageRepository,
        sessionRepository: SessionRepository,
        todoRepository: TodoRepository,
        journalRepository: JournalRepository
    ) {
        self.openAIService = openAIService
        self.contextManager = contextManager
        self.safetyClassifier = safetyClassifier
        self.crisisComposer = CrisisResponseComposer()
        self.toolRegistry = toolRegistry
        self.toolValidator = toolValidator
        self.messageRepository = messageRepository
        self.sessionRepository = sessionRepository
        self.todoRepository = todoRepository
        self.journalRepository = journalRepository
    }

    // MARK: - System Prompt

    func buildSystemPrompt(
        recentTodos: [String] = [],
        yesterdaySummary: String? = nil,
        memories: [String] = []
    ) -> String {
        var prompt = """
        You are a compassionate AI mental health companion. Your role is to:
        - Listen with empathy and validate emotions
        - Help users reflect on their thoughts and feelings
        - Suggest healthy coping strategies when appropriate
        - Never provide medical advice or diagnoses
        - Always encourage professional help when needed

        Today's date: \(formatCurrentDate())

        Guidelines:
        - Be warm, supportive, and non-judgmental
        - Ask open-ended questions to encourage reflection
        - Acknowledge and validate feelings
        - Suggest actionable self-care when appropriate
        - For serious concerns, recommend professional support
        """

        if !recentTodos.isEmpty {
            prompt += "\n\nUser's current todos:\n"
            for todo in recentTodos.prefix(5) {
                prompt += "- \(todo)\n"
            }
        }

        if let summary = yesterdaySummary {
            prompt += "\n\nYesterday's conversation summary:\n\(summary)"
        }

        if !memories.isEmpty {
            prompt += "\n\nRelevant context from past conversations:\n"
            for memory in memories.prefix(3) {
                prompt += "- \(memory)\n"
            }
        }

        return prompt
    }

    private func formatCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }

    // MARK: - Message Processing

    func processMessage(_ userMessage: String) async throws -> OrchestratorResponse {
        // Validate input
        let trimmed = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw OrchestratorError.emptyMessage
        }

        // Get or create today's session
        let session = try sessionRepository.getOrCreate(for: Date())

        // CRITICAL: Save user message BEFORE any network call
        let userChatMessage = ChatMessage(content: trimmed, role: .user)
        try messageRepository.save(userChatMessage, to: session)

        // Check safety FIRST (before LLM call)
        let safetyResult = safetyClassifier.classify(trimmed)
        if safetyResult.level == .crisis {
            return handleCrisisMessage(trimmed, session: session)
        }

        // Build context for OpenAI
        let recentMessages = try messageRepository.fetchMessages(for: session)
        let todos = try todoRepository.fetchIncomplete()
        let todoTitles = todos.map { $0.title }

        let systemPrompt = buildSystemPrompt(recentTodos: todoTitles)

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

        // Handle tool calls if present
        var executedTools: [String] = []
        if let toolCalls = response.toolCalls {
            for toolCall in toolCalls {
                _ = await executeToolCall(toolCall, session: session)
                executedTools.append(toolCall.function.name)
            }
        }

        // Get the response content
        let responseContent = response.content ?? "I'm here to listen."

        // Save assistant response
        if !responseContent.isEmpty {
            let assistantMessage = ChatMessage(content: responseContent, role: .assistant)
            try messageRepository.save(assistantMessage, to: session)
        }

        return OrchestratorResponse(
            content: responseContent,
            isCrisisResponse: false,
            toolsExecuted: executedTools
        )
    }

    // MARK: - Crisis Handling

    private func handleCrisisMessage(_ message: String, session: DailySession) -> OrchestratorResponse {
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
            toolsExecuted: []
        )
    }

    // MARK: - Tool Execution

    private func executeToolCall(_ toolCall: OpenAIToolCall, session: DailySession) async -> String {
        let functionName = toolCall.function.name
        let argumentsJSON = toolCall.function.arguments

        // Parse arguments
        guard let arguments = toolValidator.parseArguments(argumentsJSON) else {
            return "Failed to parse tool arguments"
        }

        // Validate the tool call
        let validation = toolValidator.validate(toolName: functionName, arguments: arguments)
        guard validation.isValid else {
            return "Invalid tool call: \(validation.error ?? "Unknown error")"
        }

        // Execute based on tool name
        do {
            switch functionName {
            case "add_todo":
                let title = arguments["title"] as? String ?? ""
                let todoTools = TodoTools(todoRepository: todoRepository)
                let result = try todoTools.addTodo(title: title)
                return result.message ?? "Todo added"

            case "complete_todo":
                let title = arguments["title"] as? String
                let id = arguments["id"] as? String
                let todoTools = TodoTools(todoRepository: todoRepository)
                let result = try todoTools.completeTodo(title: title, id: id)
                return result.message ?? "Todo completed"

            case "list_todos":
                let includeCompleted = arguments["include_completed"] as? Bool ?? false
                let todoTools = TodoTools(todoRepository: todoRepository)
                let result = try todoTools.listTodos(includeCompleted: includeCompleted)
                return "Found \(result.totalCount) todos"

            case "create_journal_draft":
                let journalTools = JournalTools(
                    journalRepository: journalRepository,
                    sessionRepository: sessionRepository
                )
                let result = try journalTools.createDraft(for: session.id)
                return result.message ?? "Journal draft created"

            default:
                return "Unknown tool: \(functionName)"
            }
        } catch {
            return "Tool execution failed: \(error.localizedDescription)"
        }
    }
}
