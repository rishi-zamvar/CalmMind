import Foundation

/// Retry policy with exponential backoff for network requests
struct RetryPolicy {

    // MARK: - Configuration

    let maxAttempts: Int
    let baseDelaySeconds: TimeInterval
    let maxDelaySeconds: TimeInterval
    let jitterFactor: Double

    /// Status codes that are retryable
    private let retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]

    /// URL error codes that are retryable
    private let retryableErrorCodes: Set<Int> = [
        NSURLErrorTimedOut,
        NSURLErrorNetworkConnectionLost,
        NSURLErrorNotConnectedToInternet,
        NSURLErrorDNSLookupFailed,
        NSURLErrorCannotConnectToHost,
        NSURLErrorCannotFindHost
    ]

    /// URL error codes that should NOT be retried
    private let nonRetryableErrorCodes: Set<Int> = [
        NSURLErrorCancelled,
        NSURLErrorUserCancelledAuthentication,
        NSURLErrorUserAuthenticationRequired
    ]

    // MARK: - Initialization

    /// Creates a retry policy
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts (default 3)
    ///   - baseDelaySeconds: Base delay before first retry (default 1.0)
    ///   - maxDelaySeconds: Maximum delay cap (default 60.0)
    ///   - jitterFactor: Randomization factor 0-1 (default 0.25)
    init(
        maxAttempts: Int = 3,
        baseDelaySeconds: TimeInterval = 1.0,
        maxDelaySeconds: TimeInterval = 60.0,
        jitterFactor: Double = 0.25
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelaySeconds = baseDelaySeconds
        self.maxDelaySeconds = maxDelaySeconds
        self.jitterFactor = jitterFactor
    }

    // MARK: - Retry Decisions

    /// Determines if a request should be retried based on status code
    func shouldRetry(statusCode: Int, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        return retryableStatusCodes.contains(statusCode)
    }

    /// Determines if a request should be retried based on error
    func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }

        let nsError = error as NSError

        // Check if explicitly non-retryable
        if nsError.domain == NSURLErrorDomain && nonRetryableErrorCodes.contains(nsError.code) {
            return false
        }

        // Check if retryable error code
        if nsError.domain == NSURLErrorDomain && retryableErrorCodes.contains(nsError.code) {
            return true
        }

        return false
    }

    // MARK: - Backoff Calculation

    /// Calculates the delay for a given attempt number (1-indexed)
    func delayForAttempt(_ attempt: Int) -> TimeInterval {
        // Exponential backoff: baseDelay * 2^(attempt-1)
        let exponentialDelay = baseDelaySeconds * pow(2.0, Double(attempt - 1))

        // Apply max cap
        let cappedDelay = min(exponentialDelay, maxDelaySeconds)

        // Apply jitter
        if jitterFactor > 0 {
            let jitterRange = cappedDelay * jitterFactor
            let jitter = Double.random(in: -jitterRange...jitterRange)
            return max(0, cappedDelay + jitter)
        }

        return cappedDelay
    }
}
