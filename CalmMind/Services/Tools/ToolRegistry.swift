import Foundation

/// Definition of a tool that can be called by the AI
struct ToolDefinition: Sendable {
    /// Unique name of the tool
    let name: String

    /// Human-readable description
    let description: String

    /// JSON schema for parameters
    let parameters: [String: Any]

    /// Required parameter names
    let requiredParams: [String]

    /// Parameter types for validation
    let paramTypes: [String: ParameterType]

    enum ParameterType: Sendable {
        case string
        case integer
        case boolean
        case array
    }
}

/// Registry of all available tools for AI function calling
final class ToolRegistry: Sendable {

    // MARK: - Tool Definitions

    private static let tools: [ToolDefinition] = [
        // Add Todo
        ToolDefinition(
            name: "add_todo",
            description: "Add a new todo item to the user's list",
            parameters: [
                "type": "object",
                "properties": [
                    "title": [
                        "type": "string",
                        "description": "The title of the todo item"
                    ],
                    "due_date": [
                        "type": "string",
                        "description": "Optional due date (ISO 8601 format)"
                    ]
                ],
                "required": ["title"]
            ],
            requiredParams: ["title"],
            paramTypes: ["title": .string, "due_date": .string]
        ),

        // Complete Todo
        ToolDefinition(
            name: "complete_todo",
            description: "Mark a todo item as completed",
            parameters: [
                "type": "object",
                "properties": [
                    "title": [
                        "type": "string",
                        "description": "The title of the todo to complete (fuzzy match)"
                    ],
                    "id": [
                        "type": "string",
                        "description": "The ID of the todo to complete"
                    ]
                ]
            ],
            requiredParams: [],  // Either title or id
            paramTypes: ["title": .string, "id": .string]
        ),

        // List Todos
        ToolDefinition(
            name: "list_todos",
            description: "List all incomplete todo items",
            parameters: [
                "type": "object",
                "properties": [
                    "include_completed": [
                        "type": "boolean",
                        "description": "Whether to include completed todos"
                    ]
                ]
            ],
            requiredParams: [],
            paramTypes: ["include_completed": .boolean]
        ),

        // Create Journal Draft
        ToolDefinition(
            name: "create_journal_draft",
            description: "Create a draft journal entry for the current session",
            parameters: [
                "type": "object",
                "properties": [:]
            ],
            requiredParams: [],
            paramTypes: [:]
        ),

        // Add Memory
        ToolDefinition(
            name: "add_memory",
            description: "Remember an important fact about the user",
            parameters: [
                "type": "object",
                "properties": [
                    "content": [
                        "type": "string",
                        "description": "The fact to remember"
                    ],
                    "is_private": [
                        "type": "boolean",
                        "description": "If true, this memory won't be shared with the AI"
                    ]
                ],
                "required": ["content"]
            ],
            requiredParams: ["content"],
            paramTypes: ["content": .string, "is_private": .boolean]
        ),

        // Write Journal
        ToolDefinition(
            name: "write_journal",
            description: "Write to today's journal entry. Use only when the user explicitly asks to write or save a journal entry, or clearly indicates they want something recorded in their journal.",
            parameters: [
                "type": "object",
                "properties": [
                    "content": [
                        "type": "string",
                        "description": "The journal content to write"
                    ],
                    "append": [
                        "type": "boolean",
                        "description": "If true, append to existing entry. If false, replace. Defaults to true."
                    ]
                ],
                "required": ["content"]
            ],
            requiredParams: ["content"],
            paramTypes: ["content": .string, "append": .boolean]
        )
    ]

    // MARK: - Public API

    /// All registered tools
    var allTools: [ToolDefinition] {
        Self.tools
    }

    /// All tool names
    var allToolNames: [String] {
        Self.tools.map { $0.name }
    }

    /// Get a tool by name
    func tool(named name: String) -> ToolDefinition? {
        Self.tools.first { $0.name == name }
    }

    /// Export as OpenAI function definitions
    var openAIToolDefinitions: [OpenAIToolDefinition] {
        Self.tools.map { tool in
            OpenAIToolDefinition(
                function: OpenAIFunctionDefinition(
                    name: tool.name,
                    description: tool.description,
                    parameters: tool.parameters.mapValues { AnyCodable($0) }
                )
            )
        }
    }
}
