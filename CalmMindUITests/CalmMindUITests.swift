import XCTest

final class CalmMindUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_appLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the app launched with the main content
        XCTAssertTrue(app.staticTexts["CalmMind"].exists)
    }
}
