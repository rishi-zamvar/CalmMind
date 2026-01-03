import Foundation

/// Result of journal validation
struct JournalValidationResult {
    let original: String
    let sanitized: String
    let isValid: Bool
    let wasTruncated: Bool
    let error: JournalValidationError?
}

/// Errors that can occur during journal validation
enum JournalValidationError: Error, Equatable {
    case empty
}

/// Validates and constrains journal entries
struct JournalConstraints {

    /// Maximum allowed journal entry length
    static let maxLength = 5000

    /// Validate and sanitize a journal entry
    func validate(_ entry: String) -> JournalValidationResult {
        // Sanitize
        var sanitized = entry.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if empty
        if sanitized.isEmpty {
            return JournalValidationResult(
                original: entry,
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

        return JournalValidationResult(
            original: entry,
            sanitized: sanitized,
            isValid: true,
            wasTruncated: wasTruncated,
            error: nil
        )
    }
}
