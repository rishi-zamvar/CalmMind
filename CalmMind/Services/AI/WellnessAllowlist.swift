import Foundation

/// Enforces wellness suggestion allowlist in code (not just prompt)
/// Prevents off-policy advice from reaching users
/// Default deny: unknown suggestions are rejected
struct WellnessAllowlist {

    /// Keywords that indicate ALLOWED wellness suggestions
    /// Case-insensitive matching
    private let allowedKeywords: Set<String> = [
        // Breathing
        "breathing", "breath", "4-7-8", "inhale", "exhale",
        // Physical activity
        "walk", "walking", "stretch", "stretching",
        // Mindfulness
        "gratitude", "grateful", "thankful",
        "relax", "relaxation", "muscle",
        "meditation", "mindfulness", "mindful",
        // Creative outlets
        "music", "calming",
        "write", "writing", "journal",
        // Rest
        "break", "pause", "rest"
    ]

    /// Keywords that indicate DISALLOWED medical/professional advice
    /// Takes precedence over allowed keywords
    private let blockedKeywords: Set<String> = [
        // Professional referrals
        "therapist", "doctor", "professional", "psychiatrist", "counselor",
        // Medical interventions
        "medication", "medicine", "drug", "prescription", "pill",
        // Diagnostic language
        "diagnosis", "diagnosed", "disorder", "condition", "symptoms",
        // Clinical settings
        "treatment", "clinic", "hospital", "emergency",
        // Crisis resources (handled separately by Safety module)
        "crisis line", "hotline", "988", "911"
    ]

    /// Maximum suggestions to return
    private let maxSuggestions = 2

    /// Filter suggestions to only allowed wellness techniques
    /// - Parameter suggestions: Raw suggestions from LLM
    /// - Returns: Array of allowed suggestions, capped at max, preserving order
    func filter(_ suggestions: [String]) -> [String] {
        let filtered = suggestions.filter { suggestion in
            // Skip empty strings
            guard !suggestion.trimmingCharacters(in: .whitespaces).isEmpty else {
                return false
            }

            let lowercased = suggestion.lowercased()

            // Reject if contains any blocked keywords (takes precedence)
            for blocked in blockedKeywords {
                if lowercased.contains(blocked) {
                    return false
                }
            }

            // Accept only if contains at least one allowed keyword
            for allowed in allowedKeywords {
                if lowercased.contains(allowed) {
                    return true
                }
            }

            // Default deny: unknown suggestions are rejected
            return false
        }

        return Array(filtered.prefix(maxSuggestions))
    }
}
