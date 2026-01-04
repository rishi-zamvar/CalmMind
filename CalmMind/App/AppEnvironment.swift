import Foundation

/// Debug-only environment switches for testing
/// These flags are controlled via launch arguments in UI tests
enum AppEnvironment {
    #if DEBUG
    /// Forces PromptService to fail, simulating offline mode
    static var offlineMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTest_offline")
    }

    /// Clears local storage on boot, simulating first launch
    static var isFirstLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTest_isFirstLaunch")
    }

    /// Enables verbose logging for debugging
    static var verboseLogging: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTest_verbose")
    }
    #else
    static let offlineMode = false
    static let isFirstLaunch = false
    static let verboseLogging = false
    #endif

    /// Whether running in any UI test mode
    static var isUITesting: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uiTesting")
        #else
        return false
        #endif
    }
}
