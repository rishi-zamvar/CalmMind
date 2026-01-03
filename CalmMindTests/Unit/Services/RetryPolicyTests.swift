import XCTest
@testable import CalmMind

final class RetryPolicyTests: XCTestCase {

    var sut: RetryPolicy!

    override func setUp() {
        super.setUp()
        sut = RetryPolicy()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Retry Decisions

    func test_shouldRetry_on429() {
        let result = sut.shouldRetry(statusCode: 429, attempt: 1)

        XCTAssertTrue(result)
    }

    func test_shouldRetry_on503() {
        let result = sut.shouldRetry(statusCode: 503, attempt: 1)

        XCTAssertTrue(result)
    }

    func test_shouldRetry_on500() {
        let result = sut.shouldRetry(statusCode: 500, attempt: 1)

        XCTAssertTrue(result)
    }

    func test_shouldRetry_on502() {
        let result = sut.shouldRetry(statusCode: 502, attempt: 1)

        XCTAssertTrue(result)
    }

    func test_shouldRetry_onNetworkTimeout() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        let result = sut.shouldRetry(error: error, attempt: 1)

        XCTAssertTrue(result)
    }

    func test_shouldRetry_onNetworkConnectionLost() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost, userInfo: nil)
        let result = sut.shouldRetry(error: error, attempt: 1)

        XCTAssertTrue(result)
    }

    func test_shouldNotRetry_on400() {
        let result = sut.shouldRetry(statusCode: 400, attempt: 1)

        XCTAssertFalse(result)
    }

    func test_shouldNotRetry_on401() {
        let result = sut.shouldRetry(statusCode: 401, attempt: 1)

        XCTAssertFalse(result)
    }

    func test_shouldNotRetry_on403() {
        let result = sut.shouldRetry(statusCode: 403, attempt: 1)

        XCTAssertFalse(result)
    }

    func test_shouldNotRetry_on404() {
        let result = sut.shouldRetry(statusCode: 404, attempt: 1)

        XCTAssertFalse(result)
    }

    func test_shouldNotRetry_afterMaxAttempts() {
        sut = RetryPolicy(maxAttempts: 3)

        let result = sut.shouldRetry(statusCode: 429, attempt: 3)

        XCTAssertFalse(result)
    }

    func test_shouldRetry_beforeMaxAttempts() {
        sut = RetryPolicy(maxAttempts: 3)

        let result = sut.shouldRetry(statusCode: 429, attempt: 2)

        XCTAssertTrue(result)
    }

    // MARK: - Backoff

    func test_backoff_increasesExponentially() {
        let delay1 = sut.delayForAttempt(1)
        let delay2 = sut.delayForAttempt(2)
        let delay3 = sut.delayForAttempt(3)

        XCTAssertLessThan(delay1, delay2)
        XCTAssertLessThan(delay2, delay3)
    }

    func test_backoff_firstAttemptBaseDelay() {
        sut = RetryPolicy(baseDelaySeconds: 1.0, maxDelaySeconds: 60.0, jitterFactor: 0)

        let delay = sut.delayForAttempt(1)

        // First attempt should be close to base delay
        XCTAssertEqual(delay, 1.0, accuracy: 0.01)
    }

    func test_backoff_secondAttemptDouble() {
        sut = RetryPolicy(baseDelaySeconds: 1.0, maxDelaySeconds: 60.0, jitterFactor: 0)

        let delay = sut.delayForAttempt(2)

        // 2^(2-1) = 2
        XCTAssertEqual(delay, 2.0, accuracy: 0.01)
    }

    func test_backoff_includesJitter() {
        sut = RetryPolicy(baseDelaySeconds: 1.0, maxDelaySeconds: 60.0, jitterFactor: 0.5)

        // Get multiple delays for the same attempt
        var delays: [TimeInterval] = []
        for _ in 0..<10 {
            delays.append(sut.delayForAttempt(1))
        }

        // With jitter, not all delays should be identical
        let uniqueDelays = Set(delays)
        XCTAssertGreaterThan(uniqueDelays.count, 1)
    }

    func test_backoff_cappedAtMaxDelay() {
        sut = RetryPolicy(baseDelaySeconds: 1.0, maxDelaySeconds: 10.0, jitterFactor: 0)

        // Very high attempt number should still be capped
        let delay = sut.delayForAttempt(100)

        XCTAssertLessThanOrEqual(delay, 10.0)
    }

    // MARK: - Max Attempts

    func test_maxAttempts_defaultsTo3() {
        XCTAssertEqual(sut.maxAttempts, 3)
    }

    func test_maxAttempts_customizable() {
        sut = RetryPolicy(maxAttempts: 5)

        XCTAssertEqual(sut.maxAttempts, 5)
    }

    // MARK: - Retryable Errors

    func test_notRetryable_cancelledError() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil)
        let result = sut.shouldRetry(error: error, attempt: 1)

        XCTAssertFalse(result)
    }

    func test_retryable_notConnectedToInternet() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        let result = sut.shouldRetry(error: error, attempt: 1)

        XCTAssertTrue(result)
    }
}
