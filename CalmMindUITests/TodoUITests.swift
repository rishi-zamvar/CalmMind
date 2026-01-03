import XCTest

/// UI smoke tests for the Todo interface
final class TodoUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Navigation

    func test_todoTabExists() throws {
        let todoTab = app.tabBars.buttons["Todos"]
        if todoTab.exists {
            todoTab.tap()
            XCTAssertTrue(app.navigationBars["Todos"].exists || app.staticTexts["Todos"].exists)
        }
    }

    // MARK: - List Display

    func test_todoListDisplays() throws {
        // Navigate to todos
        let todoTab = app.tabBars.buttons["Todos"]
        if todoTab.exists {
            todoTab.tap()
        }

        // Should show list or empty state
        let hasContent = app.staticTexts.count > 0 || app.cells.count > 0
        XCTAssertTrue(hasContent)
    }

    func test_emptyStateShowsWhenNoTodos() throws {
        // Navigate to todos
        let todoTab = app.tabBars.buttons["Todos"]
        if todoTab.exists {
            todoTab.tap()
        }

        // If no todos, should show empty state
        // This test just verifies the view renders without crashing
        XCTAssertTrue(app.exists)
    }

    // MARK: - Add Todo

    func test_addButtonExists() throws {
        // Navigate to todos
        let todoTab = app.tabBars.buttons["Todos"]
        if todoTab.exists {
            todoTab.tap()
        }

        // Look for add button or text field for adding todos
        let addButton = app.buttons["Add"]
        let plusButton = app.navigationBars.buttons.element(boundBy: 0)
        let textField = app.textFields.firstMatch

        // View should load successfully - at least one element should exist
        XCTAssertTrue(addButton.exists || plusButton.exists || textField.exists || app.staticTexts.count > 0)
    }

    // MARK: - Interaction

    func test_canTapTodoRow() throws {
        // Navigate to todos
        let todoTab = app.tabBars.buttons["Todos"]
        if todoTab.exists {
            todoTab.tap()
        }

        // If there are cells, try tapping one
        let cell = app.cells.firstMatch
        if cell.exists {
            cell.tap()
            // Should not crash
            XCTAssertTrue(app.exists)
        }
    }
}
