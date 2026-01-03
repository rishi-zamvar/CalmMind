import Foundation

/// Helper to get API keys for live integration tests
/// Priority: 1) Environment variable 2) xcconfig file 3) nil (skip test)
enum TestSecrets {

    /// Get OpenAI API key for live testing
    /// Returns nil if no key is configured (test should be skipped)
    static var openAIAPIKey: String? {
        // 1. Try environment variable (set in Xcode scheme or CI)
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           !envKey.isEmpty,
           envKey != "sk-your-key-here" {
            return envKey
        }

        // 2. Try xcconfig file (local development)
        if let key = readFromXCConfig() {
            return key
        }

        return nil
    }

    /// Whether live tests should run
    static var shouldRunLiveTests: Bool {
        openAIAPIKey != nil
    }

    /// Skips test if no API key is configured
    static func skipIfNoAPIKey() throws {
        if openAIAPIKey == nil {
            throw XCTSkip("No OpenAI API key configured. Set OPENAI_API_KEY environment variable or create Config/Secrets.xcconfig")
        }
    }

    // MARK: - Private

    private static func readFromXCConfig() -> String? {
        // Get path to xcconfig file
        let bundle = Bundle(for: BundleToken.self)
        guard let projectPath = bundle.resourcePath?
            .components(separatedBy: "/Build/")
            .first else {
            return nil
        }

        let configPath = (projectPath as NSString)
            .appendingPathComponent("Config/Secrets.xcconfig")

        guard FileManager.default.fileExists(atPath: configPath),
              let contents = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return nil
        }

        // Parse xcconfig format: KEY = value
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("OPENAI_API_KEY") {
                let parts = trimmed.components(separatedBy: "=")
                if parts.count >= 2 {
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty && value != "sk-your-key-here" {
                        return value
                    }
                }
            }
        }

        return nil
    }
}

// Helper class to get bundle
private class BundleToken {}

import XCTest
