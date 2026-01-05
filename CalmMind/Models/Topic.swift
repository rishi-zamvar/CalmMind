import Foundation
import SwiftData
import CryptoKit

/// A topic representing a person, event, or place that can be semantically searched
@Model
final class Topic {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var nameHash: String  // SHA256 of canonical name for fast lookup
    var topicTypeRaw: String
    var embeddingData: Data?  // Packed floats for SwiftData compatibility
    var createdAt: Date = Date()
    var lastMentionedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Fact.topic)
    var facts: [Fact] = []

    // MARK: - Computed Properties

    /// Topic type as enum (defaults to .person if raw value invalid)
    var topicType: TopicType {
        get { TopicType(rawValue: topicTypeRaw) ?? .person }
        set { topicTypeRaw = newValue.rawValue }
    }

    /// Embedding as float array (nil if no embedding stored)
    var embedding: [Float]? {
        get { embeddingData.flatMap { Self.unpackEmbedding($0) } }
        set { embeddingData = newValue.flatMap { Self.packEmbedding($0) } }
    }

    // MARK: - Initialization

    init(name: String, type: TopicType) {
        self.name = name
        self.nameHash = Self.computeNameHash(name)
        self.topicTypeRaw = type.rawValue
    }

    // MARK: - Canonical Name Handling

    /// Canonical form: trimmed + lowercased + collapsed whitespace
    static func canonicalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Compute SHA256 hash of canonical name for fast lookup
    static func computeNameHash(_ name: String) -> String {
        let canonical = canonicalize(name)
        let data = Data(canonical.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Embedding Pack/Unpack

    /// Pack float array into Data for SwiftData storage
    static func packEmbedding(_ floats: [Float]) -> Data {
        floats.withUnsafeBytes { Data($0) }
    }

    /// Unpack Data back into float array
    static func unpackEmbedding(_ data: Data) -> [Float] {
        data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }
}
