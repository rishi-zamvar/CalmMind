import SwiftUI

/// Unified permissions screen
/// Requires interaction with both permissions before allowing continuation
struct PermissionsView: View {
    @ObservedObject var permissionManager: PermissionStateManager
    let userPreferences: UserPreferences
    let onComplete: () -> Void

    @State private var showSettingsAlert = false
    @State private var settingsAlertMessage = ""
    @State private var activeTask: Task<Void, Never>?

    /// Auto-journaling toggle - defaults to ON during onboarding
    @State private var autoJournalingEnabled = true

    /// AI Insights toggle - defaults to OFF (opt-in)
    @State private var aiInsightsEnabled = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Header
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 60))
                .foregroundStyle(DesignTokens.Colors.warmClay)

            Text("Enable Features")
                .font(DesignTokens.Typography.largeHeader)
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            Text("Tap Enable on each to continue")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            // Permission rows
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "location.fill",
                    title: "Location",
                    subtitle: "Show local weather to provide context",
                    status: permissionManager.locationStatus,
                    isLoading: permissionManager.isRequestingLocation,
                    onRequest: handleLocationRequest
                )

                PermissionRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Gentle reminders for check-ins",
                    status: permissionManager.notificationStatus,
                    isLoading: permissionManager.isRequestingNotifications,
                    onRequest: handleNotificationRequest
                )

                // Auto-journaling toggle
                FeatureToggleRow(
                    icon: "book.fill",
                    title: "Auto-save to Journal",
                    subtitle: "Capture conversations as journal entries",
                    isEnabled: $autoJournalingEnabled
                )

                // AI Insights toggle (opt-in)
                FeatureToggleRow(
                    icon: "lightbulb.fill",
                    title: "AI Insights",
                    subtitle: "Get patterns & wellness tips from journal entries",
                    isEnabled: $aiInsightsEnabled
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)

            Spacer()

            // Get Started button
            Button(action: {
                guard permissionManager.canProceed else { return }
                // Save feature preferences
                userPreferences.autoJournalingEnabled = autoJournalingEnabled
                userPreferences.aiInsightsEnabled = aiInsightsEnabled
                onComplete()
            }) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(permissionManager.canProceed ? DesignTokens.Colors.warmClay : DesignTokens.Colors.textTertiary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radii.button))
            }
            .disabled(!permissionManager.canProceed)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .ambientBackground()
        .alert("Permission Required", isPresented: $showSettingsAlert) {
            Button("Open Settings") {
                SettingsOpener.openAppSettings()
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text(settingsAlertMessage)
        }
        .onAppear {
            Task { await permissionManager.refreshStates() }
        }
        .onDisappear {
            activeTask?.cancel()
        }
    }

    // MARK: - Permission Handlers

    private func handleLocationRequest() {
        activeTask?.cancel()
        activeTask = Task {
            let result = await permissionManager.requestLocation()
            guard !Task.isCancelled else { return }
            if result == .denied {
                settingsAlertMessage = "Location access was denied. Enable it in Settings to see local weather."
                showSettingsAlert = true
            }
        }
    }

    private func handleNotificationRequest() {
        activeTask?.cancel()
        activeTask = Task {
            let result = await permissionManager.requestNotifications()
            guard !Task.isCancelled else { return }
            if result == .denied {
                settingsAlertMessage = "Notifications were denied. Enable them in Settings for reminders."
                showSettingsAlert = true
            }
        }
    }
}

// MARK: - Permission Row

/// Individual permission row with enable button or status indicator
struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let status: PermissionStatus
    let isLoading: Bool
    let onRequest: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(DesignTokens.Colors.warmClay)
                .frame(width: 44, height: 44)

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignTokens.Typography.sectionHeader)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text(subtitle)
                    .font(DesignTokens.Typography.meta)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            // Status / Action
            Group {
                switch status {
                case .granted:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(DesignTokens.Colors.sage)
                case .denied:
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                case .notAsked:
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Enable") {
                            onRequest()
                        }
                        .buttonStyle(.bordered)
                        .tint(DesignTokens.Colors.warmClay)
                    }
                }
            }
            .frame(minWidth: 80)
        }
        .padding()
        .background(DesignTokens.Colors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radii.card))
    }
}

// MARK: - Feature Toggle Row

/// Toggle row for feature preferences (not OS permissions)
struct FeatureToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(DesignTokens.Colors.warmClay)
                .frame(width: 44, height: 44)

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignTokens.Typography.sectionHeader)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text(subtitle)
                    .font(DesignTokens.Typography.meta)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }

            Spacer()

            // Toggle
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(DesignTokens.Colors.warmClay)
        }
        .padding()
        .background(DesignTokens.Colors.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radii.card))
    }
}

#Preview {
    // Preview requires mock - shown for structure only
    Text("PermissionsView Preview")
        .font(.title)
}
