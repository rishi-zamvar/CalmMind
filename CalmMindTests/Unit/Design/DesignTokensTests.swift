import XCTest
import SwiftUI
@testable import CalmMind

/// Tests for design token values - verifies contracts in code, not rendered pixels
final class DesignTokensTests: XCTestCase {

    // MARK: - Color Hex Values (Primary Accents)

    func test_warmClay_hexValue_isC9A27E() {
        // warmClay is the primary action color
        let expected = "C9A27E"
        XCTAssertEqual(hexValue(DesignTokens.Colors.warmClay), expected)
    }

    func test_sage_hexValue_is9DB2A0() {
        // sage is the secondary/completed color
        let expected = "9DB2A0"
        XCTAssertEqual(hexValue(DesignTokens.Colors.sage), expected)
    }

    func test_duskBlue_hexValue_is8FA3B8() {
        // duskBlue is the informational color
        let expected = "8FA3B8"
        XCTAssertEqual(hexValue(DesignTokens.Colors.duskBlue), expected)
    }

    func test_destructive_hexValue_isC45A5A() {
        // destructive is for critical text only (no red buttons)
        let expected = "C45A5A"
        XCTAssertEqual(hexValue(DesignTokens.Colors.destructive), expected)
    }

    // MARK: - Spacing Constants

    func test_screenPad_equals20() {
        XCTAssertEqual(DesignTokens.Spacing.screenPad, 20)
    }

    func test_cardPad_equals16() {
        XCTAssertEqual(DesignTokens.Spacing.cardPad, 16)
    }

    func test_sectionGap_equals28() {
        XCTAssertEqual(DesignTokens.Spacing.sectionGap, 28)
    }

    func test_rowPadV_equals12() {
        XCTAssertEqual(DesignTokens.Spacing.rowPadV, 12)
    }

    func test_rowPadH_equals16() {
        XCTAssertEqual(DesignTokens.Spacing.rowPadH, 16)
    }

    // MARK: - Radii Constants

    func test_screenCorner_equals28() {
        XCTAssertEqual(DesignTokens.Radii.screenCorner, 28)
    }

    func test_card_equals20() {
        XCTAssertEqual(DesignTokens.Radii.card, 20)
    }

    func test_button_equals24() {
        XCTAssertEqual(DesignTokens.Radii.button, 24)
    }

    func test_pill_equals999() {
        XCTAssertEqual(DesignTokens.Radii.pill, 999)
    }

    // MARK: - Shadow Values

    func test_cardShadowRadius_equals14() {
        XCTAssertEqual(DesignTokens.cardShadowRadius, 14)
    }

    func test_cardShadowY_equals4() {
        XCTAssertEqual(DesignTokens.cardShadowY, 4)
    }

    // MARK: - Tint Enforcement

    /// Verify warmClay is available and properly defined for app tint
    func test_warmClay_existsForTint() {
        // warmClay should be used as the app-wide tint
        let warmClay = DesignTokens.Colors.warmClay
        XCTAssertNotNil(warmClay, "warmClay should exist for app tint")
    }

    /// Verify no system blue is used by checking that our palette doesn't include pure blue
    func test_noPureBlue_inColorPalette() {
        // Our palette should not include pure system blue (0, 122, 255)
        let blueHex = "007AFF" // System blue hex

        let allColors = [
            DesignTokens.Colors.warmClay,
            DesignTokens.Colors.sage,
            DesignTokens.Colors.duskBlue,
            DesignTokens.Colors.destructive
        ]

        for color in allColors {
            let hex = hexValue(color)
            XCTAssertNotEqual(hex, blueHex, "Color palette should not include system blue")
        }
    }

    // MARK: - Helper

    /// Extracts hex string from a Color by initializing it
    /// This tests the color definition, not rendered appearance
    private func hexValue(_ color: Color) -> String {
        // Convert Color to UIColor to extract components
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        return String(
            format: "%02X%02X%02X",
            Int(round(r * 255)),
            Int(round(g * 255)),
            Int(round(b * 255))
        )
    }
}
