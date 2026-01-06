import UIKit

/// Centralized helper for opening app settings
/// Safe: No sensitive data logged, no-op if URL invalid
enum SettingsOpener {

    /// Opens the app's Settings page
    /// Call from UI actions when user needs to change permissions
    static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        Task { @MainActor in
            await UIApplication.shared.open(url)
        }
    }
}
