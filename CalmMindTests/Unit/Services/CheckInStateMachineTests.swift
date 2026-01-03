import XCTest
@testable import CalmMind

final class CheckInStateMachineTests: XCTestCase {

    var sut: CheckInStateMachine!
    var mockUserDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        mockUserDefaults = UserDefaults(suiteName: "com.calmmind.tests.checkin.\(UUID().uuidString)")!
        sut = CheckInStateMachine(userDefaults: mockUserDefaults)
    }

    override func tearDown() {
        mockUserDefaults.removePersistentDomain(forName: mockUserDefaults.description)
        sut = nil
        mockUserDefaults = nil
        super.tearDown()
    }

    // MARK: - Basic State

    func test_initialState_notCheckedIn() {
        XCTAssertFalse(sut.didMorningCheckIn(for: Date()))
        XCTAssertFalse(sut.didEveningCheckIn(for: Date()))
    }

    func test_morningCheckIn_recorded() {
        let today = Date()

        sut.recordMorningCheckIn(for: today)

        XCTAssertTrue(sut.didMorningCheckIn(for: today))
        XCTAssertFalse(sut.didEveningCheckIn(for: today))
    }

    func test_eveningCheckIn_recorded() {
        let today = Date()

        sut.recordEveningCheckIn(for: today)

        XCTAssertTrue(sut.didEveningCheckIn(for: today))
        XCTAssertFalse(sut.didMorningCheckIn(for: today))
    }

    func test_resetsAtMidnight() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        sut.recordMorningCheckIn(for: yesterday)
        sut.recordEveningCheckIn(for: yesterday)

        // Yesterday's check-ins don't apply to today
        XCTAssertFalse(sut.didMorningCheckIn(for: today))
        XCTAssertFalse(sut.didEveningCheckIn(for: today))

        // Yesterday's check-ins still exist
        XCTAssertTrue(sut.didMorningCheckIn(for: yesterday))
        XCTAssertTrue(sut.didEveningCheckIn(for: yesterday))
    }

    func test_checkedIn_recentlyUsedApp() {
        let today = Date()

        sut.recordAppUsage(at: today)

        XCTAssertTrue(sut.hasRecentActivity(for: today))
    }

    // MARK: - Stable Identifiers (CRITICAL)

    func test_morningNotificationId_format() {
        let date = createDate(year: 2025, month: 1, day: 2)
        let expectedId = "nudge.morning.2025-01-02"

        XCTAssertEqual(sut.morningNudgeId(for: date), expectedId)
    }

    func test_eveningNotificationId_format() {
        let date = createDate(year: 2025, month: 1, day: 2)
        let expectedId = "nudge.evening.2025-01-02"

        XCTAssertEqual(sut.eveningNudgeId(for: date), expectedId)
    }

    func test_checkInId_format_morning() {
        let date = createDate(year: 2025, month: 1, day: 2)
        let expectedId = "checkin.morning.2025-01-02"

        XCTAssertEqual(sut.morningCheckInId(for: date), expectedId)
    }

    func test_checkInId_format_evening() {
        let date = createDate(year: 2025, month: 1, day: 2)
        let expectedId = "checkin.evening.2025-01-02"

        XCTAssertEqual(sut.eveningCheckInId(for: date), expectedId)
    }

    func test_identifiersAreIdempotent_sameDay() {
        let date = Date()

        let morning1 = sut.morningNudgeId(for: date)
        let morning2 = sut.morningNudgeId(for: date)
        let evening1 = sut.eveningNudgeId(for: date)
        let evening2 = sut.eveningNudgeId(for: date)

        XCTAssertEqual(morning1, morning2)
        XCTAssertEqual(evening1, evening2)
    }

    // MARK: - Date Key Formatting

    func test_dateKey_usesCorrectFormat() {
        let date = createDate(year: 2025, month: 12, day: 31)

        XCTAssertEqual(sut.morningNudgeId(for: date), "nudge.morning.2025-12-31")
    }

    func test_dateKey_padsSingleDigits() {
        let date = createDate(year: 2025, month: 1, day: 5)

        XCTAssertEqual(sut.morningNudgeId(for: date), "nudge.morning.2025-01-05")
    }

    // MARK: - Last Interaction Tracking

    func test_lastInteraction_tracksTime() {
        let now = Date()

        sut.recordAppUsage(at: now)

        let lastInteraction = sut.lastInteractionDate()
        XCTAssertNotNil(lastInteraction)
        XCTAssertEqual(lastInteraction!.timeIntervalSinceReferenceDate, now.timeIntervalSinceReferenceDate, accuracy: 1)
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
