import Foundation

/// Result of tool validation
struct ToolValidationResult: Sendable {
    /// Whether the tool call is valid
    let isValid: Bool

    /// Error message if invalid
    let error: String?

    /// Sanitized arguments (if valid)
    let sanitizedArguments: [String: Any]?

    static func valid(arguments: [String: Any]) -> ToolValidationResult {
        ToolValidationResult(isValid: true, error: nil, sanitizedArguments: arguments)
    }

    static func invalid(_ error: String) -> ToolValidationResult {
        ToolValidationResult(isValid: false, error: error, sanitizedArguments: nil)
    }
}

/// Validates tool calls before execution
final class ToolValidator: Sendable {

    // MARK: - Dependencies

    private let registry: ToolRegistry

    // MARK: - Initialization

    init(registry: ToolRegistry) {
        self.registry = registry
    }

    // MARK: - Validation

    /// Validate a tool call
    func validate(toolName: String, arguments: [String: Any]) -> ToolValidationResult {
        // Check for empty tool name
        guard !toolName.isEmpty else {
            return .invalid("Tool name cannot be empty")
        }

        // Check if tool exists
        guard let tool = registry.tool(named: toolName) else {
            return .invalid("Unknown tool: \(toolName)")
        }

        // Check required parameters
        for required in tool.requiredParams {
            if arguments[required] == nil {
                return .invalid("Missing required parameter: \(required)")
            }
        }

        // Validate parameter types
        for (key, value) in arguments {
            if let expectedType = tool.paramTypes[key] {
                if !validateType(value: value, expectedType: expectedType) {
                    return .invalid("Invalid type for parameter '\(key)': expected \(expectedType)")
                }
            }
        }

        // Sanitize and return
        let sanitized = sanitizeArguments(arguments)
        return .valid(arguments: sanitized)
    }

    /// Parse JSON string to arguments dictionary
    func parseArguments(_ json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8) else {
            return nil
        }

        do {
            let result = try JSONSerialization.jsonObject(with: data, options: [])
            return result as? [String: Any]
        } catch {
            return nil
        }
    }

    // MARK: - Private

    private func validateType(value: Any, expectedType: ToolDefinition.ParameterType) -> Bool {
        switch expectedType {
        case .string:
            return value is String
        case .integer:
            return value is Int || value is Double
        case .boolean:
            return value is Bool
        case .array:
            return value is [Any]
        }
    }

    private func sanitizeArguments(_ arguments: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]

        for (key, value) in arguments {
            if let stringValue = value as? String {
                // Basic sanitization - remove potential script tags
                sanitized[key] = sanitizeString(stringValue)
            } else {
                sanitized[key] = value
            }
        }

        return sanitized
    }

    private func sanitizeString(_ input: String) -> String {
        // Remove script tags and other potentially dangerous content
        var result = input
        result = result.replacingOccurrences(of: "<script", with: "", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</script>", with: "", options: .caseInsensitive)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
