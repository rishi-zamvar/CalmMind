import Foundation

/// Manages check-in state for morning and evening nudges
/// Uses stable identifiers based on date for notification management
final class CheckInStateMachine {

    // MARK: - Constants

    private struct Keys {
        static let morningCheckIns = "checkInStateMachine.morningCheckIns"
        static let eveningCheckIns = "checkInStateMachine.eveningCheckIns"
        static let lastInteraction = "checkInStateMachine.lastInteraction"
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    // MARK: - Dependencies

    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Check-In Recording

    /// Record that the user completed their morning check-in
    func recordMorningCheckIn(for date: Date) {
        var checkIns = morningCheckInDates()
        let key = dateKey(for: date)
        checkIns.insert(key)
        userDefaults.set(Array(checkIns), forKey: Keys.morningCheckIns)
    }

    /// Record that the user completed their evening check-in
    func recordEveningCheckIn(for date: Date) {
        var checkIns = eveningCheckInDates()
        let key = dateKey(for: date)
        checkIns.insert(key)
        userDefaults.set(Array(checkIns), forKey: Keys.eveningCheckIns)
    }

    /// Record app usage for activity tracking
    func recordAppUsage(at date: Date) {
        userDefaults.set(date, forKey: Keys.lastInteraction)
    }

    // MARK: - Check-In Status

    /// Whether the user completed their morning check-in for the given date
    func didMorningCheckIn(for date: Date) -> Bool {
        let key = dateKey(for: date)
        return morningCheckInDates().contains(key)
    }

    /// Whether the user completed their evening check-in for the given date
    func didEveningCheckIn(for date: Date) -> Bool {
        let key = dateKey(for: date)
        return eveningCheckInDates().contains(key)
    }

    /// Whether the user has recent activity on the given date
    func hasRecentActivity(for date: Date) -> Bool {
        guard let lastInteraction = lastInteractionDate() else {
            return false
        }
        return Calendar.current.isDate(lastInteraction, inSameDayAs: date)
    }

    /// Get the last interaction date
    func lastInteractionDate() -> Date? {
        return userDefaults.object(forKey: Keys.lastInteraction) as? Date
    }

    // MARK: - Stable Identifiers

    /// Generate stable morning nudge notification ID
    /// Format: nudge.morning.YYYY-MM-DD
    func morningNudgeId(for date: Date) -> String {
        return "nudge.morning.\(dateKey(for: date))"
    }

    /// Generate stable evening nudge notification ID
    /// Format: nudge.evening.YYYY-MM-DD
    func eveningNudgeId(for date: Date) -> String {
        return "nudge.evening.\(dateKey(for: date))"
    }

    /// Generate stable morning check-in ID
    /// Format: checkin.morning.YYYY-MM-DD
    func morningCheckInId(for date: Date) -> String {
        return "checkin.morning.\(dateKey(for: date))"
    }

    /// Generate stable evening check-in ID
    /// Format: checkin.evening.YYYY-MM-DD
    func eveningCheckInId(for date: Date) -> String {
        return "checkin.evening.\(dateKey(for: date))"
    }

    // MARK: - Cleanup

    /// Remove old check-in records to prevent unbounded growth
    /// Keeps only the last 7 days of records
    func cleanupOldRecords() {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        let cutoffKey = dateKey(for: cutoffDate)

        // Filter morning check-ins
        let morningFiltered = morningCheckInDates().filter { $0 >= cutoffKey }
        userDefaults.set(Array(morningFiltered), forKey: Keys.morningCheckIns)

        // Filter evening check-ins
        let eveningFiltered = eveningCheckInDates().filter { $0 >= cutoffKey }
        userDefaults.set(Array(eveningFiltered), forKey: Keys.eveningCheckIns)
    }

    // MARK: - Private Helpers

    private func dateKey(for date: Date) -> String {
        return dateFormatter.string(from: date)
    }

    private func morningCheckInDates() -> Set<String> {
        let array = userDefaults.stringArray(forKey: Keys.morningCheckIns) ?? []
        return Set(array)
    }

    private func eveningCheckInDates() -> Set<String> {
        let array = userDefaults.stringArray(forKey: Keys.eveningCheckIns) ?? []
        return Set(array)
    }
}
