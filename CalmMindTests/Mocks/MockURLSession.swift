import Foundation
@testable import CalmMind

/// Mock URLSession for testing network code without making real requests
final class MockURLSession: URLSessionProtocol, @unchecked Sendable {

    // MARK: - Configuration

    /// Data to return from requests
    var mockData: Data = Data()

    /// Status code to return
    var mockStatusCode: Int = 200

    /// Error to throw (if set, overrides data/status)
    var mockError: Error?

    /// Delay before returning (in seconds)
    var mockDelaySeconds: TimeInterval = 0

    /// Headers to include in response
    var mockHeaders: [String: String] = [:]

    // MARK: - Recording

    /// All requests made to this mock
    private(set) var recordedRequests: [URLRequest] = []

    /// Number of calls made
    var callCount: Int { recordedRequests.count }

    // MARK: - URLSessionProtocol

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        recordedRequests.append(request)

        // Simulate delay
        if mockDelaySeconds > 0 {
            try await Task.sleep(for: .seconds(mockDelaySeconds))
        }

        // Throw error if configured
        if let error = mockError {
            throw error
        }

        // Build response
        let url = request.url ?? URL(string: "https://mock.test")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: mockStatusCode,
            httpVersion: "HTTP/1.1",
            headerFields: mockHeaders
        )!

        return (mockData, response)
    }

    // MARK: - Helpers

    /// Resets all recorded state
    func reset() {
        recordedRequests = []
        mockError = nil
    }

    /// Convenience: Set JSON response data
    func setJSONResponse<T: Encodable>(_ value: T) throws {
        mockData = try JSONEncoder().encode(value)
        mockHeaders["Content-Type"] = "application/json"
    }

    /// Convenience: Get last request body as JSON
    func lastRequestJSON<T: Decodable>(as type: T.Type) throws -> T? {
        guard let body = recordedRequests.last?.httpBody else { return nil }
        return try JSONDecoder().decode(type, from: body)
    }
}
