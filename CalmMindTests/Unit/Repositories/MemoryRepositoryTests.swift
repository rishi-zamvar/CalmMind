import XCTest
import SwiftData
@testable import CalmMind

final class MemoryRepositoryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var sut: MemoryRepository!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: MemoryItem.self, configurations: config)
        context = ModelContext(container)
        sut = MemoryRepository(context: context)
    }

    override func tearDown() {
        sut = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Create

    func test_createMemory_persistsToStore() throws {
        let memory = try sut.create(content: "User likes hiking")

        XCTAssertNotNil(memory.id)
        XCTAssertEqual(memory.content, "User likes hiking")
    }

    func test_createMemory_defaultsToNotPrivate() throws {
        let memory = try sut.create(content: "General fact")

        XCTAssertFalse(memory.isPrivate)
    }

    func test_createMemory_canBeMarkedPrivate() throws {
        let memory = try sut.create(content: "Secret", isPrivate: true)

        XCTAssertTrue(memory.isPrivate)
    }

    // MARK: - Update Embedding

    func test_updateEmbedding_afterCreation() throws {
        let memory = try sut.create(content: "Test memory")
        XCTAssertNil(memory.embedding)

        let embedding: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        try sut.updateEmbedding(for: memory, embedding: embedding)

        XCTAssertNotNil(memory.embedding)
        XCTAssertEqual(memory.embedding, embedding)
    }

    // MARK: - Fetch

    func test_fetchNonPrivateMemories() throws {
        let _ = try sut.create(content: "Public 1", isPrivate: false)
        let _ = try sut.create(content: "Private", isPrivate: true)
        let _ = try sut.create(content: "Public 2", isPrivate: false)

        let nonPrivate = try sut.fetchNonPrivate()

        XCTAssertEqual(nonPrivate.count, 2)
        XCTAssertFalse(nonPrivate.contains { $0.content == "Private" })
    }

    func test_fetchAllMemories() throws {
        let _ = try sut.create(content: "Memory 1")
        let _ = try sut.create(content: "Memory 2")
        let _ = try sut.create(content: "Memory 3")

        let all = try sut.fetchAll()

        XCTAssertEqual(all.count, 3)
    }

    // MARK: - Reference Count

    func test_incrementReferenceCount() throws {
        let memory = try sut.create(content: "Referenced memory")
        XCTAssertEqual(memory.timesReferenced, 0)

        try sut.incrementReferenceCount(for: memory)

        XCTAssertEqual(memory.timesReferenced, 1)
        XCTAssertNotNil(memory.lastReferencedAt)
    }

    func test_incrementReferenceCount_multipleTimesUpdates() throws {
        let memory = try sut.create(content: "Multi reference")

        try sut.incrementReferenceCount(for: memory)
        try sut.incrementReferenceCount(for: memory)
        try sut.incrementReferenceCount(for: memory)

        XCTAssertEqual(memory.timesReferenced, 3)
    }

    // MARK: - Delete

    func test_deleteMemory_removesFromStore() throws {
        let memory = try sut.create(content: "Delete me")

        try sut.delete(memory)

        let all = try sut.fetchAll()
        XCTAssertEqual(all.count, 0)
    }

    // MARK: - Update Privacy

    func test_updatePrivacy_canMakePrivate() throws {
        let memory = try sut.create(content: "Was public", isPrivate: false)

        try sut.updatePrivacy(for: memory, isPrivate: true)

        XCTAssertTrue(memory.isPrivate)
    }

    func test_updatePrivacy_canMakePublic() throws {
        let memory = try sut.create(content: "Was private", isPrivate: true)

        try sut.updatePrivacy(for: memory, isPrivate: false)

        XCTAssertFalse(memory.isPrivate)
    }
}
