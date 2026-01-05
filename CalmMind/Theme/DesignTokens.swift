import SwiftUI
import UIKit

// MARK: - Design Tokens

/// Centralized design system for CalmMind
/// The app should feel like warm lamplight on paper.
enum DesignTokens {

    // MARK: - Colors

    enum Colors {
        // Backgrounds
        static let appBackground = Color(light: "F6F2EE", dark: "1C1B1A")
        static let elevatedSurface = Color(light: "FBF8F5", dark: "2A2826")
        static let subtleSection = Color(light: "EFE9E3", dark: "232120")

        // Primary accents (same in both modes)
        static let warmClay = Color(hex: "C9A27E")      // Primary action
        static let sage = Color(hex: "9DB2A0")          // Secondary/completed
        static let duskBlue = Color(hex: "8FA3B8")      // Informational

        // Text
        static let textPrimary = Color(light: "2F2F2D", dark: "F5F3F0")
        static let textSecondary = Color(light: "6E6A66", dark: "A8A4A0")
        static let textTertiary = Color(light: "9A9691", dark: "6E6A66")

        // Critical - text only, no red buttons
        static let destructive = Color(hex: "C45A5A")

        // Hairline for subtle separation
        static var hairline: Color {
            textSecondary.opacity(0.1)
        }
    }

    // MARK: - Typography

    enum Typography {
        /// ~46pt, semibold, SF Pro Rounded - for date header
        static let largeHeader = Font.system(.largeTitle, design: .rounded).weight(.semibold)

        /// 30pt, regular, SF Pro Rounded - for time display
        static let time = Font.system(size: 30, weight: .regular, design: .rounded)

        /// ~20pt, semibold, SF Pro Rounded - for section headers
        static let sectionHeader = Font.system(.title3, design: .rounded).weight(.semibold)

        /// ~16pt, regular, SF Pro Rounded - for body text
        static let body = Font.system(.body, design: .rounded)

        /// ~13pt, regular, SF Pro Rounded - for metadata
        static let meta = Font.system(.footnote, design: .rounded)
    }

    // MARK: - Spacing

    enum Spacing {
        static let screenPad: CGFloat = 20
        static let cardPad: CGFloat = 16
        static let sectionGap: CGFloat = 28
        static let rowPadV: CGFloat = 12
        static let rowPadH: CGFloat = 16
    }

    // MARK: - Radii

    enum Radii {
        static let screenCorner: CGFloat = 28   // Large containers
        static let card: CGFloat = 20
        static let button: CGFloat = 24
        static let pill: CGFloat = 999          // Full capsule
    }

    // MARK: - Sizing

    enum Sizing {
        /// Minimum hit target size per Apple HIG (44x44 points)
        static let hitTargetMin: CGFloat = 44
    }

    // MARK: - Shadow

    /// Single global shadow style - apply to cards only, never rows
    static func cardShadow() -> some View {
        EmptyView()
    }

    static let cardShadowColor = Color.black.opacity(0.08)
    static let cardShadowRadius: CGFloat = 14
    static let cardShadowY: CGFloat = 4

    // MARK: - Animation

    static let defaultAnimation = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.22)

    /// Spring animation for message entrance (float up effect)
    static let messageEntrance = Animation.spring(response: 0.42, dampingFraction: 0.82)

    // MARK: - Haptics

    enum Haptics {
        /// Light impact for subtle taps
        static func softTap() {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }

        /// Success haptic for completions only
        static func complete() {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}

// MARK: - Color Extensions

extension Color {
    /// Initialize with hex string (e.g., "F6F2EE")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Initialize with light and dark mode hex values
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(Color(hex: dark))
            default:
                return UIColor(Color(hex: light))
            }
        })
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply the standard card shadow
    func cardShadow() -> some View {
        self.shadow(
            color: DesignTokens.cardShadowColor,
            radius: DesignTokens.cardShadowRadius,
            x: 0,
            y: DesignTokens.cardShadowY
        )
    }

    /// Apply ambient background to screen
    func ambientBackground() -> some View {
        self.background(DesignTokens.Colors.appBackground.ignoresSafeArea())
    }
}

// MARK: - Copy Constants

/// Warm copy for empty states and errors
/// Never show: "Error", "Failed to load", "No data", "Something went wrong"
enum WarmCopy {
    static let emptyTodosHome = "Nothing urgent today. Want to add one gentle task?"
    static let emptyTodosTab = "Your slate is clear."
    static let noJournalEntries = "No entries yet. Tap the date to start today's."
    static let promptFallback = "Want to do a quick check-in about your day?"
    static let offlineError = "We can talk when you're ready."

    // Card headers
    static let todosCardTitle = "Today's Focus"
    static let todosCardSubtitle = "Three small wins is plenty."
    static let promptCardTitle = "A gentle check-in"

    // Hint text
    static let dateHeaderHint = "tap to open today's journal"

    // CTAs
    static let viewAllTodos = "View all"
    static let addTask = "Add task"
}
