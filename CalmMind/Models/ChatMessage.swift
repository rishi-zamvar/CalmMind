import Foundation
import SwiftData

/// Role of a chat message
enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

/// A single message in a chat conversation
@Model
final class ChatMessage {

    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique)
    var id: UUID

    /// The message content
    var content: String

    /// Role of the sender (user, assistant, system)
    var roleRaw: String

    /// When the message was created
    var timestamp: Date

    /// Whether this message was injected as context (not user-initiated)
    var isContextInjection: Bool

    /// The session this message belongs to
    @Relationship(inverse: \DailySession.messages)
    var session: DailySession?

    // MARK: - Computed Properties

    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        content: String,
        role: MessageRole,
        timestamp: Date = Date(),
        isContextInjection: Bool = false,
        session: DailySession? = nil
    ) {
        self.id = id
        self.content = content
        self.roleRaw = role.rawValue
        self.timestamp = timestamp
        self.isContextInjection = isContextInjection
        self.session = session
    }
}
