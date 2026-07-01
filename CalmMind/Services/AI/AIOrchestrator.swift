import Foundation
import SwiftData
import os.log

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
    func generateWelcomeMessage() async throws -> String?
}

/// Orchestrates the AI conversation flow
/// Responsibilities:
/// - Safety classification before LLM calls
/// - Context management and token budgeting
/// - Tool call execution via ToolExecutor
/// - Message persistence
/// - INVARIANT: Every response must contain user-facing text (never empty)
@MainActor
final class AIOrchestrator: AIOrchestratorProtocol {

    // MARK: - Constants

    /// Maximum rounds of tool calls before forcing a text response
    private static let maxToolRounds = 2

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
    private let journalPersistence: JournalPersistenceActor?
    private let preferences: UserPreferences
    private let clock: any DateClock
    private let analytics: AnalyticsProtocol?
    private let logger = Logger(subsystem: "com.calmmind", category: "AIOrchestrator")

    // Weather & Semantic context (optional - gates decide usage)
    private let services: ServiceContainer?
    private let semanticSearchGate: SemanticSearchGate?
    private let semanticSearchEngine: SemanticSearchEngine?

    /// Callback for showing undo toast when auto-journaling saves
    var onJournalEventSaved: ((UUID) -> Void)?

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
        journalPersistence: JournalPersistenceActor? = nil,
        preferences: UserPreferences = .shared,
        clock: any DateClock = SystemClock(),
        analytics: AnalyticsProtocol? = nil,
        services: ServiceContainer? = nil,
        semanticSearchGate: SemanticSearchGate? = nil,
        semanticSearchEngine: SemanticSearchEngine? = nil
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
        self.journalPersistence = journalPersistence
        self.preferences = preferences
        self.clock = clock
        self.analytics = analytics
        self.services = services
        self.semanticSearchGate = semanticSearchGate
        self.semanticSearchEngine = semanticSearchEngine
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
        if let entry = journalRepository.fetchEntry(for: clock.now) {
            // Use summary if available, otherwise truncate full text
            todaysJournal = entry.summary ?? String(entry.fullText.prefix(200))
        } else {
            todaysJournal = nil
        }

        // Build weather context (discretionary - only extreme/transition)
        let weatherContext = buildWeatherContext()

        // Build semantic context (auto-enabled when threshold met)
        let semanticContext = await buildSemanticContext(query: trimmed)

        // Build system prompt with all explicit parameters (pure function)
        let systemPrompt = SystemPromptBuilder.build(
            userName: preferences.userName,
            autoCreateTodos: preferences.autoCreateTodos,
            recentTodos: todoTitles,
            todaysJournal: todaysJournal,
            memories: [],  // TODO: Add memory retrieval
            currentDate: clock.now,
            weatherContext: weatherContext,
            semanticContext: semanticContext
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

        // Handle tool calls with follow-up for conversational response
        var executedTools: [String] = []
        var finalContent = response.content ?? ""
        var currentMessages = openAIMessages
        var currentResponse = response
        var toolRound = 0
        var previousToolNames: Set<String> = []

        // Tool call loop with maxToolRounds limit
        while let toolCalls = currentResponse.toolCalls, !toolCalls.isEmpty, toolRound < Self.maxToolRounds {
            toolRound += 1

            // Reset rate limits for this message (only on first round)
            if toolRound == 1 {
                await toolExecutor.resetRateLimits()
            }

            // Convert OpenAI tool calls to our ToolCall type
            // Block same tool twice in a row
            let calls = toolCalls.compactMap { openAICall -> ToolCall? in
                let toolName = openAICall.function.name
                if previousToolNames.contains(toolName) {
                    logger.debug("Blocking repeated tool call: \(toolName)")
                    return nil
                }
                let arguments = toolValidator.parseArguments(openAICall.function.arguments) ?? [:]
                return ToolCall(
                    id: openAICall.id,
                    name: toolName,
                    arguments: arguments
                )
            }

            guard !calls.isEmpty else { break }

            // Track tool names for duplicate prevention
            previousToolNames = Set(calls.map { $0.name })

            // Execute with policy-based filtering
            let results = await toolExecutor.execute(calls, policy: policy)
            executedTools.append(contentsOf: results.filter { $0.wasAllowed }.map { $0.toolName })

            // Add assistant message with tool calls to conversation
            currentMessages.append(OpenAIMessage(
                role: .assistant,
                content: currentResponse.content,
                toolCallId: nil,
                toolCalls: toolCalls
            ))

            // Add tool results as messages
            for result in results {
                currentMessages.append(OpenAIMessage(
                    role: .tool,
                    content: result.output,
                    toolCallId: result.toolCallId,
                    toolCalls: nil
                ))
            }

            // Make follow-up API call to get conversational response
            do {
                currentResponse = try await openAIService.sendChatCompletion(
                    messages: currentMessages,
                    tools: toolRound < Self.maxToolRounds ? toolRegistry.openAIToolDefinitions : nil,
                    model: AppConfig.shared.aiModel,
                    maxTokens: AppConfig.shared.maxTokens
                )
                finalContent = currentResponse.content ?? ""
            } catch {
                // On follow-up failure, use fallback message
                logger.error("Follow-up API call failed: \(error.localizedDescription)")
                break
            }
        }

        // INVARIANT: Must speak - ensure we have user-facing text
        let responseContent = ensureNonEmptyResponse(
            content: finalContent,
            executedTools: executedTools
        )

        // Save assistant response
        let assistantMessage = ChatMessage(content: responseContent, role: .assistant)
        try messageRepository.save(assistantMessage, to: session)

        // Auto-journal if enabled (fire-and-forget, non-blocking)
        Task {
            await saveToJournalIfEnabled(userMessage: trimmed)
        }

        return OrchestratorResponse(
            content: responseContent,
            isCrisisResponse: false,
            toolsExecuted: executedTools,
            safetyLevel: safetyResult.level
        )
    }

