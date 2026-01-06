import Foundation
@testable import CalmMind

/// Mock PermissionStateManager for deterministic testing
@MainActor
final class MockPermissionStateManager: ObservableObject {
    @Published var locationStatus: PermissionStatus = .notAsked
    @Published var notificationStatus: PermissionStatus = .notAsked
    @Published var locationInteracted = false
    @Published var notificationInteracted = false
    @Published var isRequestingLocation = false
    @Published var isRequestingNotifications = false

    var canProceed: Bool {
        locationInteracted && notificationInteracted
    }

    // Test hooks
    var locationRequestResult: PermissionStatus = .granted
    var notificationRequestResult: PermissionStatus = .granted
    var requestLocationCallCount = 0
    var requestNotificationsCallCount = 0

    func refreshStates() async {
        // No-op for tests - state is set directly
    }

    func requestLocation() async -> PermissionStatus {
        requestLocationCallCount += 1
        locationInteracted = true
        locationStatus = locationRequestResult
        return locationRequestResult
    }

    func requestNotifications() async -> PermissionStatus {
        requestNotificationsCallCount += 1
        notificationInteracted = true
        notificationStatus = notificationRequestResult
        return notificationRequestResult
    }
}
