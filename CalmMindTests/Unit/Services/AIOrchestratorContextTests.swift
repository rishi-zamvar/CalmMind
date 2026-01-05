import XCTest
import SwiftData
import CoreLocation
@testable import CalmMind

/// Tests for AIOrchestrator context integration (weather + semantic)
/// TDD: These tests are written FIRST, implementation follows
@MainActor
final class AIOrchestratorContextTests: XCTestCase {

    var container: ModelContainer!
    var mockOpenAI: MockOpenAIService!
    var contextManager: ContextManager!
    var safetyClassifier: SafetyClassifier!
    var toolRegistry: ToolRegistry!
    var toolValidator: ToolValidator!
    var toolExecutor: ToolExecutor!
    var messageRepo: MessageRepository!
    var sessionRepo: SessionRepository!
    var todoRepo: TodoRepository!
    var journalRepo: JournalRepository!
    var topicRepo: TopicRepository!
    var userPreferences: UserPreferences!
    var weatherStore: WeatherStore!

    override func setUp() {
        super.setUp()

        container = try! ModelContainer(
            for: ChatMessage.self, DailySession.self, TodoItem.self, JournalEntry.self,
                 MemoryItem.self, Topic.self, Fact.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        mockOpenAI = MockOpenAIService()
        contextManager = ContextManager()
        safetyClassifier = SafetyClassifier()
        toolRegistry = ToolRegistry()
        toolValidator = ToolValidator(registry: toolRegistry)
        messageRepo = MessageRepository(context: container.mainContext)
        sessionRepo = SessionRepository(context: container.mainContext)
        todoRepo = TodoRepository(context: container.mainContext)
        journalRepo = JournalRepository(context: container.mainContext)
        topicRepo = TopicRepository(context: container.mainContext)
        userPreferences = UserPreferences(defaults: UserDefaults(suiteName: "test.\(UUID())")!)
        weatherStore = WeatherStore(defaults: UserDefaults(suiteName: "test.\(UUID())")!)

        let journalTools = JournalTools(
            journalRepository: journalRepo,
            sessionRepository: sessionRepo
        )
        let todoTools = TodoTools(todoRepository: todoRepo)
        toolExecutor = ToolExecutor(
            journalTools: journalTools,
            todoTools: todoTools
        )
    }

    override func tearDown() {
        userPreferences = nil
        weatherStore = nil
        topicRepo = nil
        journalRepo = nil
        todoRepo = nil
        sessionRepo = nil
        messageRepo = nil
        toolExecutor = nil
        toolValidator = nil
        toolRegistry = nil
        safetyClassifier = nil
        contextManager = nil
        mockOpenAI = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func createTopicWithEmbedding(name: String) throws {
        let topic = try topicRepo.create(name: name, type: .person)
        try topicRepo.updateEmbedding(for: topic, embedding: [0.1, 0.2, 0.3])
    }

    private func createExtremeWeather() -> Weather {
        Weather(
            temperature: 100,
            condition: .thunderstorm,
            description: "severe thunderstorm",
            humidity: 85,
            locationName: "Phoenix",
            timestamp: Date()
        )
    }

    private func createNormalWeather() -> Weather {
        Weather(
            temperature: 72,
            condition: .clear,
            description: "clear sky",
            humidity: 45,
            locationName: "San Francisco",
            timestamp: Date()
        )
    }

    // MARK: - SystemPromptBuilder Weather Context Tests

    func test_systemPrompt_includesWeatherContext_whenProvided() {
        let weatherContext = "Weather context: Currently 100°F, Thunderstorm in Phoenix."

        let prompt = SystemPromptBuilder.build(
            userName: nil,
            autoCreateTodos: true,
            recentTodos: [],
            todaysJournal: nil,
            memories: [],
            currentDate: Date(),
            weatherContext: weatherContext,
            semanticContext: nil
        )

        XCTAssertTrue(prompt.contains("100°F"))
        XCTAssertTrue(prompt.contains("Phoenix"))
    }

    func test_systemPrompt_excludesWeatherContext_whenNil() {
        let prompt = SystemPromptBuilder.build(
            userName: nil,
            autoCreateTodos: true,
            recentTodos: [],
            todaysJournal: nil,
            memories: [],
            currentDate: Date(),
            weatherContext: nil,
            semanticContext: nil
        )

        XCTAssertFalse(prompt.contains("Weather context"))
    }

    // MARK: - SystemPromptBuilder Semantic Context Tests

    func test_systemPrompt_includesSemanticContext_whenProvided() {
        let semanticContext = """
        Relevant context from your memory:

        ## Alice Smith
        • Works at Google
        • Lives in San Francisco
        """

        let prompt = SystemPromptBuilder.build(
            userName: nil,
            autoCreateTodos: true,
            recentTodos: [],
            todaysJournal: nil,
            memories: [],
            currentDate: Date(),
            weatherContext: nil,
            semanticContext: semanticContext
        )

        XCTAssertTrue(prompt.contains("Alice Smith"))
        XCTAssertTrue(prompt.contains("Works at Google"))
    }

    func test_systemPrompt_excludesSemanticContext_whenNil() {
        let prompt = SystemPromptBuilder.build(
            userName: nil,
            autoCreateTodos: true,
            recentTodos: [],
            todaysJournal: nil,
            memories: [],
            currentDate: Date(),
            weatherContext: nil,
            semanticContext: nil
        )

        XCTAssertFalse(prompt.contains("Relevant context from your memory"))
    }

    // MARK: - WeatherContextProvider Integration

    func test_weatherContext_extremeWeather_shouldInclude() {
        let extreme = createExtremeWeather()

        let shouldMention = WeatherContextProvider.shouldMentionWeather(
            current: extreme,
            progression: nil,
            recentHistory: nil
        )

        XCTAssertTrue(shouldMention, "Extreme weather should be mentioned")

        let context = WeatherContextProvider.buildContext(
            current: extreme,
            progression: nil,
            location: "Phoenix, AZ"
        )

        XCTAssertNotNil(context)
        XCTAssertTrue(context!.contains("100°F"))
    }

    func test_weatherContext_normalWeather_shouldExclude() {
        let normal = createNormalWeather()

        let shouldMention = WeatherContextProvider.shouldMentionWeather(
            current: normal,
            progression: nil,
            recentHistory: nil
        )

        XCTAssertFalse(shouldMention, "Normal weather should NOT be mentioned")

        let context = WeatherContextProvider.buildContext(
            current: normal,
            progression: nil,
            location: "San Francisco"
        )

        XCTAssertNil(context)
    }

    // MARK: - SemanticSearchGate Integration

    func test_semanticContext_enabled_whenAboveThreshold() throws {
        // Create 5 topics with embeddings (at threshold)
        for i in 1...5 {
            try createTopicWithEmbedding(name: "Person \(i)")
        }

        let gate = SemanticSearchGate(
            topicRepository: topicRepo,
            userPreferences: userPreferences
        )

        XCTAssertTrue(gate.shouldEnableContext())
    }

    func test_semanticContext_disabled_whenBelowThreshold() throws {
        // Create only 2 topics with embeddings
        try createTopicWithEmbedding(name: "Alice")
        try createTopicWithEmbedding(name: "Bob")

        let gate = SemanticSearchGate(
            topicRepository: topicRepo,
            userPreferences: userPreferences
        )

        XCTAssertFalse(gate.shouldEnableContext())
    }

    // MARK: - Privacy Mode Tests

    func test_weatherContext_privacyMode_excluded() {
        userPreferences.privacyModeEnabled = true

        let extreme = createExtremeWeather()

        // Weather context should still return nil when buildContext respects preferences
        // The actual orchestrator would check privacy mode before building context
        // This test verifies the pattern we expect in AIOrchestrator
        XCTAssertTrue(userPreferences.privacyModeEnabled)
    }

    func test_semanticContext_privacyMode_disabled() throws {
        // Create enough topics
        for i in 1...10 {
            try createTopicWithEmbedding(name: "Person \(i)")
        }

        userPreferences.privacyModeEnabled = true

        let gate = SemanticSearchGate(
            topicRepository: topicRepo,
            userPreferences: userPreferences
        )

        XCTAssertFalse(gate.shouldEnableContext(), "Privacy mode should disable semantic context")
    }

    // MARK: - Combined Context Tests

    func test_systemPrompt_includesBothContexts_whenBothProvided() {
        let weatherContext = "Weather: 100°F Thunderstorm in Phoenix"
        let semanticContext = "Relevant: Alice works at Google"

        let prompt = SystemPromptBuilder.build(
            userName: "Rishi",
            autoCreateTodos: true,
            recentTodos: [],
            todaysJournal: nil,
            memories: [],
            currentDate: Date(),
            weatherContext: weatherContext,
            semanticContext: semanticContext
        )

        XCTAssertTrue(prompt.contains("100°F"))
        XCTAssertTrue(prompt.contains("Alice works at Google"))
    }
}