    // MARK: - Response Helpers

    /// INVARIANT: Every response must contain user-facing text
    /// If content is empty or whitespace, generate a warm fallback based on what was done
    private func ensureNonEmptyResponse(content: String, executedTools: [String]) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // If we have content, use it
        if !trimmed.isEmpty {
            return trimmed
        }

        // Generate warm fallback based on executed tools
        if executedTools.isEmpty {
            return "I'm here if you'd like to talk."
        }

        // Build tool-specific confirmation
        let toolDescriptions = executedTools.map { toolName -> String in
            switch toolName {
            case "add_todo":
                return "your task"
            case "complete_todo":
                return "the task completion"
            case "write_journal":
                return "your journal"
            case "list_todos":
                return "your tasks"
            default:
                return toolName.replacingOccurrences(of: "_", with: " ")
            }
        }

        let uniqueDescriptions = Array(Set(toolDescriptions))
        if uniqueDescriptions.count == 1 {
            return "All set. I've updated \(uniqueDescriptions[0])."
        } else {
            let list = uniqueDescriptions.dropLast().joined(separator: ", ")
            let last = uniqueDescriptions.last ?? ""
            return "All set. I've updated \(list) and \(last)."
        }
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

    // MARK: - Welcome Message

    /// Context for generating a welcome message
    struct WelcomeContext {
        let timeOfDay: String
        let formattedTime: String
        let hasTodos: Bool
        let lastMessageTime: Date?
        let isPrivacyModeOn: Bool
    }

    /// Generate a warm welcome message with safety guardrails
    /// Rules:
    /// - Never mention specific names, places, or sensitive details
    /// - Use themes, not specifics
    /// - One question max
    /// - Cache once per day (keyed by startOfLocalDay)
    /// - Skip if last message was within 4 hours
    /// - Skip if user has already sent a message today
    /// - No tool calls
    ///
    /// - Returns: Welcome message or nil if skipped
    func generateWelcomeMessage() async throws -> String? {
        // Check privacy mode - defense in depth
        if preferences.privacyModeEnabled {
            return WarmCopy.promptFallback
        }

        // Get today's session
        let today = Calendar.current.startOfDay(for: clock.now)
        guard let session = try? sessionRepository.getOrCreate(for: clock.now) else {
            return WarmCopy.promptFallback
        }

        // Check if user has already sent a message today
        let messages = try? messageRepository.fetchMessages(for: session)
        let userMessages = messages?.filter { $0.role == .user } ?? []
        if !userMessages.isEmpty {
            // User already engaged today - skip welcome
            return nil
        }

        // Check last message time (skip if within 4 hours)
        if let lastMessage = messages?.last,
           clock.now.timeIntervalSince(lastMessage.timestamp) < 4 * 3600 {
            return nil
        }

        // Check cache (keyed by startOfLocalDay)
        let cacheKey = "welcomeMessage_\(ISO8601DateFormatter().string(from: today))"
        if let cached = UserDefaults.standard.string(forKey: cacheKey) {
            return cached
        }

        // Build context
        let hour = Calendar.current.component(.hour, from: clock.now)
        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<21: timeOfDay = "evening"
        default: timeOfDay = "night"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let formattedTime = formatter.string(from: clock.now)

        let todos = try? todoRepository.fetchIncomplete()
        let hasTodos = !(todos?.isEmpty ?? true)

        // Build welcome prompt with safety rules
        let systemPrompt = """
        Write a warm, brief (1-2 sentences) greeting for a mental health companion app.

        Context:
        - Time of day: \(timeOfDay) (\(formattedTime))
        - User has pending tasks: \(hasTodos ? "yes" : "no")

        Rules (CRITICAL):
        - Ask ONE question about their day or how they're feeling
        - Do NOT mention specific names, places, companies, or events
        - Do NOT start with "I noticed" or reference any personal data
        - Keep it warm, conversational, and natural
        - Do NOT be robotic or clinical
        - Maximum 2 sentences
        """

        do {
            let response = try await openAIService.sendChatCompletion(
                messages: [OpenAIMessage(role: .system, content: systemPrompt, toolCallId: nil, toolCalls: nil)],
                tools: nil,  // No tools for welcome
                model: AppConfig.shared.aiModel,
                maxTokens: 100
            )

            let content = response.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if !content.isEmpty {
                // Cache for today
                UserDefaults.standard.set(content, forKey: cacheKey)
                return content
            }
        } catch {
            logger.error("Failed to generate welcome message: \(error.localizedDescription)")
        }

        return WarmCopy.promptFallback
    }

