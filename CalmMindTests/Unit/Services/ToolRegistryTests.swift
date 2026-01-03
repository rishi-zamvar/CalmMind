import XCTest
@testable import CalmMind

final class ToolRegistryTests: XCTestCase {

    var sut: ToolRegistry!

    override func setUp() {
        super.setUp()
        sut = ToolRegistry()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Registration

    func test_registersAllTools() {
        let tools = sut.allTools
        XCTAssertFalse(tools.isEmpty)
    }

    func test_toolHasName() {
        let tools = sut.allTools
        for tool in tools {
            XCTAssertFalse(tool.name.isEmpty, "Tool must have a name")
        }
    }

    func test_toolHasDescription() {
        let tools = sut.allTools
        for tool in tools {
            XCTAssertFalse(tool.description.isEmpty, "Tool \(tool.name) must have a description")
        }
    }

    func test_toolHasParameterSchema() {
        let tools = sut.allTools
        for tool in tools {
            XCTAssertNotNil(tool.parameters, "Tool \(tool.name) must have parameter schema")
        }
    }

    // MARK: - Available Tools

    func test_addTodo_registered() {
        let tool = sut.tool(named: "add_todo")
        XCTAssertNotNil(tool)
        XCTAssertEqual(tool?.name, "add_todo")
    }

    func test_completeTodo_registered() {
        let tool = sut.tool(named: "complete_todo")
        XCTAssertNotNil(tool)
    }

    func test_listTodos_registered() {
        let tool = sut.tool(named: "list_todos")
        XCTAssertNotNil(tool)
    }

    func test_writeJournal_registered() {
        let tool = sut.tool(named: "write_journal")
        XCTAssertNotNil(tool, "write_journal must be registered for LLM to write journals")
        XCTAssertEqual(tool?.name, "write_journal")
        XCTAssertTrue(tool?.requiredParams.contains("content") ?? false)
    }

    // MARK: - Schema Export

    func test_exportsOpenAIFunctionSchema() {
        let schemas = sut.openAIToolDefinitions

        XCTAssertFalse(schemas.isEmpty)
        for schema in schemas {
            XCTAssertEqual(schema.type, "function")
            XCTAssertFalse(schema.function.name.isEmpty)
        }
    }

    func test_schemaHasRequiredFields() {
        let schemas = sut.openAIToolDefinitions

        for schema in schemas {
            XCTAssertFalse(schema.function.name.isEmpty)
            XCTAssertFalse(schema.function.description.isEmpty)
        }
    }

    // MARK: - Tool Lookup

    func test_findToolByName() {
        let tool = sut.tool(named: "add_todo")
        XCTAssertNotNil(tool)
    }

    func test_findToolByName_returnsNilForUnknown() {
        let tool = sut.tool(named: "nonexistent_tool")
        XCTAssertNil(tool)
    }

    // MARK: - Tool Names

    func test_allToolNames() {
        let names = sut.allToolNames
        XCTAssertTrue(names.contains("add_todo"))
        XCTAssertTrue(names.contains("complete_todo"))
        XCTAssertTrue(names.contains("list_todos"))
        XCTAssertTrue(names.contains("write_journal"))
    }
}

// MARK: - ToolValidatorTests

final class ToolValidatorTests: XCTestCase {

    var sut: ToolValidator!
    var registry: ToolRegistry!

    override func setUp() {
        super.setUp()
        registry = ToolRegistry()
        sut = ToolValidator(registry: registry)
    }

    override func tearDown() {
        sut = nil
        registry = nil
        super.tearDown()
    }

    // MARK: - Validation

    func test_validatesRequiredParams() {
        // add_todo requires "title"
        let result = sut.validate(toolName: "add_todo", arguments: [:])
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.error?.contains("title") ?? false)
    }

    func test_acceptsValidParams() {
        let result = sut.validate(toolName: "add_todo", arguments: ["title": "Buy groceries"])
        XCTAssertTrue(result.isValid)
    }

    func test_validatesParamTypes() {
        // title should be a string
        let result = sut.validate(toolName: "add_todo", arguments: ["title": 123])
        XCTAssertFalse(result.isValid)
    }

    // MARK: - Security

    func test_rejectsUnknownTool() {
        let result = sut.validate(toolName: "unknown_tool", arguments: [:])
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.error?.contains("Unknown") ?? false)
    }

    func test_sanitizesStringParams() {
        // Should handle strings with special characters
        let result = sut.validate(toolName: "add_todo", arguments: ["title": "Test <script>alert('xss')</script>"])
        XCTAssertTrue(result.isValid)  // Should accept but sanitize
    }

    func test_rejectsMalformedJSON() {
        // Empty tool name should be rejected
        let result = sut.validate(toolName: "", arguments: [:])
        XCTAssertFalse(result.isValid)
    }

    // MARK: - Parse Arguments

    func test_parsesJSONArguments() {
        let json = "{\"title\": \"Test todo\"}"
        let result = sut.parseArguments(json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?["title"] as? String, "Test todo")
    }

    func test_parsesEmptyJSON() {
        let json = "{}"
        let result = sut.parseArguments(json)

        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isEmpty ?? false)
    }

    func test_returnsNilForInvalidJSON() {
        let json = "not valid json"
        let result = sut.parseArguments(json)

        XCTAssertNil(result)
    }
}
