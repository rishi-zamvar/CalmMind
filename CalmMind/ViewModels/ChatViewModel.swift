import Foundation
import SwiftUI
import SwiftData
import Observation

/// ViewModel for the chat interface
/// Manages conversation state, message sending, and error handling
@MainActor
@Observable
final class ChatViewModel {

    // MARK: - Published State

    /// All messages in the current session
    private(set) var messages: [ChatMessage] = []

    /// Current input text
    var inputText: String = ""

    /// Whether a message is being processed
    private(set) var isLoading: Bool = false

    /// Whether to show error alert
    var showError: Bool = false

    /// Error message to display
    private(set) var errorMessage: String?

    /// Whether the last response was a crisis response
    private(set) var lastResponseWasCrisis: Bool = false

    // MARK: - Computed Properties

    /// Whether the send button should be enabled
    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    // MARK: - Dependencies

    private let orchestrator: AIOrchestratorProtocol
    private let sessionRepository: SessionRepository
    private let messageRepository: MessageRepository

    // MARK: - Private State

    private var currentSession: DailySession?

    // MARK: - Initialization

    init(
        orchestrator: AIOrchestratorProtocol,
        sessionRepository: SessionRepository,
        messageRepository: MessageRepository
    ) {
        self.orchestrator = orchestrator
        self.sessionRepository = sessionRepository
        self.messageRepository = messageRepository
    }

    // MARK: - Session Management

    /// Load or create today's session
    /// If the session is empty, generate a welcome message
    func loadSession() async {
        do {
            currentSession = try sessionRepository.getOrCreate(for: Date())
            if let session = currentSession {
                messages = try messageRepository.fetchMessages(for: session)

                // Generate welcome message if session is empty
                if messages.isEmpty {
                    await generateWelcomeIfNeeded()
                }
            }
        } catch {
            errorMessage = "Failed to load session: \(error.localizedDescription)"
            showError = true
        }
    }

    /// Generate a welcome message if appropriate
    private func generateWelcomeIfNeeded() async {
        guard let session = currentSession else { return }

        do {
            if let welcome = try await orchestrator.generateWelcomeMessage() {
                // Save welcome as assistant message
                let welcomeMessage = ChatMessage(content: welcome, role: .assistant)
                try messageRepository.save(welcomeMessage, to: session)

                // Reload messages to include the welcome
                messages = try messageRepository.fetchMessages(for: session)
            }
        } catch {
            // Silently fail - welcome is optional
            // User can still interact without it
        }
    }

    // MARK: - Message Sending

    /// Send the current input message with optimistic UI
    /// The user message appears immediately with animation before API call
    func sendMessage() async {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate input
        guard !trimmedInput.isEmpty else {
            return
        }

        // 1. Create optimistic message with client ID
        let clientId = UUID()
        let userMessage = ChatMessage(
            clientMessageId: clientId,
            content: trimmedInput,
            role: .user,
            sendStatus: .sending
        )

        // 2. Append to local array with animation (optimistic UI)
        withAnimation(DesignTokens.messageEntrance) {
            messages.append(userMessage)
        }

        // 3. Clear input immediately for responsiveness
        inputText = ""

        // Clear any previous error
        showError = false
        errorMessage = nil

        // Start loading (shows typing indicator)
        isLoading = true

        do {
            // 4. Process the message (orchestrator persists it)
            let response = try await orchestrator.processMessage(trimmedInput)

            // 5. Update optimistic message status to sent
            if let index = messages.firstIndex(where: { $0.clientMessageId == clientId }) {
                messages[index].sendStatus = .sent
            }

            // Track if this was a crisis response
            lastResponseWasCrisis = response.isCrisisResponse

            // 6. Append assistant response with animation (not full reload)
            let assistantMessage = ChatMessage(
                content: response.content,
                role: .assistant,
                sendStatus: .sent
            )
            withAnimation(DesignTokens.messageEntrance) {
                messages.append(assistantMessage)
            }

        } catch let error as OrchestratorError {
            // 7. Mark as failed (don't remove - show retry)
            if let index = messages.firstIndex(where: { $0.clientMessageId == clientId }) {
                messages[index].sendStatus = .failed
            }
            handleOrchestratorError(error)
        } catch {
            if let index = messages.firstIndex(where: { $0.clientMessageId == clientId }) {
                messages[index].sendStatus = .failed
            }
            errorMessage = "An unexpected error occurred"
            showError = true
        }

        isLoading = false
    }

    /// Retry sending a failed message
    func retryMessage(_ message: ChatMessage) async {
        guard message.sendStatus == .failed else { return }

        // Update status to sending
        if let index = messages.firstIndex(where: { $0.clientMessageId == message.clientMessageId }) {
            messages[index].sendStatus = .sending
        }

        // Clear any previous error
        showError = false
        errorMessage = nil

        // Start loading
        isLoading = true

        do {
            // Resend with same content
            let response = try await orchestrator.processMessage(message.content)

            // Update status to sent
            if let index = messages.firstIndex(where: { $0.clientMessageId == message.clientMessageId }) {
                messages[index].sendStatus = .sent
            }

            // Track if this was a crisis response
            lastResponseWasCrisis = response.isCrisisResponse

            // Append assistant response
            let assistantMessage = ChatMessage(
                content: response.content,
                role: .assistant,
                sendStatus: .sent
            )
            withAnimation(DesignTokens.messageEntrance) {
                messages.append(assistantMessage)
            }

        } catch let error as OrchestratorError {
            // Keep as failed
            if let index = messages.firstIndex(where: { $0.clientMessageId == message.clientMessageId }) {
                messages[index].sendStatus = .failed
            }
            handleOrchestratorError(error)
        } catch {
            if let index = messages.firstIndex(where: { $0.clientMessageId == message.clientMessageId }) {
                messages[index].sendStatus = .failed
            }
            errorMessage = "An unexpected error occurred"
            showError = true
        }

        isLoading = false
    }

    // MARK: - Error Handling

    /// Dismiss the current error
    func dismissError() {
        showError = false
        errorMessage = nil
    }

    private func handleOrchestratorError(_ error: OrchestratorError) {
        switch error {
        case .emptyMessage:
            // Shouldn't happen since we validate, but handle anyway
            errorMessage = "Please enter a message"
        case .missingAPIKey:
            errorMessage = "API key not configured. Please go to Settings and enter your OpenAI API key."
        case .networkError:
            errorMessage = "Unable to connect. Please check your internet connection and try again."
        case .invalidResponse:
            errorMessage = "Received an invalid response. Please try again."
        case .toolExecutionFailed(let toolName):
            errorMessage = "Failed to execute \(toolName). Please try again."
        }
        showError = true
    }

    // MARK: - Scroll Management

    /// ID of the last message (for scrolling)
    var lastMessageId: UUID? {
        messages.last?.id
    }
}
