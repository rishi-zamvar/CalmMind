import Foundation

/// Protocol for clock abstraction to enable testable date handling
/// Use this instead of Date() directly to allow MockDateClock injection in tests
///
/// Note: Named `DateClock` to avoid conflict with Swift's stdlib Clock protocol
protocol DateClock: Sendable {
    /// Current date/time
    var now: Date { get }
}

/// System clock using the actual current time
final class SystemClock: DateClock, Sendable {
    init() {}

    var now: Date { Date() }
}

/// Mock clock for testing with a controllable fixed date
final class MockClock: DateClock, @unchecked Sendable {
    private var _fixedDate: Date
    private let lock = NSLock()

    init(fixedDate: Date = Date()) {
        self._fixedDate = fixedDate
    }

    var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return _fixedDate
    }

    /// Update the fixed date (for tests that need to simulate time passing)
    func setDate(_ date: Date) {
        lock.lock()
        defer { lock.unlock() }
        _fixedDate = date
    }

    /// Advance time by a given interval
    func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        _fixedDate = _fixedDate.addingTimeInterval(interval)
    }
}

/// Type alias for backwards compatibility
typealias Clock = DateClock
