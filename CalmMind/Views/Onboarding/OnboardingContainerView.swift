import SwiftUI

/// Navigation coordinator for onboarding flow
/// Manages state between name input and permissions screens
/// Uses atomic completion latch to prevent double-submit
struct OnboardingContainerView: View {
    let locationService: LocationServiceProtocol
    let userPreferences: UserPreferences
    let onComplete: () -> Void

    @StateObject private var permissionManager: PermissionStateManager

    @State private var currentStep: OnboardingStep = .name
    @State private var userName = ""
    @State private var isCommittingCompletion = false

    enum OnboardingStep {
        case name
        case permissions
    }

    init(
        locationService: LocationServiceProtocol,
        userPreferences: UserPreferences,
        onComplete: @escaping () -> Void
    ) {
        self.locationService = locationService
        self.userPreferences = userPreferences
        self.onComplete = onComplete

        // Create PermissionStateManager with injected dependencies
        _permissionManager = StateObject(wrappedValue: PermissionStateManager(
            locationService: locationService,
            userPreferences: userPreferences
        ))
    }

    var body: some View {
        Group {
            switch currentStep {
            case .name:
                WelcomeNameView(name: $userName) {
                    // Save name and move to permissions
                    userPreferences.userName = userName.trimmingCharacters(in: .whitespaces)
                    withAnimation {
                        currentStep = .permissions
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .permissions:
                PermissionsView(
                    permissionManager: permissionManager,
                    userPreferences: userPreferences
                ) {
                    completeOnboarding()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .animation(DesignTokens.defaultAnimation, value: currentStep)
    }

    // MARK: - Private Methods

    /// Atomic, idempotent completion - can only fire once
    private func completeOnboarding() {
        // One-way latch: prevent double-submit
        guard !isCommittingCompletion else { return }
        guard !userPreferences.hasCompletedOnboardingV2 else { return }

        isCommittingCompletion = true
        userPreferences.hasCompletedOnboardingV2 = true

        // Notify parent
        onComplete()
        // Note: isCommittingCompletion stays true; view will unmount
    }
}

#Preview {
    // Preview requires mocks - shown for structure only
    Text("OnboardingContainerView Preview")
        .font(.title)
}
