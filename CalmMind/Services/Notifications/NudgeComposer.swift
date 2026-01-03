import Foundation

/// Composes personalized, privacy-safe nudge messages
/// Uses seeded randomness for deterministic template selection
final class NudgeComposer {

    // MARK: - Template Pools

    private static let morningTemplates = [
        "Good morning! How are you feeling today?",
        "Rise and shine! Ready to check in?",
        "New day, fresh start. How's your mood?",
        "Morning! Take a moment to reflect on how you're doing.",
        "Hello! Let's start the day with a quick check-in."
    ]

    private static let eveningTemplates = [
        "How was your day? Let's reflect together.",
        "Evening check-in time. How are you feeling?",
        "Time to wind down. How did today go?",
        "End of day reflection. What's on your mind?",
        "Before bed, let's take stock of the day."
    ]

    private static let morningTemplatesMinimal = [
        "Start your day mindfully.",
        "Morning check-in available.",
        "Ready when you are.",
        "A moment for yourself.",
        "Check in when ready."
    ]

    private static let eveningTemplatesMinimal = [
        "Take a moment to reflect.",
        "Evening reflection available.",
        "End your day mindfully.",
        "Time for reflection.",
        "A moment before rest."
    ]

    // MARK: - Dependencies

    private let userPreferences: UserPreferences

    // MARK: - Initialization

    init(userPreferences: UserPreferences = .shared) {
        self.userPreferences = userPreferences
    }

    // MARK: - Public API

    /// Compose a morning nudge message
    /// - Parameters:
    ///   - date: The date for seeded selection
    ///   - includeTaskCount: Optional task count to mention
    /// - Returns: Nudge content with title and body
    func composeMorningNudge(for date: Date, taskCount: Int? = nil) -> NudgeContent {
        let isMinimal = userPreferences.notificationPrivacyMode == .minimal
        let templates = isMinimal ? Self.morningTemplatesMinimal : Self.morningTemplates

        let body = selectTemplate(from: templates, for: date, prefix: "morning")

        // In detailed mode, we could add task info, but keep it simple for now
        let enhancedBody: String
        if !isMinimal, let count = taskCount, count > 0 {
            enhancedBody = "\(body) You have \(count) task\(count == 1 ? "" : "s") today."
        } else {
            enhancedBody = body
        }

        return NudgeContent(
            title: "Good Morning",
            body: enhancedBody,
            isMinimal: isMinimal
        )
    }

    /// Compose an evening nudge message
    /// - Parameters:
    ///   - date: The date for seeded selection
    ///   - moodTrend: Optional mood context (not included in minimal mode)
    /// - Returns: Nudge content with title and body
    func composeEveningNudge(for date: Date, moodTrend: MoodTrend? = nil) -> NudgeContent {
        let isMinimal = userPreferences.notificationPrivacyMode == .minimal
        let templates = isMinimal ? Self.eveningTemplatesMinimal : Self.eveningTemplates

        let body = selectTemplate(from: templates, for: date, prefix: "evening")

        // In detailed mode, we could add mood context
        let enhancedBody: String
        if !isMinimal, let trend = moodTrend, trend == .declining {
            enhancedBody = "\(body) We noticed today might have been tough."
        } else {
            enhancedBody = body
        }

        return NudgeContent(
            title: "Evening Reflection",
            body: enhancedBody,
            isMinimal: isMinimal
        )
    }

    /// Compose a gentle nudge for after negative days
    func composeGentleNudge(for date: Date) -> NudgeContent {
        let isMinimal = userPreferences.notificationPrivacyMode == .minimal

        let body = isMinimal
            ? "We're here when you're ready."
            : "No pressure, but we're here if you want to talk."

        return NudgeContent(
            title: "Thinking of You",
            body: body,
            isMinimal: isMinimal
        )
    }

    // MARK: - Template Selection

    /// Select a template using seeded randomness
    /// Same date + same device = same template (deterministic)
    private func selectTemplate(from templates: [String], for date: Date, prefix: String) -> String {
        let seed = generateSeed(for: date, prefix: prefix)
        let index = abs(seed.hashValue) % templates.count
        return templates[index]
    }

    /// Generate a deterministic seed for template selection
    /// Seed = dateKey + deviceSalt + prefix
    private func generateSeed(for date: Date, prefix: String) -> String {
        let dateKey = formatDateKey(date)
        let deviceSalt = userPreferences.deviceSalt
        return "\(dateKey)-\(deviceSalt)-\(prefix)"
    }

    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

/// Nudge notification content
struct NudgeContent {
    let title: String
    let body: String
    let isMinimal: Bool
}

/// Mood trend indicator
enum MoodTrend {
    case improving
    case stable
    case declining
}
