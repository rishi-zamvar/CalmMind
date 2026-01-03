import Foundation

// MARK: - Message Types

/// Role in a chat conversation
enum OpenAIRole: String, Codable {
    case system
    case user
    case assistant
    case tool
}

/// A message in the OpenAI chat completion format
struct OpenAIMessage: Codable, Equatable {
    let role: OpenAIRole
    let content: String?
    let toolCallId: String?
    let toolCalls: [OpenAIToolCall]?

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case toolCallId = "tool_call_id"
        case toolCalls = "tool_calls"
    }

    init(role: OpenAIRole, content: String?, toolCallId: String? = nil, toolCalls: [OpenAIToolCall]? = nil) {
        self.role = role
        self.content = content
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
    }
}

// MARK: - Tool Types

/// Definition of a tool for OpenAI function calling
struct OpenAIToolDefinition: Codable, Equatable {
    let type: String
    let function: OpenAIFunctionDefinition

    init(function: OpenAIFunctionDefinition) {
        self.type = "function"
        self.function = function
    }
}

/// Function definition for OpenAI tool
struct OpenAIFunctionDefinition: Codable, Equatable {
    let name: String
    let description: String
    let parameters: [String: AnyCodable]
}

/// Tool call from OpenAI response
struct OpenAIToolCall: Codable, Equatable {
    let id: String
    let type: String
    let function: OpenAIFunctionCall
}

/// Function call details
struct OpenAIFunctionCall: Codable, Equatable {
    let name: String
    let arguments: String
}

// MARK: - Request Types

/// Request body for chat completion
struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let tools: [OpenAIToolDefinition]?
    let stream: Bool
    let maxTokens: Int?
    let temperature: Double?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case tools
        case stream
        case maxTokens = "max_tokens"
        case temperature
    }
}

// MARK: - Response Types

/// Response from chat completion
struct ChatCompletionResponse: Equatable {
    let id: String
    let content: String?
    let toolCalls: [OpenAIToolCall]?
    let finishReason: String?
    let usage: TokenUsage?
}

/// Token usage from API
struct TokenUsage: Codable, Equatable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Streaming Types

/// A chunk from streaming response
struct StreamingChunk: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [StreamingChoice]

    struct StreamingChoice: Codable {
        let index: Int
        let delta: StreamingDelta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct StreamingDelta: Codable {
        let role: OpenAIRole?
        let content: String?
        let toolCalls: [PartialToolCall]?

        enum CodingKeys: String, CodingKey {
            case role
            case content
            case toolCalls = "tool_calls"
        }
    }

    struct PartialToolCall: Codable {
        let index: Int
        let id: String?
        let type: String?
        let function: PartialFunctionCall?
    }

    struct PartialFunctionCall: Codable {
        let name: String?
        let arguments: String?
    }
}

// MARK: - Errors

/// Errors from OpenAI service
enum OpenAIError: Error, Equatable {
    case missingAPIKey
    case invalidURL
    case encodingError
    case decodingError(String)
    case httpError(statusCode: Int, message: String?)
    case rateLimited(retryAfter: TimeInterval?)
    case networkError(String)
    case serverError(statusCode: Int)
    case invalidResponse
    case cancelled
    case timeout
    case unknown(String)
}

// MARK: - API Error Response

struct OpenAIErrorResponse: Codable {
    let error: OpenAIAPIError
}

struct OpenAIAPIError: Codable {
    let message: String
    let type: String
    let code: String?
}

// MARK: - Helper Type

/// Type-erased Codable for flexible JSON
struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Simple equality for common types
        switch (lhs.value, rhs.value) {
        case let (l as String, r as String): return l == r
        case let (l as Int, r as Int): return l == r
        case let (l as Double, r as Double): return l == r
        case let (l as Bool, r as Bool): return l == r
        case is NSNull, is NSNull: return true
        default: return false
        }
    }
}
