import Foundation

/// Topic categories - designed for easy extension
/// Add new cases here; CaseIterable auto-updates iteration
enum TopicType: String, Codable, CaseIterable, Sendable {
    case person
    case event
    case place
    // Future: case organization, case concept, etc.
}