    // MARK: - Auto-Journaling

    /// Save user message to journal if auto-journaling is enabled
    /// - Parameter userMessage: The user's message text
    private func saveToJournalIfEnabled(userMessage: String) async {
        // Check opt-in setting
        guard preferences.autoJournalingEnabled else { return }

        // Skip if no persistence actor configured
        guard let persistence = journalPersistence else {
            logger.debug("Auto-journaling skipped: no persistence actor")
            return
        }

        // Create event with user text only (truncated at init)
        let event = JournalEvent(userText: userMessage)

        do {
            try await persistence.addEvent(event)
            logger.debug("Auto-journaled event \(event.id)")

            // Notify for undo toast (on main actor)
            onJournalEventSaved?(event.id)
        } catch {
            logger.error("Failed to auto-journal: \(error.localizedDescription)")
            // Don't throw - auto-journaling failure shouldn't break chat
        }
    }

    /// Exclude a journal event from synthesis (for undo action)
    /// - Parameter eventID: The event ID to exclude
    func excludeJournalEvent(_ eventID: UUID) async {
        guard let persistence = journalPersistence else { return }
        do {
            try await persistence.excludeEventFromSynthesis(eventID)
            logger.debug("Excluded journal event \(eventID)")
        } catch {
            logger.error("Failed to exclude journal event: \(error.localizedDescription)")
        }
    }

    // MARK: - Context Building (Weather & Semantic)

    /// Build weather context for system prompt
    /// Only returns context for extreme weather or notable transitions
    /// Returns nil if: no services, privacy mode, no API key, or weather not noteworthy
    private func buildWeatherContext() -> String? {
        guard let services = services else { return nil }

        // Gate checks: privacy mode + API availability
        guard services.weatherAPIStatus == .available else { return nil }

        // Get cached weather (don't fetch - we're in a message processing flow)
        guard let current = services.weatherService.getCachedWeather() else { return nil }

        // Get progression and history for mention decision
        let progression = services.weatherStore.getProgression(for: services.startOfDay(for: clock.now))
        let recentHistory = services.weatherStore.getRecentDays()

        // WeatherContextProvider decides if this weather is worth mentioning
        guard WeatherContextProvider.shouldMentionWeather(
            current: current,
            progression: progression.hadTransition ? progression : nil,
            recentHistory: recentHistory.isEmpty ? nil : recentHistory
        ) else {
            return nil
        }

        // Build the context string
        return WeatherContextProvider.buildContext(
            current: current,
            progression: progression.hadTransition ? progression : nil,
            location: current.locationName
        )
    }

    /// Build semantic context for system prompt
    /// Only returns context if gate allows and search succeeds
    /// Returns nil if: no engine, privacy mode, below threshold, or search fails
    private func buildSemanticContext(query: String) async -> String? {
        guard let gate = semanticSearchGate,
              let engine = semanticSearchEngine else { return nil }

        // Gate checks: privacy mode + topic threshold
        guard gate.shouldEnableContext() else { return nil }

        do {
            let results = try await engine.search(query: query, limit: 3)
            return SemanticContextBuilder.buildContext(from: results)
        } catch {
            logger.debug("Semantic search failed: \(error.localizedDescription)")
            return nil  // Non-critical failure
        }
    }
}
