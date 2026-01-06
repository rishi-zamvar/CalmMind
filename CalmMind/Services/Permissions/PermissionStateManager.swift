import Foundation
import CoreLocation
import UserNotifications

/// Canonical permission state - UI must not invent its own truth
enum PermissionStatus: String, Codable, Equatable {
    case notAsked
    case granted
    case denied
}

// NotificationCenterProtocol is defined in NotificationScheduler.swift

/// Single source of truth for permission states
/// Persists interaction tracking to survive app restarts
///
/// INVARIANTS:
/// - Permission state is read from OS/LocationService, never invented
/// - Interaction tracking is persisted synchronously (survives relaunch)
/// - Only ONE underlying request occurs even with rapid taps (idempotent)
/// - canProceed requires BOTH permissions interacted (not necessarily granted)
@MainActor
final class PermissionStateManager: ObservableObject {

    // MARK: - Dependencies

    private let locationService: LocationServiceProtocol
    private let userPreferences: UserPreferences
    private let notificationCenter: NotificationCenterProtocol

    // MARK: - Published State

    /// Current location permission status
    @Published private(set) var locationStatus: PermissionStatus = .notAsked

    /// Current notification permission status
    @Published private(set) var notificationStatus: PermissionStatus = .notAsked

    /// Whether user has interacted with location permission (persisted)
    @Published private(set) var locationInteracted: Bool

    /// Whether user has interacted with notification permission (persisted)
    @Published private(set) var notificationInteracted: Bool

    /// Whether location permission request is in progress
    @Published private(set) var isRequestingLocation = false

    /// Whether notification permission request is in progress
    @Published private(set) var isRequestingNotifications = false

    // MARK: - Computed Properties

    /// Can proceed with onboarding - requires BOTH permissions interacted OR already granted
    /// If OS already has permission granted, user doesn't need to tap "Enable"
    var canProceed: Bool {
        let locationOK = locationInteracted || locationStatus == .granted
        let notificationOK = notificationInteracted || notificationStatus == .granted
        return locationOK && notificationOK
    }

    // MARK: - Initialization

    init(
        locationService: LocationServiceProtocol,
        userPreferences: UserPreferences,
        notificationCenter: NotificationCenterProtocol = UNUserNotificationCenter.current()
    ) {
        self.locationService = locationService
        self.userPreferences = userPreferences
        self.notificationCenter = notificationCenter

        // Load persisted interaction state (synchronous - survives relaunch)
        self.locationInteracted = userPreferences.locationPermissionInteracted
        self.notificationInteracted = userPreferences.notificationPermissionInteracted

        // Sync with current OS states
        Task { await refreshStates() }
    }

    // MARK: - Public Methods

    /// Refresh from OS state - call on appear and when returning from Settings
    func refreshStates() async {
        // Location
        switch locationService.permissionState {
        case .authorized:
            locationStatus = .granted
            if !locationInteracted {
                markLocationInteracted()
            }
        case .denied:
            locationStatus = .denied
            if !locationInteracted {
                markLocationInteracted()
            }
        case .notDetermined, .privacyMode:
            locationStatus = .notAsked
        }

        // Notifications
        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationStatus = .granted
            if !notificationInteracted {
                markNotificationInteracted()
            }
        case .denied:
            notificationStatus = .denied
            if !notificationInteracted {
                markNotificationInteracted()
            }
        case .notDetermined:
            notificationStatus = .notAsked
        @unknown default:
            notificationStatus = .notAsked
        }
    }

    /// Request location permission - bounded, idempotent
    /// Returns: .granted, .denied, or .notAsked (if privacy mode)
    func requestLocation() async -> PermissionStatus {
        // Double-tap protection: if already requesting, return current status
        guard !isRequestingLocation else { return locationStatus }

        // If already decided (granted or denied), mark interacted and return
        guard locationStatus == .notAsked else {
            markLocationInteracted()
            return locationStatus
        }

        isRequestingLocation = true
        defer { isRequestingLocation = false }

        // Request from OS via LocationService
        _ = await locationService.requestPermissionIfNeeded()
        markLocationInteracted()
        await refreshStates()
        return locationStatus
    }

    /// Request notification permission - bounded, idempotent
    /// Returns: .granted, .denied, or .notAsked (if error)
    func requestNotifications() async -> PermissionStatus {
        // Double-tap protection: if already requesting, return current status
        guard !isRequestingNotifications else { return notificationStatus }

        // If already decided (granted or denied), mark interacted and return
        guard notificationStatus == .notAsked else {
            markNotificationInteracted()
            return notificationStatus
        }

        isRequestingNotifications = true
        defer { isRequestingNotifications = false }

        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await notificationCenter.requestAuthorization(options: options)
            notificationStatus = granted ? .granted : .denied
        } catch {
            notificationStatus = .denied
        }
        markNotificationInteracted()
        return notificationStatus
    }

    // MARK: - Private Methods

    private func markLocationInteracted() {
        guard !locationInteracted else { return }
        locationInteracted = true
        userPreferences.locationPermissionInteracted = true
    }

    private func markNotificationInteracted() {
        guard !notificationInteracted else { return }
        notificationInteracted = true
        userPreferences.notificationPermissionInteracted = true
    }
}
