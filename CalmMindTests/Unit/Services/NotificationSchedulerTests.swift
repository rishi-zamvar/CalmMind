import XCTest
import UserNotifications
@testable import CalmMind

final class NotificationSchedulerTests: XCTestCase {

    var sut: NotificationScheduler!
    var mockNotificationCenter: MockUNUserNotificationCenter!
    var userPreferences: UserPreferences!
    var checkInStateMachine: CheckInStateMachine!
    var testUserDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testUserDefaults = UserDefaults(suiteName: "com.calmmind.tests.scheduler.\(UUID().uuidString)")!
        mockNotificationCenter = MockUNUserNotificationCenter()
        userPreferences = UserPreferences(defaults: testUserDefaults)
        checkInStateMachine = CheckInStateMachine(userDefaults: testUserDefaults)

        sut = NotificationScheduler(
            notificationCenter: mockNotificationCenter,
            userPreferences: userPreferences,
            checkInStateMachine: checkInStateMachine
        )
    }

    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: testUserDefaults.description)
        sut = nil
        mockNotificationCenter = nil
        userPreferences = nil
        checkInStateMachine = nil
        testUserDefaults = nil
        super.tearDown()
    }

    // MARK: - Basic Scheduling

    func test_schedulesMorningNudge() async throws {
        userPreferences.morningNotificationsEnabled = true

        await sut.scheduleMorningNudge(for: Date())

        XCTAssertEqual(mockNotificationCenter.pendingRequests.count, 1)
        let request = mockNotificationCenter.pendingRequests.first!
        XCTAssertTrue(request.identifier.contains("nudge.morning"))
    }

    func test_schedulesEveningNudge() async throws {
        userPreferences.eveningNotificationsEnabled = true

        await sut.scheduleEveningNudge(for: Date())

        XCTAssertEqual(mockNotificationCenter.pendingRequests.count, 1)
        let request = mockNotificationCenter.pendingRequests.first!
        XCTAssertTrue(request.identifier.contains("nudge.evening"))
    }

    func test_respectsUserPreferences_morningDisabled() async throws {
        userPreferences.morningNotificationsEnabled = false

        await sut.scheduleMorningNudge(for: Date())

        XCTAssertEqual(mockNotificationCenter.pendingRequests.count, 0)
    }

    func test_respectsUserPreferences_eveningDisabled() async throws {
        userPreferences.eveningNotificationsEnabled = false

        await sut.scheduleEveningNudge(for: Date())

        XCTAssertEqual(mockNotificationCenter.pendingRequests.count, 0)
    }

    // MARK: - Stable Identifiers

    func test_usesStableNotificationId_morning() async throws {
        userPreferences.morningNotificationsEnabled = true
        let date = createDate(year: 2025, month: 1, day: 2)

        await sut.scheduleMorningNudge(for: date)

        let request = mockNotificationCenter.pendingRequests.first!
        XCTAssertEqual(request.identifier, "nudge.morning.2025-01-02")
    }

    func test_usesStableNotificationId_evening() async throws {
        userPreferences.eveningNotificationsEnabled = true
        let date = createDate(year: 2025, month: 1, day: 2)

        await sut.scheduleEveningNudge(for: date)

        let request = mockNotificationCenter.pendingRequests.first!
        XCTAssertEqual(request.identifier, "nudge.evening.2025-01-02")
    }

    // MARK: - Anti-Duplicate Guard

    func test_doesNotScheduleDuplicateNudges_sameDay() async throws {
        userPreferences.morningNotificationsEnabled = true
        let today = Date()

        await sut.scheduleMorningNudge(for: today)
        await sut.scheduleMorningNudge(for: today)

        // Should only have one request (same identifier overwrites)
        XCTAssertEqual(mockNotificationCenter.pendingRequests.count, 1)
    }

    func test_allowsReschedule_nextDay() async throws {
        userPreferences.morningNotificationsEnabled = true
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        await sut.scheduleMorningNudge(for: today)
        await sut.scheduleMorningNudge(for: tomorrow)

        // Should have two requests with different identifiers
        XCTAssertEqual(mockNotificationCenter.pendingRequests.count, 2)
    }

    // MARK: - Cancellation

    func test_cancelMorningNudge_removesFromPending() async throws {
        userPreferences.morningNotificationsEnabled = true
        let date = createDate(year: 2025, month: 1, day: 2)

        await sut.scheduleMorningNudge(for: date)
        XCTAssertEqual(mockNotificationCenter.pendingRequests.count, 1)

        sut.cancelMorningNudge(for: date)
        XCTAssertEqual(mockNotificationCenter.removedIdentifiers.count, 1)
        XCTAssertEqual(mockNotificationCenter.removedIdentifiers.first, "nudge.morning.2025-01-02")
    }

    func test_cancelEveningNudge_removesFromPending() async throws {
        userPreferences.eveningNotificationsEnabled = true
        let date = createDate(year: 2025, month: 1, day: 2)

        await sut.scheduleEveningNudge(for: date)
        XCTAssertEqual(mockNotificationCenter.pendingRequests.count, 1)

        sut.cancelEveningNudge(for: date)
        XCTAssertEqual(mockNotificationCenter.removedIdentifiers.count, 1)
        XCTAssertEqual(mockNotificationCenter.removedIdentifiers.first, "nudge.evening.2025-01-02")
    }

    func test_cancelAllPending_removesAll() async throws {
        userPreferences.morningNotificationsEnabled = true
        userPreferences.eveningNotificationsEnabled = true

        await sut.scheduleMorningNudge(for: Date())
        await sut.scheduleEveningNudge(for: Date())
        XCTAssertEqual(mockNotificationCenter.pendingRequests.count, 2)

        sut.cancelAllPending()
        XCTAssertTrue(mockNotificationCenter.removeAllCalled)
    }

    // MARK: - Helpers

    private func createDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }
}

// MARK: - Mock UNUserNotificationCenter

final class MockUNUserNotificationCenter: NotificationCenterProtocol {
    var pendingRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var removeAllCalled = false
    var authorizationStatus: UNAuthorizationStatus = .authorized

    func add(_ request: UNNotificationRequest) async throws {
        // Remove any existing request with same identifier
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func removeAllPendingNotificationRequests() {
        removeAllCalled = true
        pendingRequests.removeAll()
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        return authorizationStatus == .authorized
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        return pendingRequests
    }

    func notificationSettings() async -> UNNotificationSettings {
        // Create mock settings using a test-specific approach
        // UNNotificationSettings cannot be directly instantiated, so we use the current center
        return await UNUserNotificationCenter.current().notificationSettings()
    }
}
