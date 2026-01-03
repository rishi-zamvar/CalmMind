import Foundation

/// Result of message validation
struct MessageValidationResult {
    let original: String
    let sanitized: String
    let isValid: Bool
    let wasTruncated: Bool
    let error: MessageValidationError?
}

/// Errors that can occur during message validation
enum MessageValidationError: Error, Equatable {
    case empty
}

/// Validates and sanitizes user chat messages
struct MessageValidator {

    /// Maximum allowed message length
    static let maxLength = 2000

    /// Validate and sanitize a message
    func validate(_ message: String) -> MessageValidationResult {
        // Sanitize first
        var sanitized = message

        // Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        // Normalize newlines (convert \r\n and \r to \n)
        sanitized = sanitized.replacingOccurrences(of: "\r\n", with: "\n")
        sanitized = sanitized.replacingOccurrences(of: "\r", with: "\n")

        // Collapse multiple newlines to max 2
        while sanitized.contains("\n\n\n") {
            sanitized = sanitized.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        // Check if empty
        if sanitized.isEmpty {
            return MessageValidationResult(
                original: message,
                sanitized: sanitized,
                isValid: false,
                wasTruncated: false,
                error: .empty
            )
        }

        // Truncate if needed
        let wasTruncated = sanitized.count > Self.maxLength
        if wasTruncated {
            sanitized = String(sanitized.prefix(Self.maxLength))
        }

        return MessageValidationResult(
            original: message,
            sanitized: sanitized,
            isValid: true,
            wasTruncated: wasTruncated,
            error: nil
        )
    }
}
