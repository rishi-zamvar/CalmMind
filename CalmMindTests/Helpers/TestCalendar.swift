import Foundation

/// Deterministic calendar for testing
/// Uses Gregorian calendar with fixed timezone and locale
enum TestCalendar {
    /// Fixed Gregorian calendar with UTC timezone and en_US_POSIX locale
    static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    /// Creates a fixed date for testing
    /// - Parameters:
    ///   - year: The year component
    ///   - month: The month component (1-12)
    ///   - day: The day component (1-31)
    ///   - hour: The hour component (0-23), defaults to 12
    ///   - minute: The minute component (0-59), defaults to 0
    ///   - second: The second component (0-59), defaults to 0
    /// - Returns: A Date with the specified components
    static func createDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return gregorian.date(from: components)!
    }

    /// Creates a date representing January 15, 2025 at noon UTC
    /// Useful as a stable reference date for tests
    static var referenceDate: Date {
        createDate(year: 2025, month: 1, day: 15, hour: 12)
    }

    /// Creates a date representing today at a specific hour (in UTC)
    static func today(at hour: Int) -> Date {
        let now = Date()
        let startOfDay = gregorian.startOfDay(for: now)
        return gregorian.date(byAdding: .hour, value: hour, to: startOfDay)!
    }
}
