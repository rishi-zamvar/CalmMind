import XCTest
import SwiftData
@testable import CalmMind

final class DataExporterTests: XCTestCase {

    var sut: DataExporter!
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: ChatMessage.self, DailySession.self, JournalEntry.self, TodoItem.self, MemoryItem.self,
            configurations: config
        )
        context = ModelContext(container)
        sut = DataExporter(modelContext: context)
    }

    override func tearDown() {
        sut = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Export All Data

    func test_exportAllData_createsValidJSON() throws {
        // Add some test data
        let session = DailySession(date: Date())
        context.insert(session)

        let message = ChatMessage(content: "Hello", role: .user)
        context.insert(message)

        try context.save()

        let exportData = try sut.exportAllData()

        XCTAssertNotNil(exportData)
        XCTAssertFalse(exportData.isEmpty)

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: exportData)
        XCTAssertNotNil(json as? [String: Any])
    }

    func test_exportAllData_includesAllEntityTypes() throws {
        // Add one of each entity type
        let session = DailySession(date: Date())
        context.insert(session)

        let message = ChatMessage(content: "Test message", role: .user)
        context.insert(message)

        let journal = JournalEntry(fullText: "Test journal", date: Date())
        context.insert(journal)

        let todo = TodoItem(title: "Test todo")
        context.insert(todo)

        let memory = MemoryItem(content: "Test memory")
        context.insert(memory)

        try context.save()

        let exportData = try sut.exportAllData()
        let json = try JSONSerialization.jsonObject(with: exportData) as! [String: Any]

        XCTAssertNotNil(json["sessions"])
        XCTAssertNotNil(json["messages"])
        XCTAssertNotNil(json["journals"])
        XCTAssertNotNil(json["todos"])
        XCTAssertNotNil(json["memories"])
    }

    func test_exportAllData_excludesAPIKey() throws {
        let exportData = try sut.exportAllData()
        let jsonString = String(data: exportData, encoding: .utf8) ?? ""

        // Should not contain API key patterns
        XCTAssertFalse(jsonString.contains("sk-"))
        XCTAssertFalse(jsonString.contains("apiKey"))
        XCTAssertFalse(jsonString.contains("api_key"))
    }

    func test_exportAllData_includesExportMetadata() throws {
        let exportData = try sut.exportAllData()
        let json = try JSONSerialization.jsonObject(with: exportData) as! [String: Any]

        XCTAssertNotNil(json["exportDate"])
        XCTAssertNotNil(json["version"])
    }

    // MARK: - Export Specific Entities

    func test_exportMessages_returnsAllMessages() throws {
        let session = DailySession(date: Date())
        context.insert(session)

        for i in 0..<5 {
            let message = ChatMessage(content: "Message \(i)", role: .user)
            context.insert(message)
        }
        try context.save()

        let messages = try sut.exportMessages()

        XCTAssertEqual(messages.count, 5)
    }

    func test_exportJournals_returnsAllEntries() throws {
        let entry1 = JournalEntry(fullText: "Entry 1", date: Date())
        let entry2 = JournalEntry(fullText: "Entry 2", date: Date().addingTimeInterval(-86400))
        context.insert(entry1)
        context.insert(entry2)
        try context.save()

        let journals = try sut.exportJournals()

        XCTAssertEqual(journals.count, 2)
    }

    func test_exportTodos_returnsAllTodos() throws {
        let todo1 = TodoItem(title: "Todo 1")
        let todo2 = TodoItem(title: "Todo 2")
        todo2.markCompleted()
        context.insert(todo1)
        context.insert(todo2)
        try context.save()

        let todos = try sut.exportTodos()

        XCTAssertEqual(todos.count, 2)
    }

    // MARK: - Export Format

    func test_exportData_usesReadableFormat() throws {
        let entry = JournalEntry(fullText: "Test content", date: Date())
        context.insert(entry)
        try context.save()

        let exportData = try sut.exportAllData()
        let jsonString = String(data: exportData, encoding: .utf8)!

        // Should be pretty-printed (contains newlines)
        XCTAssertTrue(jsonString.contains("\n"))
    }

    func test_exportData_containsHumanReadableDates() throws {
        let entry = JournalEntry(fullText: "Test", date: Date())
        context.insert(entry)
        try context.save()

        let exportData = try sut.exportAllData()
        let jsonString = String(data: exportData, encoding: .utf8)!

        // Should contain ISO 8601 date format
        XCTAssertTrue(jsonString.contains("T"))
    }
}
