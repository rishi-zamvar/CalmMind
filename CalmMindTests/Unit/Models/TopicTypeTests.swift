import XCTest
@testable import CalmMind

/// Tests for TopicType enum - extensible topic categorization
final class TopicTypeTests: XCTestCase {

    // MARK: - Raw Values

    func test_topicType_person_rawValue() {
        XCTAssertEqual(TopicType.person.rawValue, "person")
    }

    func test_topicType_event_rawValue() {
        XCTAssertEqual(TopicType.event.rawValue, "event")
    }

    func test_topicType_place_rawValue() {
        XCTAssertEqual(TopicType.place.rawValue, "place")
    }

    // MARK: - CaseIterable

    func test_topicType_allCases_containsThreeTypes() {
        XCTAssertEqual(TopicType.allCases.count, 3)
        XCTAssertTrue(TopicType.allCases.contains(.person))
        XCTAssertTrue(TopicType.allCases.contains(.event))
        XCTAssertTrue(TopicType.allCases.contains(.place))
    }

    func test_topicType_isExtensible() {
        // CaseIterable allows iteration - new cases auto-added
        var typeNames: [String] = []
        for type in TopicType.allCases {
            typeNames.append(type.rawValue)
        }
        XCTAssertEqual(typeNames.sorted(), ["event", "person", "place"])
    }

    // MARK: - Codable

    func test_topicType_encodesToRawValue() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(TopicType.person)
        let string = String(data: data, encoding: .utf8)
        XCTAssertEqual(string, "\"person\"")
    }

    func test_topicType_decodesFromRawValue() throws {
        let decoder = JSONDecoder()
        let data = "\"event\"".data(using: .utf8)!
        let type = try decoder.decode(TopicType.self, from: data)
        XCTAssertEqual(type, .event)
    }

    func test_topicType_invalidRawValue_throwsDecodingError() {
        let decoder = JSONDecoder()
        let data = "\"invalid\"".data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(TopicType.self, from: data))
    }

    // MARK: - Equatable

    func test_topicType_equatable() {
        XCTAssertEqual(TopicType.person, TopicType.person)
        XCTAssertNotEqual(TopicType.person, TopicType.event)
    }

    // MARK: - Hashable

    func test_topicType_hashable() {
        var set = Set<TopicType>()
        set.insert(.person)
        set.insert(.event)
        set.insert(.person) // Duplicate
        XCTAssertEqual(set.count, 2)
    }
}
