import Foundation

/// Keyword-based mood analysis (no API call needed)
/// Returns mood score 1-10 based on text sentiment
///
/// Implementation notes:
/// - Purely local analysis, no network calls
/// - Case-insensitive word matching
/// - Returns nil for empty/whitespace-only input
/// - Clamped to 1-10 range (never exceeds bounds)
struct MoodAnalyzer {

    // MARK: - Sentiment Indicators

    /// Words that indicate positive mood (each adds +1)
    private static let positiveIndicators = [
        "happy", "great", "wonderful", "excited", "grateful",
        "love", "joy", "amazing", "blessed", "peaceful", "calm",
        "proud", "hopeful", "relaxed", "content"
    ]

    /// Words that indicate negative mood (each subtracts -1)
    private static let negativeIndicators = [
        "sad", "angry", "frustrated", "anxious", "worried",
        "stressed", "overwhelmed", "tired", "exhausted", "hurt",
        "lonely", "scared", "afraid", "depressed", "hopeless"
    ]

    /// Baseline mood score (neutral)
    private static let baseline = 5

    /// Minimum mood score floor (avoid depressing scores)
    static let moodFloor = 4

    // MARK: - Analysis

    /// Analyze text and return mood score (4-10)
    /// - Parameter text: The text to analyze
    /// - Returns: Mood score 4-10 (floored at 4), or nil if text is empty/whitespace
    static func analyzeMood(from text: String) -> Int? {
        let normalized = text.lowercased()

        // Return nil for empty or whitespace-only text
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var score = baseline

        // Add points for positive words
        for word in positiveIndicators where normalized.contains(word) {
            score += 1
        }

        // Subtract points for negative words
        for word in negativeIndicators where normalized.contains(word) {
            score -= 1
        }

        // Clamp to moodFloor-10 range (floor at 4 to avoid depressing scores)
        return max(moodFloor, min(10, score))
    }
}
