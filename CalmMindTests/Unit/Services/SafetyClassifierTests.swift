import XCTest
@testable import CalmMind

final class SafetyClassifierTests: XCTestCase {

    var sut: SafetyClassifier!

    override func setUp() {
        super.setUp()
        sut = SafetyClassifier()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Classification Levels

    func test_classifies_safe() {
        let result = sut.classify("I had a great day today!")
        XCTAssertEqual(result.level, .safe)
    }

    func test_classifies_cautionary() {
        let result = sut.classify("I've been feeling really down lately")
        XCTAssertEqual(result.level, .cautionary)
    }

    func test_classifies_crisis() {
        let result = sut.classify("I want to end my life")
        XCTAssertEqual(result.level, .crisis)
    }

    // MARK: - Crisis Detection - Direct Statements

    func test_detectsCrisis_suicidalIdeation() {
        let result = sut.classify("I've been thinking about suicide")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_selfHarmMention() {
        let result = sut.classify("I've been hurting myself")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_hopelessnessIndicators() {
        let result = sut.classify("There's no point in living anymore")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_emergencyKeywords() {
        let result = sut.classify("I'm going to kill myself tonight")
        XCTAssertEqual(result.level, .crisis)
    }

    // MARK: - Crisis Detection - Variants (Must Not Miss)

    func test_detectsCrisis_variant_wantToDie() {
        let result = sut.classify("I just want to die")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_variant_endItAll() {
        let result = sut.classify("I want to end it all")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_variant_noPointLiving() {
        let result = sut.classify("There's no point in living")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_variant_cuttingMyself() {
        let result = sut.classify("I've been cutting myself")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_variant_overdose() {
        let result = sut.classify("I'm thinking about taking all my pills")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_variant_betterOffWithoutMe() {
        let result = sut.classify("Everyone would be better off without me")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_variant_givingAwayPossessions() {
        let result = sut.classify("I'm giving away all my things, I won't need them")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_variant_cannotGoOn() {
        let result = sut.classify("I can't go on anymore")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_variant_noReasonToLive() {
        let result = sut.classify("I have no reason to live")
        XCTAssertEqual(result.level, .crisis)
    }

    // MARK: - False Positives (Should NOT Trigger Crisis)

    func test_doesNotTrigger_discussingPastCrisis() {
        // Past tense discussion should be cautionary, not crisis
        let result = sut.classify("I used to have suicidal thoughts but I'm better now")
        XCTAssertNotEqual(result.level, .crisis)
    }

    func test_doesNotTrigger_hypothetical() {
        let result = sut.classify("If someone were suicidal, what would you tell them?")
        XCTAssertNotEqual(result.level, .crisis)
    }

    func test_doesNotTrigger_movieReference() {
        let result = sut.classify("I watched a movie about suicide prevention")
        XCTAssertNotEqual(result.level, .crisis)
    }

    func test_doesNotTrigger_songLyrics() {
        let result = sut.classify("That song lyrics say 'kill me softly'")
        XCTAssertNotEqual(result.level, .crisis)
    }

    func test_doesNotTrigger_metaphoricalDeath() {
        let result = sut.classify("This work is killing me")
        XCTAssertNotEqual(result.level, .crisis)
    }

    func test_doesNotTrigger_videogame() {
        let result = sut.classify("I died in the game and had to restart")
        XCTAssertNotEqual(result.level, .crisis)
    }

    // MARK: - Cautionary Detection

    func test_detectsCautionary_feelingHopeless() {
        let result = sut.classify("I feel hopeless")
        XCTAssertEqual(result.level, .cautionary)
    }

    func test_detectsCautionary_overwhelmed() {
        let result = sut.classify("I'm so overwhelmed I don't know what to do")
        XCTAssertEqual(result.level, .cautionary)
    }

    func test_detectsCautionary_worthless() {
        let result = sut.classify("I feel worthless")
        XCTAssertEqual(result.level, .cautionary)
    }

    func test_detectsCautionary_depressed() {
        let result = sut.classify("I've been depressed for weeks")
        XCTAssertEqual(result.level, .cautionary)
    }

    func test_detectsCautionary_anxious() {
        let result = sut.classify("My anxiety is out of control")
        XCTAssertEqual(result.level, .cautionary)
    }

    // MARK: - Safe Messages

    func test_detectsSafe_greeting() {
        let result = sut.classify("Hello, how are you?")
        XCTAssertEqual(result.level, .safe)
    }

    func test_detectsSafe_positiveStatement() {
        let result = sut.classify("I'm feeling great today!")
        XCTAssertEqual(result.level, .safe)
    }

    func test_detectsSafe_neutralStatement() {
        let result = sut.classify("I went to the store today")
        XCTAssertEqual(result.level, .safe)
    }

    func test_detectsSafe_workDiscussion() {
        let result = sut.classify("I have a meeting tomorrow at 3pm")
        XCTAssertEqual(result.level, .safe)
    }

    // MARK: - Determinism

    func test_sameInput_sameOutput() {
        let input = "I've been feeling down lately"
        let result1 = sut.classify(input)
        let result2 = sut.classify(input)
        XCTAssertEqual(result1.level, result2.level)
    }

    func test_noExternalDependencies() {
        // SafetyClassifier should work without network or other services
        let classifier1 = SafetyClassifier()
        let classifier2 = SafetyClassifier()
        let input = "I want to end my life"

        let result1 = classifier1.classify(input)
        let result2 = classifier2.classify(input)

        XCTAssertEqual(result1.level, result2.level)
        XCTAssertEqual(result1.level, .crisis)
    }

    // MARK: - Case Insensitivity

    func test_caseInsensitive_crisis() {
        let result1 = sut.classify("I WANT TO DIE")
        let result2 = sut.classify("i want to die")
        let result3 = sut.classify("I Want To Die")

        XCTAssertEqual(result1.level, .crisis)
        XCTAssertEqual(result2.level, .crisis)
        XCTAssertEqual(result3.level, .crisis)
    }

    // MARK: - Empty/Edge Cases

    func test_emptyInput_returnsSafe() {
        let result = sut.classify("")
        XCTAssertEqual(result.level, .safe)
    }

    func test_whitespaceOnly_returnsSafe() {
        let result = sut.classify("   \n\t  ")
        XCTAssertEqual(result.level, .safe)
    }

    // MARK: - Matched Keywords

    func test_crisis_returnsMatchedKeywords() {
        let result = sut.classify("I want to kill myself")
        XCTAssertEqual(result.level, .crisis)
        XCTAssertFalse(result.matchedPatterns.isEmpty)
    }

    func test_safe_hasNoMatchedKeywords() {
        let result = sut.classify("I had a great day!")
        XCTAssertEqual(result.level, .safe)
        XCTAssertTrue(result.matchedPatterns.isEmpty)
    }
}
