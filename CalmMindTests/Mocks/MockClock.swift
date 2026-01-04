import Foundation
@testable import CalmMind

// Note: The main MockClock is defined in CalmMind/Core/Clock.swift
// This file provides test-specific extensions for the MockClock

extension MockClock {
    /// Start of today using the fixed test calendar
    var startOfTodayForTesting: Date {
        TestCalendar.gregorian.startOfDay(for: now)
    }
}
