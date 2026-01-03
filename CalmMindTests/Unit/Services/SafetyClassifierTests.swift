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

    // MARK: - Safe Messages (Most things should be SAFE)

    func test_classifies_greetings_safe() {
        let result = sut.classify("Hello, how are you?")
        XCTAssertEqual(result.level, .safe)
    }

    func test_classifies_positiveStatement_safe() {
        let result = sut.classify("I had a great day today!")
        XCTAssertEqual(result.level, .safe)
    }

    func test_classifies_anxiety_safe() {
        // Anxiety should be SAFE - the AI should engage with this
        let result = sut.classify("I'm having a lot of anxiety about my ex")
        XCTAssertEqual(result.level, .safe)
    }

    func test_classifies_breakup_safe() {
        let result = sut.classify("I just feel bad she's out of my life forever")
        XCTAssertEqual(result.level, .safe)
    }

    func test_classifies_sadness_safe() {
        let result = sut.classify("I've been feeling really sad lately")
        XCTAssertEqual(result.level, .safe)
    }

    func test_classifies_depression_safe() {
        // Depression discussion is SAFE - AI should help
        let result = sut.classify("I've been depressed for weeks")
        XCTAssertEqual(result.level, .safe)
    }

    func test_classifies_stress_safe() {
        let result = sut.classify("I'm really stressed about everything")
        XCTAssertEqual(result.level, .safe)
    }

    func test_classifies_loneliness_safe() {
        let result = sut.classify("I feel so alone and no one cares about me")
        XCTAssertEqual(result.level, .safe)
    }

    func test_classifies_hopelessness_safe() {
        // Even "hopeless" feeling is safe - not explicit self-harm
        let result = sut.classify("I feel hopeless about my situation")
        XCTAssertEqual(result.level, .safe)
    }

    func test_classifies_workStress_safe() {
        let result = sut.classify("Work is killing me, I have so many deadlines")
        XCTAssertEqual(result.level, .safe)
    }

    func test_classifies_relationship_safe() {
        let result = sut.classify("My relationship is falling apart")
        XCTAssertEqual(result.level, .safe)
    }

    func test_classifies_idiomaticDeath_safe() {
        // Idiomatic "want to die" should be safe
        let result = sut.classify("This exam makes me want to die lol")
        XCTAssertEqual(result.level, .safe)
    }

    // MARK: - Crisis Messages (ONLY explicit self-harm)

    func test_detectsCrisis_killMyself() {
        let result = sut.classify("I want to kill myself")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_goingToKillMyself() {
        let result = sut.classify("I'm going to kill myself tonight")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_endMyLife() {
        let result = sut.classify("I want to end my life")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_takeMyOwnLife() {
        let result = sut.classify("I'm going to take my own life")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_commitSuicide() {
        let result = sut.classify("I'm going to commit suicide")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_cuttingMyself() {
        let result = sut.classify("I've been cutting myself")
        XCTAssertEqual(result.level, .crisis)
    }

    func test_detectsCrisis_selfHarming() {
        let result = sut.classify("I've been self-harming")
        XCTAssertEqual(result.level, .crisis)
    }

    // MARK: - Exclusions (Past tense, hypothetical should NOT trigger crisis)

    func test_pastTense_isSafe() {
        // Discussing past should be safe even with crisis words
        let result = sut.classify("I used to think about suicide but I'm better now")
        XCTAssertEqual(result.level, .safe)
    }

    func test_hypothetical_isSafe() {
        let result = sut.classify("If someone wanted to kill themselves, what would you say?")
        XCTAssertEqual(result.level, .safe)
    }

    func test_movie_isSafe() {
        let result = sut.classify("In the movie, the character wanted to kill himself")
        XCTAssertEqual(result.level, .safe)
    }

    func test_negation_isSafe() {
        let result = sut.classify("I don't want to kill myself, I just want things to get better")
        XCTAssertEqual(result.level, .safe)
    }

    // MARK: - Edge Cases

    func test_emptyInput_returnsSafe() {
        let result = sut.classify("")
        XCTAssertEqual(result.level, .safe)
    }

    func test_whitespaceOnly_returnsSafe() {
        let result = sut.classify("   \n\t  ")
        XCTAssertEqual(result.level, .safe)
    }

    func test_crisis_returnsMatchedPatterns() {
        let result = sut.classify("I want to kill myself")
        XCTAssertEqual(result.level, .crisis)
        XCTAssertFalse(result.matchedPatterns.isEmpty)
    }

    func test_safe_hasNoMatchedPatterns() {
        let result = sut.classify("I had a great day!")
        XCTAssertEqual(result.level, .safe)
        XCTAssertTrue(result.matchedPatterns.isEmpty)
    }

    // MARK: - Determinism

    func test_sameInput_sameOutput() {
        let input = "I've been feeling down lately"
        let result1 = sut.classify(input)
        let result2 = sut.classify(input)
        XCTAssertEqual(result1.level, result2.level)
    }

    func test_caseInsensitive_crisis() {
        let result1 = sut.classify("I WANT TO KILL MYSELF")
        let result2 = sut.classify("i want to kill myself")
        let result3 = sut.classify("I Want To Kill Myself")

        XCTAssertEqual(result1.level, .crisis)
        XCTAssertEqual(result2.level, .crisis)
        XCTAssertEqual(result3.level, .crisis)
    }

    // MARK: - 30-Corpus Tests

    /// Non-crisis items (1-20) must NOT be classified as crisis
    func test_everydayDistress_notCrisis() {
        let nonCrisisCorpus = [
            // Relationship/Breakup (5)
            "I'm having anxiety about my ex",
            "I can't stop thinking about her",
            "I feel like she never really loved me",
            "My heart hurts so much right now",
            "I miss him more than I thought I would",

            // Stress/Overwhelm (5)
            "Idk, I'm just so stressed right now idk what to do",
            "I have so much work and I don't know where to start",
            "Everything feels like too much lately",
            "I'm drowning in responsibilities",
            "School is overwhelming me completely",

            // Loneliness/Isolation (5)
            "I feel like no one really cares about me",
            "I don't have anyone to talk to about this",
            "Everyone seems to have their life together except me",
            "I feel so alone even when I'm with people",
            "Nobody understands what I'm going through",

            // General Sadness/Down (5)
            "I've been feeling really down lately",
            "Some days I just don't want to get out of bed",
            "I don't know why I feel so sad",
            "Nothing feels exciting or fun anymore",
            "I just feel empty inside",
        ]

        for message in nonCrisisCorpus {
            let result = sut.classify(message)
            XCTAssertNotEqual(result.level, .crisis, "Should not be crisis: \(message)")
        }
    }

    /// Crisis items: ONLY self-harm with intent/plan/timeframe
    func test_selfHarmCrisis_areCrisis() {
        let selfHarmCrisis = [
            "I want to kill myself",
            "I'm going to end my life tonight",
            "I've been cutting myself",
            "I don't want to be alive anymore",
            "I have a plan to hurt myself",
            "I'm going to take all my pills",
            "Nobody would miss me if I was gone",
        ]

        for message in selfHarmCrisis {
            let result = sut.classify(message)
            XCTAssertEqual(result.level, .crisis, "Should be crisis: \(message)")
        }
    }

    /// Cautionary items: serious but not imminent self-harm
    /// These should NOT trigger crisis bypass - user wants practical help
    func test_dangerSituations_areCautionary() {
        let cautionaryCorpus = [
            "I want to hurt someone",           // vague anger - cautionary
            "My partner hits me",               // abuse - needs safety planning
            "I'm being stalked and I'm scared", // stalking - needs practical help
        ]

        for message in cautionaryCorpus {
            let result = sut.classify(message)
            XCTAssertEqual(result.level, .cautionary, "Should be cautionary: \(message)")
        }
    }
}
