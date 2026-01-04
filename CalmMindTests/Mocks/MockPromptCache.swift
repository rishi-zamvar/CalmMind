import Foundation
@testable import CalmMind

/// Mock prompt cache for testing
final class MockPromptCache: PromptCacheProtocol {
    var storage: [Date: String] = [:]
    var getCalled = false
    var getCallCount = 0
    var setCalled = false
    var setCallCount = 0
    var clearCalled = false
    var lastGetDate: Date?
    var lastSetDate: Date?

    func get(for date: Date) -> String? {
        getCalled = true
        getCallCount += 1
        let key = TestCalendar.gregorian.startOfDay(for: date)
        lastGetDate = key
        return storage[key]
    }

    func set(_ prompt: String, for date: Date) {
        setCalled = true
        setCallCount += 1
        let key = TestCalendar.gregorian.startOfDay(for: date)
        lastSetDate = key
        storage[key] = prompt
    }

    func clear() {
        clearCalled = true
        storage.removeAll()
    }

    func reset() {
        storage.removeAll()
        getCalled = false
        getCallCount = 0
        setCalled = false
        setCallCount = 0
        clearCalled = false
        lastGetDate = nil
        lastSetDate = nil
    }
}
