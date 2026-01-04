import Foundation

/// Extension to add startOfToday to DateClock
/// Uses the existing DateClock protocol from Core/Clock.swift
extension DateClock {
    /// The start of today (midnight)
    var startOfToday: Date {
        Calendar.current.startOfDay(for: now)
    }
}
