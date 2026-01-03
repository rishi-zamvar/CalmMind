import Foundation

/// Token bucket rate limiter for API requests
actor RateLimiter {

    // MARK: - Configuration

    private let maxTokens: Int
    private let refillRate: Double // tokens per second
    private let cooldownDuration: TimeInterval

    // MARK: - State

    private var tokens: Int
    private var lastRefillTime: Date
    private var cooldownUntil: Date?

    /// For testing: allows simulating time passage
    private var simulatedTimeOffset: TimeInterval = 0

    // MARK: - Initialization

    /// Creates a rate limiter
    /// - Parameters:
    ///   - maxRequestsPerMinute: Maximum requests allowed per minute
    ///   - cooldownAfter429Seconds: Cooldown duration after receiving 429 response
    init(maxRequestsPerMinute: Int, cooldownAfter429Seconds: TimeInterval = 60) {
        self.maxTokens = maxRequestsPerMinute
        self.refillRate = Double(maxRequestsPerMinute) / 60.0 // tokens per second
        self.cooldownDuration = cooldownAfter429Seconds
        self.tokens = maxRequestsPerMinute
        self.lastRefillTime = Date()
        self.cooldownUntil = nil
    }

    // MARK: - Public Interface

    /// Checks if a request should be allowed (without consuming a token)
    var availableTokens: Int {
        refillTokens()
        return tokens
    }

    /// Checks if a request should be allowed
    func shouldAllowRequest() -> Bool {
        // Check cooldown first
        if let cooldown = cooldownUntil {
            if currentTime < cooldown {
                return false
            } else {
                cooldownUntil = nil
            }
        }

        refillTokens()
        return tokens > 0
    }

    /// Records a request (consumes a token)
    func recordRequest() {
        refillTokens()
        if tokens > 0 {
            tokens -= 1
        }
    }

    /// Triggers a cooldown period after receiving a 429 response
    func trigger429Cooldown() {
        cooldownUntil = currentTime.addingTimeInterval(cooldownDuration)
    }

    /// Returns the time to wait until the next request can be made
    func waitTimeUntilNextRequest() -> TimeInterval {
        // Check cooldown first
        if let cooldown = cooldownUntil {
            let remaining = cooldown.timeIntervalSince(currentTime)
            if remaining > 0 {
                return remaining
            }
        }

        refillTokens()

        if tokens > 0 {
            return 0
        }

        // Calculate time until next token
        return 1.0 / refillRate
    }

    // MARK: - Testing Support

    /// For testing: simulates time passage
    func simulateTimePassage(seconds: TimeInterval) {
        simulatedTimeOffset += seconds
    }

    /// Resets the simulated time offset (for testing)
    func resetSimulatedTime() {
        simulatedTimeOffset = 0
    }

    // MARK: - Private

    private var currentTime: Date {
        Date().addingTimeInterval(simulatedTimeOffset)
    }

    private func refillTokens() {
        let now = currentTime
        let elapsed = now.timeIntervalSince(lastRefillTime)

        if elapsed > 0 {
            let tokensToAdd = Int(elapsed * refillRate)
            if tokensToAdd > 0 {
                tokens = min(maxTokens, tokens + tokensToAdd)
                lastRefillTime = now
            }
        }
    }
}
