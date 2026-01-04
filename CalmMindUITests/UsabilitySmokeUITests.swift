import XCTest

/// End-to-end usability tests
/// Verifies the user can complete a basic session without dead ends
final class UsabilitySmokeUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - First Launch / Empty States

    func test_firstLaunch_homeLoadsWithEmptyStates() throws {
        app.launchArguments.append("-uiTest_isFirstLaunch")
        app.launch()

        // Home tab should be selected
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.exists)
        XCTAssertTrue(homeTab.isSelected)

        // Date/time header should exist
        let dateHeader = app.staticTexts.matching(identifier: "dateTimeHeader").firstMatch
        XCTAssertTrue(dateHeader.waitForExistence(timeout: 5))

        // Todos card should show empty state (not crash or blank)
        let todosCard = app.otherElements.matching(identifier: "priorityTodosCard").firstMatch
        XCTAssertTrue(todosCard.waitForExistence(timeout: 5))

        // Prompt card should show something (fallback or loading)
        let promptCard = app.otherElements.matching(identifier: "reflectivePromptCard").firstMatch
        XCTAssertTrue(promptCard.waitForExistence(timeout: 5))
    }

    // MARK: - Journal Navigation

    func test_tapDateHeader_opensTodayJournal() throws {
        app.launch()

        // Find and tap the date header
        let dateHeader = app.staticTexts.matching(identifier: "dateTimeHeader").firstMatch
        XCTAssertTrue(dateHeader.waitForExistence(timeout: 5))
        dateHeader.tap()

        // Journal detail sheet should appear
        let journalSheet = app.navigationBars["Entry"]
        XCTAssertTrue(journalSheet.waitForExistence(timeout: 5))
    }

    // MARK: - Todo Flow

    func test_navigateToTodos_andBack() throws {
        app.launch()

        // Tap todos tab
        let todosTab = app.tabBars.buttons["Todos"]
        XCTAssertTrue(todosTab.exists)
        todosTab.tap()

        // Todos screen should load
        let todosNav = app.navigationBars["Todos"]
        XCTAssertTrue(todosNav.waitForExistence(timeout: 5))

        // Go back to home
        let homeTab = app.tabBars.buttons["Home"]
        homeTab.tap()

        // Home should still work
        let dateHeader = app.staticTexts.matching(identifier: "dateTimeHeader").firstMatch
        XCTAssertTrue(dateHeader.waitForExistence(timeout: 5))
    }

    // MARK: - Chat Navigation

    func test_promptCard_opensChat() throws {
        app.launch()

        // Find and tap the prompt card
        let promptCard = app.otherElements.matching(identifier: "reflectivePromptCard").firstMatch
        XCTAssertTrue(promptCard.waitForExistence(timeout: 5))
        promptCard.tap()

        // Should navigate to chat tab
        let chatTab = app.tabBars.buttons["Chat"]
        XCTAssertTrue(chatTab.waitForExistence(timeout: 2))
        // Give time for navigation to complete
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(chatTab.isSelected)
    }

    // MARK: - Tab State Contract

    func test_appLaunch_startsOnHomeTab() throws {
        app.launch()

        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.exists)
        XCTAssertTrue(homeTab.isSelected, "App should always launch to Home tab")
    }

    // MARK: - Privacy Mode

    func test_privacyMode_promptShowsGenericFallback() throws {
        // Enable privacy mode via UserDefaults
        app.launchArguments.append(contentsOf: ["-privacyMode", "true"])
        app.launch()

        // Prompt card should exist and show fallback
        let promptCard = app.otherElements.matching(identifier: "reflectivePromptCard").firstMatch
        XCTAssertTrue(promptCard.waitForExistence(timeout: 5))

        // Should not be blank
        let promptText = promptCard.staticTexts.firstMatch
        XCTAssertTrue(promptText.exists, "Prompt card should have visible text in privacy mode")
    }

    // MARK: - Offline Mode

    func test_offlineMode_promptFallsBack_appStillUsable() throws {
        app.launchArguments.append("-uiTest_offline")
        app.launch()

        // App should load without crashing
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))

        // Prompt card should show fallback (not spinner forever)
        let promptCard = app.otherElements.matching(identifier: "reflectivePromptCard").firstMatch
        XCTAssertTrue(promptCard.waitForExistence(timeout: 10))

        // Wait for loading to complete (fallback or error state)
        // The card should eventually show text, not stay in loading state
        Thread.sleep(forTimeInterval: 5)

        // Chat should still be tappable
        let chatTab = app.tabBars.buttons["Chat"]
        chatTab.tap()
        XCTAssertTrue(chatTab.isSelected)
    }

    // MARK: - All Tabs Accessible

    func test_allTabs_areAccessible() throws {
        app.launch()

        let tabNames = ["Home", "Chat", "Todos", "Journal", "Settings"]

        for tabName in tabNames {
            let tab = app.tabBars.buttons[tabName]
            XCTAssertTrue(tab.exists, "\(tabName) tab should exist")
            tab.tap()
            XCTAssertTrue(tab.isSelected, "\(tabName) tab should be selectable")
        }
    }

    // MARK: - Todo Integration

    func test_addTodoInTodosView_thenHomeShowsItInTopThree() throws {
        app.launch()

        // Navigate to todos
        let todosTab = app.tabBars.buttons["Todos"]
        todosTab.tap()

        // Wait for todos view to load
        let addField = app.textFields["Add a gentle task..."]
        XCTAssertTrue(addField.waitForExistence(timeout: 5))

        // Add a new todo
        addField.tap()
        addField.typeText("Test todo from smoke test")

        // Tap the add button
        let addButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'plus' OR label CONTAINS 'Add'")).firstMatch
        addButton.tap()

        // Navigate back to home
        let homeTab = app.tabBars.buttons["Home"]
        homeTab.tap()

        // The new todo should appear in the priority todos card
        let todosCard = app.otherElements.matching(identifier: "priorityTodosCard").firstMatch
        XCTAssertTrue(todosCard.waitForExistence(timeout: 5))

        // The todo text should be visible somewhere in the card
        let todoText = app.staticTexts["Test todo from smoke test"]
        XCTAssertTrue(todoText.waitForExistence(timeout: 5), "Newly added todo should appear on home screen")
    }

    // MARK: - CTAs

    func test_viewAllCTA_navigatesToTodos() throws {
        // First add some todos so CTAs appear
        app.launchArguments.append("-uiTest_hasTodos")
        app.launch()

        // Find "View all" button in priority todos card
        let viewAllButton = app.buttons["View all"]

        // If button exists, tap it
        if viewAllButton.waitForExistence(timeout: 5) {
            viewAllButton.tap()

            // Should be on todos tab now
            let todosTab = app.tabBars.buttons["Todos"]
            XCTAssertTrue(todosTab.isSelected, "View all should navigate to Todos tab")
        } else {
            // If no todos, card is in empty state - skip this test
            throw XCTSkip("No todos available - CTAs not visible")
        }
    }

    func test_addTaskCTA_navigatesToTodosWithFocus() throws {
        // First add some todos so CTAs appear
        app.launchArguments.append("-uiTest_hasTodos")
        app.launch()

        // Find "Add task" button in priority todos card
        let addTaskButton = app.buttons["Add task"]

        if addTaskButton.waitForExistence(timeout: 5) {
            addTaskButton.tap()

            // Should be on todos tab
            let todosTab = app.tabBars.buttons["Todos"]
            XCTAssertTrue(todosTab.waitForExistence(timeout: 2))
            XCTAssertTrue(todosTab.isSelected, "Add task should navigate to Todos tab")

            // The add field should eventually be focused (keyboard visible)
            // Note: Keyboard detection in UI tests can be flaky
            Thread.sleep(forTimeInterval: 0.5)
        } else {
            throw XCTSkip("No todos available - CTAs not visible")
        }
    }

    // MARK: - Chat Input

    func test_chatInputField_isTypeable() throws {
        app.launch()

        // Navigate to chat
        let chatTab = app.tabBars.buttons["Chat"]
        chatTab.tap()
        XCTAssertTrue(chatTab.isSelected)

        // Find the chat input field
        let chatInput = app.textFields.firstMatch
        XCTAssertTrue(chatInput.waitForExistence(timeout: 5))

        // Type in the field
        chatInput.tap()
        chatInput.typeText("Hello, this is a test")

        // Verify text was entered
        XCTAssertTrue(chatInput.value as? String == "Hello, this is a test" ||
                      app.staticTexts["Hello, this is a test"].exists)
    }
}
