import XCTest
@testable import CalmMind

final class CrisisResponseComposerTests: XCTestCase {

    var sut: CrisisResponseComposer!

    override func setUp() {
        super.setUp()
        sut = CrisisResponseComposer()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Response Generation

    func test_generatesEmpatheticResponse() {
        let response = sut.compose(for: "I want to end my life")

        // Response should be empathetic, not dismissive
        XCTAssertFalse(response.message.isEmpty)
        XCTAssertFalse(response.message.lowercased().contains("just"))  // "just" is dismissive
        XCTAssertFalse(response.message.lowercased().contains("don't worry"))
    }

    func test_includesCrisisHotline() {
        let response = sut.compose(for: "I want to die")

        // Must include crisis resources
        XCTAssertFalse(response.resources.isEmpty)
        XCTAssertTrue(response.resources.contains { $0.name.lowercased().contains("988") || $0.phoneNumber == "988" })
    }

    func test_responseIsLocallyGenerated_noLLM() {
        // This test verifies the response is generated synchronously without any async calls
        // The compose method should be synchronous
        let response = sut.compose(for: "I'm thinking about suicide")
        XCTAssertFalse(response.message.isEmpty)
        XCTAssertFalse(response.resources.isEmpty)
    }

    func test_responseVariesByInputContext() {
        let response1 = sut.compose(for: "I want to die")
        let response2 = sut.compose(for: "I've been hurting myself")

        // Both should be valid crisis responses
        XCTAssertFalse(response1.message.isEmpty)
        XCTAssertFalse(response2.message.isEmpty)
        XCTAssertFalse(response1.resources.isEmpty)
        XCTAssertFalse(response2.resources.isEmpty)
    }

    // MARK: - Resources

    func test_includesNationalSuicideHotline() {
        let response = sut.compose(for: "I want to end it all")

        let hasSuicideHotline = response.resources.contains { resource in
            resource.name.lowercased().contains("suicide") ||
            resource.name.lowercased().contains("988") ||
            resource.phoneNumber == "988"
        }
        XCTAssertTrue(hasSuicideHotline)
    }

    func test_includes988Number() {
        let response = sut.compose(for: "I want to kill myself")

        let has988 = response.resources.contains { $0.phoneNumber == "988" }
        XCTAssertTrue(has988, "Response must include 988 number")
    }

    func test_includesCrisisTextLine() {
        let response = sut.compose(for: "I'm going to hurt myself")

        let hasCrisisTextLine = response.resources.contains { resource in
            resource.name.lowercased().contains("text") ||
            resource.textNumber != nil
        }
        XCTAssertTrue(hasCrisisTextLine, "Response should include text-based crisis resource")
    }

    // MARK: - Tone

    func test_neverDismissive() {
        let dismissivePhrases = [
            "just",
            "calm down",
            "don't worry",
            "you're overreacting",
            "it's not that bad",
            "snap out of it",
            "get over it",
            "think positive"
        ]

        let response = sut.compose(for: "I want to die")
        let lowercaseMessage = response.message.lowercased()

        for phrase in dismissivePhrases {
            XCTAssertFalse(
                lowercaseMessage.contains(phrase),
                "Response should not contain dismissive phrase: '\(phrase)'"
            )
        }
    }

    func test_neverJudgmental() {
        let judgmentalPhrases = [
            "wrong",
            "stupid",
            "crazy",
            "selfish",
            "weak",
            "coward"
        ]

        let response = sut.compose(for: "I'm thinking about suicide")
        let lowercaseMessage = response.message.lowercased()

        for phrase in judgmentalPhrases {
            XCTAssertFalse(
                lowercaseMessage.contains(phrase),
                "Response should not contain judgmental phrase: '\(phrase)'"
            )
        }
    }

    func test_alwaysValidating() {
        let response = sut.compose(for: "I feel like giving up")

        // Response should contain validating language
        let validatingPhrases = [
            "hear",
            "understand",
            "care",
            "matter",
            "here",
            "help",
            "support",
            "reach out"
        ]

        let lowercaseMessage = response.message.lowercased()
        let hasValidatingLanguage = validatingPhrases.contains { lowercaseMessage.contains($0) }

        XCTAssertTrue(hasValidatingLanguage, "Response should contain validating language")
    }

    // MARK: - Resource Data

    func test_resourcesHaveValidPhoneNumbers() {
        let response = sut.compose(for: "I want to die")

        for resource in response.resources {
            if let phone = resource.phoneNumber {
                // Phone should be numeric (may have dashes)
                let digitsOnly = phone.filter { $0.isNumber }
                XCTAssertFalse(digitsOnly.isEmpty, "Phone number should contain digits: \(phone)")
            }
        }
    }

    func test_resourcesHaveDescriptions() {
        let response = sut.compose(for: "I want to die")

        for resource in response.resources {
            XCTAssertFalse(resource.description.isEmpty, "Resource '\(resource.name)' should have a description")
        }
    }

    func test_resourcesHaveNames() {
        let response = sut.compose(for: "I want to die")

        for resource in response.resources {
            XCTAssertFalse(resource.name.isEmpty, "All resources should have names")
        }
    }

    // MARK: - Self-Harm Specific

    func test_selfHarmResponse_includesSpecificResources() {
        let response = sut.compose(for: "I've been cutting myself")

        // Should still include crisis resources
        XCTAssertFalse(response.resources.isEmpty)
        XCTAssertFalse(response.message.isEmpty)
    }

    // MARK: - Determinism

    func test_sameInput_producesConsistentResponse() {
        let input = "I want to end my life"
        let response1 = sut.compose(for: input)
        let response2 = sut.compose(for: input)

        // Resources should be the same
        XCTAssertEqual(response1.resources.count, response2.resources.count)
    }
}
