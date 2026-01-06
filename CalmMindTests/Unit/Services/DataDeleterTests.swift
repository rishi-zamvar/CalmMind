import XCTest
import SwiftData
@testable import CalmMind

final class DataDeleterTests: XCTestCase {

    var sut: DataDeleter!
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: ChatMessage.self, DailySession.self, JournalEntry.self, TodoItem.self, MemoryItem.self, Topic.self, Fact.self,
            configurations: config
        )
        context = ModelContext(container)
        sut = DataDeleter(modelContext: context)
    }

    override func tearDown() {
        sut = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Delete All Data

    func test_deleteAllData_removesAllMessages() throws {
        // Add messages
        for i in 0..<5 {
            let message = ChatMessage(content: "Message \(i)", role: .user)
            context.insert(message)
        }
        try context.save()

        // Delete all
        try sut.deleteAllData()

        // Verify deletion
        let descriptor = FetchDescriptor<ChatMessage>()
        let remaining = try context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 0)
    }

    func test_deleteAllData_removesAllSessions() throws {
        let session1 = DailySession(date: Date())
        let session2 = DailySession(date: Date().addingTimeInterval(-86400))
        context.insert(session1)
        context.insert(session2)
        try context.save()

        try sut.deleteAllData()

        let descriptor = FetchDescriptor<DailySession>()
        let remaining = try context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 0)
    }

    func test_deleteAllData_removesAllJournals() throws {
        let entry = JournalEntry(fullText: "Test", date: Date())
        context.insert(entry)
        try context.save()

        try sut.deleteAllData()

        let descriptor = FetchDescriptor<JournalEntry>()
        let remaining = try context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 0)
    }

    func test_deleteAllData_removesAllTodos() throws {
        let todo = TodoItem(title: "Test todo")
        context.insert(todo)
        try context.save()

        try sut.deleteAllData()

        let descriptor = FetchDescriptor<TodoItem>()
        let remaining = try context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 0)
    }

    func test_deleteAllData_removesAllMemories() throws {
        let memory = MemoryItem(content: "Test memory")
        context.insert(memory)
        try context.save()

        try sut.deleteAllData()

        let descriptor = FetchDescriptor<MemoryItem>()
        let remaining = try context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 0)
    }

    func test_deleteAllData_removesAllTopics() throws {
        let topic = Topic(name: "Test Person", type: .person)
        context.insert(topic)
        try context.save()

        try sut.deleteAllData()

        let descriptor = FetchDescriptor<Topic>()
        let remaining = try context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 0)
    }

    func test_deleteAllData_cascadesDeleteToFacts() throws {
        let topic = Topic(name: "Test Person", type: .person)
        let fact = Fact(content: "Test fact", topic: topic)
        topic.facts.append(fact)
        context.insert(topic)
        try context.save()

        try sut.deleteAllData()

        let topicDescriptor = FetchDescriptor<Topic>()
        let factDescriptor = FetchDescriptor<Fact>()
        XCTAssertEqual(try context.fetch(topicDescriptor).count, 0)
        XCTAssertEqual(try context.fetch(factDescriptor).count, 0)
    }

    // MARK: - Idempotency

    func test_deleteAllData_isIdempotent() throws {
        // Add some data
        let message = ChatMessage(content: "Test", role: .user)
        context.insert(message)
        try context.save()

        // Delete twice - should not throw
        try sut.deleteAllData()
        try sut.deleteAllData()

        // Verify still empty
        let descriptor = FetchDescriptor<ChatMessage>()
        let remaining = try context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 0)
    }

    // MARK: - Comprehensive Cleanup

    func test_deleteAllData_deletesAllUserContent() throws {
        // Add data of all types
        let session = DailySession(date: Date())
        context.insert(session)

        let message = ChatMessage(content: "Test", role: .user)
        context.insert(message)

        let journal = JournalEntry(fullText: "Test", date: Date())
        context.insert(journal)

        let todo = TodoItem(title: "Test")
        context.insert(todo)

        let memory = MemoryItem(content: "Test")
        context.insert(memory)

        let topic = Topic(name: "Test Person", type: .person)
        context.insert(topic)

        try context.save()

        // Delete everything
        try sut.deleteAllData()

        // Verify all user content cleared
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChatMessage>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailySession>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TodoItem>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MemoryItem>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Topic>()).count, 0)
    }

    // MARK: - Preserves Settings (Regression Guard)

    func test_deleteAllData_doesNotAffectUserDefaults() throws {
        // Set some preferences
        let testDefaults = UserDefaults(suiteName: "com.calmmind.test.\(UUID().uuidString)")!
        testDefaults.set(true, forKey: "morningNotificationsEnabled")
        testDefaults.set("test-value", forKey: "customSetting")

        // Add some data
        let message = ChatMessage(content: "Test", role: .user)
        context.insert(message)
        try context.save()

        // Delete all data
        try sut.deleteAllData()

        // Verify preferences are preserved
        XCTAssertTrue(testDefaults.bool(forKey: "morningNotificationsEnabled"))
        XCTAssertEqual(testDefaults.string(forKey: "customSetting"), "test-value")

        // Cleanup
        testDefaults.removePersistentDomain(forName: "com.calmmind.test")
    }
}
