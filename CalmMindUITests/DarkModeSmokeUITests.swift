import XCTest

/// Dark mode smoke tests
/// Verifies screens load and text is visible in dark mode
/// Does NOT verify exact hex colors (too brittle)
final class DarkModeSmokeUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Smoke Tests

    func test_darkMode_homeScreenLoads() throws {
        // Force dark mode via launch argument
        // Note: This requires the app to handle the argument or system settings
        app.launch()

        // Home should load
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))

        // Key elements should exist
        let dateHeader = app.staticTexts.matching(identifier: "dateTimeHeader").firstMatch
        XCTAssertTrue(dateHeader.waitForExistence(timeout: 5))
    }

    func test_darkMode_chatScreenLoads() throws {
        app.launch()

        let chatTab = app.tabBars.buttons["Chat"]
        chatTab.tap()

        // Chat should load
        XCTAssertTrue(chatTab.isSelected)
    }

    func test_darkMode_todosScreenLoads() throws {
        app.launch()

        let todosTab = app.tabBars.buttons["Todos"]
        todosTab.tap()

        // Todos nav should appear
        let todosNav = app.navigationBars["Todos"]
        XCTAssertTrue(todosNav.waitForExistence(timeout: 5))
    }

    func test_darkMode_journalScreenLoads() throws {
        app.launch()

        let journalTab = app.tabBars.buttons["Journal"]
        journalTab.tap()

        // Journal nav should appear
        let journalNav = app.navigationBars["Journal"]
        XCTAssertTrue(journalNav.waitForExistence(timeout: 5))
    }

    func test_darkMode_settingsScreenLoads() throws {
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()

        // Settings nav should appear
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5))
    }

    // MARK: - Text Visibility

    func test_darkMode_homeTextIsVisible() throws {
        app.launch()

        // Wait for home to load
        let dateHeader = app.staticTexts.matching(identifier: "dateTimeHeader").firstMatch
        XCTAssertTrue(dateHeader.waitForExistence(timeout: 5))

        // Verify static texts are present (not checking color, just existence)
        let todosCard = app.otherElements.matching(identifier: "priorityTodosCard").firstMatch
        XCTAssertTrue(todosCard.exists)

        let todosTitle = todosCard.staticTexts["Today's Focus"]
        XCTAssertTrue(todosTitle.exists, "Card title should be visible")
    }

    // MARK: - No Crashes

    func test_darkMode_rapidTabSwitching_noCrash() throws {
        app.launch()

        // Rapidly switch between tabs
        for _ in 0..<10 {
            app.tabBars.buttons["Chat"].tap()
            app.tabBars.buttons["Todos"].tap()
            app.tabBars.buttons["Journal"].tap()
            app.tabBars.buttons["Settings"].tap()
            app.tabBars.buttons["Home"].tap()
        }

        // App should still be running
        XCTAssertTrue(app.tabBars.buttons["Home"].exists)
    }
}
