import XCTest

final class CalmMindUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_appLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the app launched with the tab bar (main content)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    }
}
