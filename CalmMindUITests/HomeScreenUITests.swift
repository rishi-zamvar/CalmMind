import XCTest

/// Home screen UI tests
/// Verifies element presence and basic navigation
final class HomeScreenUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Element Presence

    func test_dateTimeHeader_exists() throws {
        let dateHeader = app.staticTexts.matching(identifier: "dateTimeHeader").firstMatch
        XCTAssertTrue(dateHeader.waitForExistence(timeout: 5))
    }

    func test_priorityTodosCard_exists() throws {
        let todosCard = app.otherElements.matching(identifier: "priorityTodosCard").firstMatch
        XCTAssertTrue(todosCard.waitForExistence(timeout: 5))
    }

    func test_reflectivePromptCard_exists() throws {
        let promptCard = app.otherElements.matching(identifier: "reflectivePromptCard").firstMatch
        XCTAssertTrue(promptCard.waitForExistence(timeout: 5))
    }

    func test_tabBar_exists() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists)

        // All 5 tabs should be present
        XCTAssertTrue(app.tabBars.buttons["Home"].exists)
        XCTAssertTrue(app.tabBars.buttons["Chat"].exists)
        XCTAssertTrue(app.tabBars.buttons["Todos"].exists)
        XCTAssertTrue(app.tabBars.buttons["Journal"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }

    // MARK: - Tab Navigation

    func test_homeTab_isSelectedByDefault() throws {
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.isSelected)
    }

    func test_tapChatTab_navigatesToChat() throws {
        let chatTab = app.tabBars.buttons["Chat"]
        chatTab.tap()

        XCTAssertTrue(chatTab.isSelected)
        // Chat screen should have a text input or navigation bar
        let chatNav = app.navigationBars.firstMatch
        XCTAssertTrue(chatNav.waitForExistence(timeout: 5))
    }

    func test_tapTodosTab_navigatesToTodos() throws {
        let todosTab = app.tabBars.buttons["Todos"]
        todosTab.tap()

        XCTAssertTrue(todosTab.isSelected)
        let todosNav = app.navigationBars["Todos"]
        XCTAssertTrue(todosNav.waitForExistence(timeout: 5))
    }

    func test_tapJournalTab_navigatesToJournal() throws {
        let journalTab = app.tabBars.buttons["Journal"]
        journalTab.tap()

        XCTAssertTrue(journalTab.isSelected)
        let journalNav = app.navigationBars["Journal"]
        XCTAssertTrue(journalNav.waitForExistence(timeout: 5))
    }

    func test_tapSettingsTab_navigatesToSettings() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()

        XCTAssertTrue(settingsTab.isSelected)
        let settingsNav = app.navigationBars["Settings"]
        XCTAssertTrue(settingsNav.waitForExistence(timeout: 5))
    }

    // MARK: - Deep Link Navigation

    func test_tapDateTimeHeader_opensJournalSheet() throws {
        let dateHeader = app.staticTexts.matching(identifier: "dateTimeHeader").firstMatch
        XCTAssertTrue(dateHeader.waitForExistence(timeout: 5))

        dateHeader.tap()

        // Should open journal detail sheet
        let journalSheet = app.navigationBars["Entry"]
        XCTAssertTrue(journalSheet.waitForExistence(timeout: 5))
    }

    func test_tapPromptCard_opensChatTab() throws {
        let promptCard = app.otherElements.matching(identifier: "reflectivePromptCard").firstMatch
        XCTAssertTrue(promptCard.waitForExistence(timeout: 5))

        promptCard.tap()

        // Should navigate to chat
        Thread.sleep(forTimeInterval: 0.5)
        let chatTab = app.tabBars.buttons["Chat"]
        XCTAssertTrue(chatTab.isSelected)
    }

    // MARK: - Card Content

    func test_todosCard_showsTitle() throws {
        let todosCard = app.otherElements.matching(identifier: "priorityTodosCard").firstMatch
        XCTAssertTrue(todosCard.waitForExistence(timeout: 5))

        // Should have the "Today's Focus" title
        let title = todosCard.staticTexts["Today's Focus"]
        XCTAssertTrue(title.exists)
    }

    func test_promptCard_showsTitle() throws {
        let promptCard = app.otherElements.matching(identifier: "reflectivePromptCard").firstMatch
        XCTAssertTrue(promptCard.waitForExistence(timeout: 5))

        // Should have the "A gentle check-in" title
        let title = promptCard.staticTexts["A gentle check-in"]
        XCTAssertTrue(title.exists)
    }
}
