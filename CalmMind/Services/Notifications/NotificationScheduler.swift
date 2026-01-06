import Foundation
import UserNotifications

/// Protocol for notification scheduler (enables testing)
protocol NotificationSchedulerProtocol {
    func scheduleMorningNudge(for date: Date) async
    func scheduleEveningNudge(for date: Date) async
    func cancelNudge(id: String)
    func cancelAllPending()
    func requestAuthorization() async -> Bool
}

/// Protocol for notification center operations (enables testing)
protocol NotificationCenterProtocol {
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeAllPendingNotificationRequests()
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func notificationSettings() async -> UNNotificationSettings
}

extension UNUserNotificationCenter: NotificationCenterProtocol {}

/// Schedules and manages notification nudges for check-ins
/// Uses stable identifiers based on date for reliable cancellation
final class NotificationScheduler: NotificationSchedulerProtocol {

    // MARK: - Dependencies

    private let notificationCenter: NotificationCenterProtocol
    private let userPreferences: UserPreferences
    private let checkInStateMachine: CheckInStateMachine

    // MARK: - Configuration

    /// Default morning nudge hour (8 AM)
    private let morningNudgeHour: Int

    /// Default evening nudge hour (9 PM)
    private let eveningNudgeHour: Int

    // MARK: - Initialization

    init(
        notificationCenter: NotificationCenterProtocol = UNUserNotificationCenter.current(),
        userPreferences: UserPreferences = UserPreferences(),
        checkInStateMachine: CheckInStateMachine = CheckInStateMachine(),
        morningNudgeHour: Int = 8,
        eveningNudgeHour: Int = 21
    ) {
        self.notificationCenter = notificationCenter
        self.userPreferences = userPreferences
        self.checkInStateMachine = checkInStateMachine
        self.morningNudgeHour = morningNudgeHour
        self.eveningNudgeHour = eveningNudgeHour
    }

    // MARK: - Authorization

    /// Request notification authorization
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Scheduling

    /// Schedule both morning and evening nudges for today
    func scheduleAllNudges() async {
        let today = Date()
        await scheduleMorningNudge(for: today)
        await scheduleEveningNudge(for: today)
    }

    // MARK: - Cancellation

    /// Cancel morning nudge for the given date
    func cancelMorningNudge(for date: Date) {
        let identifier = checkInStateMachine.morningNudgeId(for: date)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Cancel evening nudge for the given date
    func cancelEveningNudge(for date: Date) {
        let identifier = checkInStateMachine.eveningNudgeId(for: date)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Cancel all pending nudges
    func cancelAllPending() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    /// Cancel a specific nudge by ID
    func cancelNudge(id: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Scheduling Methods (Protocol Conformance)

    /// Schedule morning nudge
    func scheduleMorningNudge(for date: Date) async {
        guard userPreferences.morningNotificationsEnabled else {
            return
        }

        let identifier = checkInStateMachine.morningNudgeId(for: date)
        let content = createMorningContent()
        let trigger = createTrigger(forHour: morningNudgeHour, on: date)

        await scheduleNotification(identifier: identifier, content: content, trigger: trigger)
    }

    /// Schedule evening nudge
    func scheduleEveningNudge(for date: Date) async {
        guard userPreferences.eveningNotificationsEnabled else {
            return
        }

        let identifier = checkInStateMachine.eveningNudgeId(for: date)
        let content = createEveningContent()
        let trigger = createTrigger(forHour: eveningNudgeHour, on: date)

        await scheduleNotification(identifier: identifier, content: content, trigger: trigger)
    }

    /// Cancel nudges after user check-in
    func handleCheckIn(for date: Date, isMorning: Bool) {
        if isMorning {
            cancelMorningNudge(for: date)
            checkInStateMachine.recordMorningCheckIn(for: date)
        } else {
            cancelEveningNudge(for: date)
            checkInStateMachine.recordEveningCheckIn(for: date)
        }
    }

    // MARK: - Private Helpers

    private func scheduleNotification(
        identifier: String,
        content: UNMutableNotificationContent,
        trigger: UNCalendarNotificationTrigger
    ) async {
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            // Silently fail - notification scheduling is best-effort
        }
    }

    private func createMorningContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Good Morning"
        content.body = privacySafeBody(for: .morning)
        content.sound = .default
        return content
    }

    private func createEveningContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Evening Reflection"
        content.body = privacySafeBody(for: .evening)
        content.sound = .default
        return content
    }

    private func privacySafeBody(for type: NudgeType) -> String {
        let isMinimal = userPreferences.notificationPrivacyMode == .minimal

        switch type {
        case .morning:
            return isMinimal
                ? "Start your day mindfully."
                : "How are you feeling today? Let's check in."
        case .evening:
            return isMinimal
                ? "Take a moment to reflect."
                : "How was your day? Let's reflect together."
        }
    }

    private func createTrigger(forHour hour: Int, on date: Date) -> UNCalendarNotificationTrigger {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private enum NudgeType {
        case morning
        case evening
    }
}
