import XCTest

/// Navigation UI tests
/// Verifies tab state contracts and sheet behaviors
final class NavigationUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tab State Contract

    func test_appLaunch_startsOnHomeTab() throws {
        app.launch()

        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.isSelected, "App should always launch to Home tab")
    }

    func test_tabSelection_notPersistedAfterRelaunch() throws {
        // First launch - navigate to Settings
        app.launch()
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        XCTAssertTrue(settingsTab.isSelected)

        // Terminate and relaunch
        app.terminate()
        app.launch()

        // Should start on Home, not Settings
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.isSelected, "Tab selection should not persist across launches")
    }

    // MARK: - Sheet Behavior

    func test_journalSheet_dismissable() throws {
        app.launch()

        // Open journal from date header
        let dateHeader = app.staticTexts.matching(identifier: "dateTimeHeader").firstMatch
        XCTAssertTrue(dateHeader.waitForExistence(timeout: 5))
        dateHeader.tap()

        // Sheet should open
        let journalSheet = app.navigationBars["Entry"]
        XCTAssertTrue(journalSheet.waitForExistence(timeout: 5))

        // Close button should exist and work
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.exists)
        closeButton.tap()

        // Sheet should be dismissed
        XCTAssertFalse(journalSheet.exists)

        // Home should still be visible
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.isSelected)
    }

    // MARK: - Tab Cycling

    func test_tabCycling_worksCorrectly() throws {
        app.launch()

        let tabs = ["Home", "Chat", "Todos", "Journal", "Settings"]

        // Forward cycle
        for tab in tabs {
            let tabButton = app.tabBars.buttons[tab]
            tabButton.tap()
            XCTAssertTrue(tabButton.isSelected, "\(tab) should be selected after tap")
        }

        // Backward cycle
        for tab in tabs.reversed() {
            let tabButton = app.tabBars.buttons[tab]
            tabButton.tap()
            XCTAssertTrue(tabButton.isSelected, "\(tab) should be selected after tap")
        }

        // End on Home
        let homeTab = app.tabBars.buttons["Home"]
        homeTab.tap()
        XCTAssertTrue(homeTab.isSelected)
    }

    // MARK: - Navigation Stack

    func test_todosList_navigateAndBack() throws {
        app.launch()

        // Navigate to Todos
        let todosTab = app.tabBars.buttons["Todos"]
        todosTab.tap()

        // Todos screen should load
        let todosNav = app.navigationBars["Todos"]
        XCTAssertTrue(todosNav.waitForExistence(timeout: 5))

        // Navigate back to Home
        let homeTab = app.tabBars.buttons["Home"]
        homeTab.tap()

        // Home elements should be visible
        let dateHeader = app.staticTexts.matching(identifier: "dateTimeHeader").firstMatch
        XCTAssertTrue(dateHeader.waitForExistence(timeout: 5))
    }
}
