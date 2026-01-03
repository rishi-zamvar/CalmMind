import XCTest
import SwiftData
@testable import CalmMind

final class MemoryItemTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: MemoryItem.self, configurations: config)
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Creation

    func test_createMemory_withContent() {
        let memory = MemoryItem(content: "User likes hiking")

        XCTAssertEqual(memory.content, "User likes hiking")
    }

    func test_createMemory_setsDateNoted() {
        let before = Date()
        let memory = MemoryItem(content: "Test")
        let after = Date()

        XCTAssertGreaterThanOrEqual(memory.dateNoted, before)
        XCTAssertLessThanOrEqual(memory.dateNoted, after)
    }

    func test_createMemory_embeddingDefaultsToNil() {
        let memory = MemoryItem(content: "Test")

        XCTAssertNil(memory.embedding)
    }

    // MARK: - Usage Tracking

    func test_timesReferenced_defaultsToZero() {
        let memory = MemoryItem(content: "Test")

        XCTAssertEqual(memory.timesReferenced, 0)
    }

    func test_incrementTimesReferenced() {
        let memory = MemoryItem(content: "Test")

        memory.incrementReferenceCount()
        memory.incrementReferenceCount()

        XCTAssertEqual(memory.timesReferenced, 2)
    }

    func test_lastReferencedDate_updates() {
        let memory = MemoryItem(content: "Test")
        let beforeReference = memory.lastReferencedAt

        // Small delay to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)
        memory.incrementReferenceCount()

        if let before = beforeReference {
            XCTAssertGreaterThan(memory.lastReferencedAt!, before)
        } else {
            XCTAssertNotNil(memory.lastReferencedAt)
        }
    }

    // MARK: - Private Flag

    func test_isPrivate_defaultsFalse() {
        let memory = MemoryItem(content: "Test")

        XCTAssertFalse(memory.isPrivate)
    }

    func test_privateMemories_canBeMarked() {
        let memory = MemoryItem(content: "Secret", isPrivate: true)

        XCTAssertTrue(memory.isPrivate)
    }

    // MARK: - Embedding

    func test_embedding_canBeSet() {
        let memory = MemoryItem(content: "Test")
        let embedding: [Float] = [0.1, 0.2, 0.3, 0.4]

        memory.embedding = embedding

        XCTAssertEqual(memory.embedding, embedding)
    }

    // MARK: - Summary

    func test_summary_defaultsToNil() {
        let memory = MemoryItem(content: "Test")

        XCTAssertNil(memory.summary)
    }

    func test_summary_canBeSet() {
        let memory = MemoryItem(content: "Long content about user preferences...")

        memory.summary = "Likes coffee"

        XCTAssertEqual(memory.summary, "Likes coffee")
    }

    // MARK: - Persistence

    func test_memory_persistsToSwiftData() throws {
        let memory = MemoryItem(content: "Persisted memory")
        context.insert(memory)
        try context.save()

        let descriptor = FetchDescriptor<MemoryItem>()
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.content, "Persisted memory")
    }

    // MARK: - Queries

    func test_fetchNonPrivateMemories() throws {
        let memory1 = MemoryItem(content: "Public 1")
        let memory2 = MemoryItem(content: "Private", isPrivate: true)
        let memory3 = MemoryItem(content: "Public 2")

        context.insert(memory1)
        context.insert(memory2)
        context.insert(memory3)
        try context.save()

        let descriptor = FetchDescriptor<MemoryItem>(
            predicate: #Predicate { !$0.isPrivate }
        )
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 2)
    }
}
