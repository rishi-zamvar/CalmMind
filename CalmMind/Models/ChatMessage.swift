import Foundation
import SwiftData

/// Role of a chat message
enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

/// Send status for optimistic UI
enum SendStatus: String, Codable {
    case sending   // Optimistic, not yet persisted
    case sent      // Successfully persisted
    case failed    // Send failed, needs retry
}

/// A single message in a chat conversation
@Model
final class ChatMessage {

    // MARK: - Properties

    /// Unique identifier
    @Attribute(.unique)
    var id: UUID

    /// Client-generated ID for optimistic UI deduplication
    /// Survives persistence and is used for reconciliation
    var clientMessageId: UUID

    /// The message content
    var content: String

    /// Role of the sender (user, assistant, system)
    var roleRaw: String

    /// When the message was created
    var timestamp: Date

    /// Whether this message was injected as context (not user-initiated)
    var isContextInjection: Bool

    /// Send status for optimistic UI (sending, sent, failed)
    var sendStatusRaw: String

    /// The session this message belongs to
    @Relationship(inverse: \DailySession.messages)
    var session: DailySession?

    // MARK: - Computed Properties

    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    var sendStatus: SendStatus {
        get { SendStatus(rawValue: sendStatusRaw) ?? .sent }
        set { sendStatusRaw = newValue.rawValue }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        clientMessageId: UUID = UUID(),
        content: String,
        role: MessageRole,
        timestamp: Date = Date(),
        isContextInjection: Bool = false,
        sendStatus: SendStatus = .sent,
        session: DailySession? = nil
    ) {
        self.id = id
        self.clientMessageId = clientMessageId
        self.content = content
        self.roleRaw = role.rawValue
        self.timestamp = timestamp
        self.isContextInjection = isContextInjection
        self.sendStatusRaw = sendStatus.rawValue
        self.session = session
    }
}
