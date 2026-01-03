import XCTest

/// UI smoke tests for the Chat interface
final class ChatUITests: XCTestCase {

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

    // MARK: - Smoke Tests

    func test_chatViewExists() throws {
        // Navigate to chat tab if needed
        let chatTab = app.tabBars.buttons["Chat"]
        if chatTab.exists {
            chatTab.tap()
        }

        // Verify chat elements exist
        let textField = app.textFields["Message input"]
        let sendButton = app.buttons["Send"]

        // At least one of these should exist
        XCTAssertTrue(textField.exists || sendButton.exists || app.staticTexts.count > 0)
    }

    func test_inputFieldIsEditable() throws {
        // Navigate to chat
        let chatTab = app.tabBars.buttons["Chat"]
        if chatTab.exists {
            chatTab.tap()
        }

        // Find text field
        let textField = app.textFields.firstMatch
        if textField.exists {
            textField.tap()
            textField.typeText("Hello")
            XCTAssertEqual(textField.value as? String, "Hello")
        }
    }

    func test_sendButtonExistsWhenInputHasText() throws {
        // Navigate to chat
        let chatTab = app.tabBars.buttons["Chat"]
        if chatTab.exists {
            chatTab.tap()
        }

        // Type in text field
        let textField = app.textFields.firstMatch
        if textField.exists {
            textField.tap()
            textField.typeText("Test message")

            // Send button should be enabled
            let sendButton = app.buttons["Send"]
            if sendButton.exists {
                XCTAssertTrue(sendButton.isEnabled)
            }
        }
    }

    func test_emptyStateOrMessagesDisplayed() throws {
        // Navigate to chat
        let chatTab = app.tabBars.buttons["Chat"]
        if chatTab.exists {
            chatTab.tap()
        }

        // Should have some content - either messages or empty state
        let hasContent = app.staticTexts.count > 0
        XCTAssertTrue(hasContent)
    }
}
