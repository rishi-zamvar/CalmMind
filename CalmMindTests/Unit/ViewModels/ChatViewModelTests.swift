import XCTest
import SwiftData
@testable import CalmMind

@MainActor
final class ChatViewModelTests: XCTestCase {

    var sut: ChatViewModel!
    var container: ModelContainer!
    var mockOrchestrator: MockAIOrchestrator!
    var sessionRepo: SessionRepository!
    var messageRepo: MessageRepository!

    override func setUp() {
        super.setUp()
        container = try! ModelContainer(
            for: ChatMessage.self, DailySession.self, TodoItem.self, JournalEntry.self, MemoryItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        mockOrchestrator = MockAIOrchestrator()
        sessionRepo = SessionRepository(context: container.mainContext)
        messageRepo = MessageRepository(context: container.mainContext)

        sut = ChatViewModel(
            orchestrator: mockOrchestrator,
            sessionRepository: sessionRepo,
            messageRepository: messageRepo
        )
    }

    override func tearDown() {
        sut = nil
        messageRepo = nil
        sessionRepo = nil
        mockOrchestrator = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Session Management

    func test_loadsExistingSession_forToday() async throws {
        // Create a session with messages
        let session = try sessionRepo.getOrCreate(for: Date())
        let message = ChatMessage(content: "Hello", role: .user)
        try messageRepo.save(message, to: session)

        // Load the view model
        await sut.loadSession()

        // Should have the message
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages.first?.content, "Hello")
    }

    func test_createsNewSession_forNewDay() async throws {
        // Load session (no existing session)
        await sut.loadSession()

        // Should have empty messages but session exists
        XCTAssertTrue(sut.messages.isEmpty)

        // Session should be created
        let sessions = try sessionRepo.fetchRecentSessions(limit: 10)
        XCTAssertEqual(sessions.count, 1)
    }

    func test_messagesOrdered_chronologically() async throws {
        let session = try sessionRepo.getOrCreate(for: Date())

        // Add messages with slight time gaps
        let msg1 = ChatMessage(content: "First", role: .user)
        try messageRepo.save(msg1, to: session)

        let msg2 = ChatMessage(content: "Second", role: .assistant)
        try messageRepo.save(msg2, to: session)

        let msg3 = ChatMessage(content: "Third", role: .user)
        try messageRepo.save(msg3, to: session)

        await sut.loadSession()

        XCTAssertEqual(sut.messages.count, 3)
        XCTAssertEqual(sut.messages[0].content, "First")
        XCTAssertEqual(sut.messages[1].content, "Second")
        XCTAssertEqual(sut.messages[2].content, "Third")
    }

    // MARK: - Sending Messages

    func test_sendMessage_validatesInput() async {
        sut.inputText = ""

        await sut.sendMessage()

        // Should not call orchestrator for empty input
        XCTAssertEqual(mockOrchestrator.processCallCount, 0)
    }

    func test_sendMessage_validatesWhitespaceOnly() async {
        sut.inputText = "   \n\t  "

        await sut.sendMessage()

        XCTAssertEqual(mockOrchestrator.processCallCount, 0)
    }

    func test_sendMessage_callsOrchestrator() async {
        mockOrchestrator.mockResponse = OrchestratorResponse(content: "Hello!")
        sut.inputText = "Hi there"

        await sut.sendMessage()

        XCTAssertEqual(mockOrchestrator.processCallCount, 1)
        XCTAssertEqual(mockOrchestrator.lastMessage, "Hi there")
    }

    func test_sendMessage_clearsInputText() async {
        mockOrchestrator.mockResponse = OrchestratorResponse(content: "Response")
        sut.inputText = "My message"

        await sut.sendMessage()

        XCTAssertEqual(sut.inputText, "")
    }

    func test_sendMessage_callsOrchestratorWithCorrectMessage() async {
        mockOrchestrator.mockResponse = OrchestratorResponse(content: "I understand")
        sut.inputText = "I feel stressed"

        await sut.loadSession() // Initialize session
        await sut.sendMessage()

        // Verify orchestrator was called with the correct message
        XCTAssertEqual(mockOrchestrator.processCallCount, 1)
        XCTAssertEqual(mockOrchestrator.lastMessage, "I feel stressed")
    }

    func test_canSend_falseWhenEmpty() {
        sut.inputText = ""
        XCTAssertFalse(sut.canSend)
    }

    func test_canSend_falseWhenWhitespaceOnly() {
        sut.inputText = "   "
        XCTAssertFalse(sut.canSend)
    }

    func test_canSend_trueWhenHasContent() {
        sut.inputText = "Hello"
        XCTAssertTrue(sut.canSend)
    }

    func test_canSend_falseWhenLoading() async {
        sut.inputText = "Hello"
        mockOrchestrator.delay = 0.5

        // Start sending (don't await)
        let task = Task {
            await sut.sendMessage()
        }

        // Give it a moment to start
        try? await Task.sleep(for: .milliseconds(50))

        // Should be loading
        XCTAssertTrue(sut.isLoading)
        XCTAssertFalse(sut.canSend)

        await task.value
    }

    // MARK: - Loading States

    func test_isLoading_whileWaitingForResponse() async {
        mockOrchestrator.delay = 0.2
        mockOrchestrator.mockResponse = OrchestratorResponse(content: "Done")
        sut.inputText = "Test"

        XCTAssertFalse(sut.isLoading)

        let task = Task {
            await sut.sendMessage()
        }

        // Wait a bit for loading to start
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(sut.isLoading)

        await task.value
        XCTAssertFalse(sut.isLoading)
    }

    func test_isLoading_falseAfterResponse() async {
        mockOrchestrator.mockResponse = OrchestratorResponse(content: "Response")
        sut.inputText = "Message"

        await sut.sendMessage()

        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Error Handling

    func test_showsError_onNetworkFailure() async {
        mockOrchestrator.shouldFail = true
        mockOrchestrator.failureError = OrchestratorError.networkError
        sut.inputText = "Test message"

        await sut.sendMessage()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.showError)
    }

    func test_errorCleared_onNewSend() async {
        // First send fails
        mockOrchestrator.shouldFail = true
        mockOrchestrator.failureError = OrchestratorError.networkError
        sut.inputText = "First"
        await sut.sendMessage()

        XCTAssertTrue(sut.showError)

        // Second send succeeds
        mockOrchestrator.shouldFail = false
        mockOrchestrator.mockResponse = OrchestratorResponse(content: "OK")
        sut.inputText = "Second"
        await sut.sendMessage()

        XCTAssertFalse(sut.showError)
        XCTAssertNil(sut.errorMessage)
    }

    func test_dismissError_clearsError() async {
        mockOrchestrator.shouldFail = true
        mockOrchestrator.failureError = OrchestratorError.networkError
        sut.inputText = "Test"
        await sut.sendMessage()

        XCTAssertTrue(sut.showError)

        sut.dismissError()

        XCTAssertFalse(sut.showError)
    }

    // MARK: - Crisis Response

    func test_crisisResponse_marked() async {
        mockOrchestrator.mockResponse = OrchestratorResponse(
            content: "I hear you...",
            isCrisisResponse: true,
            toolsExecuted: []
        )
        sut.inputText = "I want to hurt myself"

        await sut.sendMessage()

        // The view model should track that last response was crisis
        XCTAssertTrue(sut.lastResponseWasCrisis)
    }

    func test_normalResponse_notMarkedAsCrisis() async {
        mockOrchestrator.mockResponse = OrchestratorResponse(content: "Hello!")
        sut.inputText = "Hi"

        await sut.sendMessage()

        XCTAssertFalse(sut.lastResponseWasCrisis)
    }
}

// MARK: - Mock AIOrchestrator

@MainActor
final class MockAIOrchestrator: AIOrchestratorProtocol {
    var mockResponse: OrchestratorResponse = OrchestratorResponse(content: "Mock response")
    var shouldFail: Bool = false
    var failureError: OrchestratorError = .networkError
    var delay: TimeInterval = 0

    var processCallCount: Int = 0
    var lastMessage: String?

    func processMessage(_ userMessage: String) async throws -> OrchestratorResponse {
        processCallCount += 1
        lastMessage = userMessage

        if delay > 0 {
            try await Task.sleep(for: .seconds(delay))
        }

        if shouldFail {
            throw failureError
        }

        return mockResponse
    }
}
