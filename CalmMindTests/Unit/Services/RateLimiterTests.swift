import XCTest
@testable import CalmMind

final class RateLimiterTests: XCTestCase {

    var sut: RateLimiter!

    override func setUp() {
        super.setUp()
        // Default: 60 requests per minute
        sut = RateLimiter(maxRequestsPerMinute: 60)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Basic Operation

    func test_allowsRequestUnderLimit() async {
        let allowed = await sut.shouldAllowRequest()

        XCTAssertTrue(allowed)
    }

    func test_blocksRequestOverLimit() async {
        // Use a small limit for testing
        sut = RateLimiter(maxRequestsPerMinute: 3)

        // Make 3 requests (should all succeed)
        for _ in 0..<3 {
            let _ = await sut.shouldAllowRequest()
            await sut.recordRequest()
        }

        // 4th request should be blocked
        let allowed = await sut.shouldAllowRequest()
        XCTAssertFalse(allowed)
    }

    func test_refillsTokensOverTime() async {
        sut = RateLimiter(maxRequestsPerMinute: 60) // 1 per second refill

        // Exhaust tokens
        for _ in 0..<60 {
            await sut.recordRequest()
        }

        // Should be blocked
        var allowed = await sut.shouldAllowRequest()
        XCTAssertFalse(allowed)

        // Wait for tokens to refill (simulate time passing)
        await sut.simulateTimePassage(seconds: 2)

        // Should be allowed again
        allowed = await sut.shouldAllowRequest()
        XCTAssertTrue(allowed)
    }

    // MARK: - Configuration

    func test_respectsMaxRequestsPerMinute() async {
        sut = RateLimiter(maxRequestsPerMinute: 10)

        // Make 10 requests
        for _ in 0..<10 {
            await sut.recordRequest()
        }

        // 11th should be blocked
        let allowed = await sut.shouldAllowRequest()
        XCTAssertFalse(allowed)
    }

    func test_respectsCooldownAfter429() async {
        sut = RateLimiter(maxRequestsPerMinute: 60, cooldownAfter429Seconds: 5)

        // Trigger 429 cooldown
        await sut.trigger429Cooldown()

        // Should be blocked during cooldown
        let allowed = await sut.shouldAllowRequest()
        XCTAssertFalse(allowed)
    }

    func test_cooldownExpires() async {
        sut = RateLimiter(maxRequestsPerMinute: 60, cooldownAfter429Seconds: 2)

        // Trigger 429 cooldown
        await sut.trigger429Cooldown()

        // Wait for cooldown to expire
        await sut.simulateTimePassage(seconds: 3)

        // Should be allowed again
        let allowed = await sut.shouldAllowRequest()
        XCTAssertTrue(allowed)
    }

    // MARK: - Concurrency

    func test_threadSafe_concurrentRequests() async {
        sut = RateLimiter(maxRequestsPerMinute: 100)

        // Perform concurrent requests
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    let _ = await self.sut.shouldAllowRequest()
                    await self.sut.recordRequest()
                }
            }
        }

        // Should still function correctly after concurrent access
        let tokenCount = await sut.availableTokens
        XCTAssertEqual(tokenCount, 50) // 100 - 50 = 50 remaining
    }

    // MARK: - Wait Time

    func test_returnsWaitTime_whenBlocked() async {
        sut = RateLimiter(maxRequestsPerMinute: 60)

        // Exhaust tokens
        for _ in 0..<60 {
            await sut.recordRequest()
        }

        let waitTime = await sut.waitTimeUntilNextRequest()
        XCTAssertGreaterThan(waitTime, 0)
        XCTAssertLessThanOrEqual(waitTime, 1.0) // Should refill within 1 second
    }

    func test_returnsZeroWaitTime_whenAllowed() async {
        let waitTime = await sut.waitTimeUntilNextRequest()

        XCTAssertEqual(waitTime, 0)
    }

    // MARK: - Token Count

    func test_initialTokenCount_equalsMax() async {
        sut = RateLimiter(maxRequestsPerMinute: 30)

        let tokens = await sut.availableTokens
        XCTAssertEqual(tokens, 30)
    }

    func test_recordRequest_decrementsTokens() async {
        sut = RateLimiter(maxRequestsPerMinute: 10)

        await sut.recordRequest()

        let tokens = await sut.availableTokens
        XCTAssertEqual(tokens, 9)
    }
}
