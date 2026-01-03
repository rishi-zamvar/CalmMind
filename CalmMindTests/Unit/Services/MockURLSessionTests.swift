import XCTest
@testable import CalmMind

final class MockURLSessionTests: XCTestCase {

    var sut: MockURLSession!

    override func setUp() {
        super.setUp()
        sut = MockURLSession()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Configured Response

    func test_mockSession_returnsConfiguredResponse() async throws {
        let responseData = "Hello, World!".data(using: .utf8)!
        sut.mockData = responseData
        sut.mockStatusCode = 200

        let request = URLRequest(url: URL(string: "https://api.openai.com/test")!)
        let (data, response) = try await sut.data(for: request)

        XCTAssertEqual(data, responseData)
        let httpResponse = response as? HTTPURLResponse
        XCTAssertEqual(httpResponse?.statusCode, 200)
    }

    func test_mockSession_returnsCustomStatusCode() async throws {
        sut.mockData = Data()
        sut.mockStatusCode = 429

        let request = URLRequest(url: URL(string: "https://api.openai.com/test")!)
        let (_, response) = try await sut.data(for: request)

        let httpResponse = response as? HTTPURLResponse
        XCTAssertEqual(httpResponse?.statusCode, 429)
    }

    // MARK: - Error Simulation

    func test_mockSession_canSimulateError() async {
        let expectedError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        sut.mockError = expectedError

        let request = URLRequest(url: URL(string: "https://api.openai.com/test")!)

        do {
            let _ = try await sut.data(for: request)
            XCTFail("Expected error to be thrown")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, NSURLErrorNotConnectedToInternet)
        }
    }

    // MARK: - Delay Simulation

    func test_mockSession_canSimulateDelay() async throws {
        sut.mockData = Data()
        sut.mockStatusCode = 200
        sut.mockDelaySeconds = 0.1

        let request = URLRequest(url: URL(string: "https://api.openai.com/test")!)
        let startTime = Date()

        let _ = try await sut.data(for: request)

        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertGreaterThanOrEqual(elapsed, 0.1)
    }

    // MARK: - Request Recording

    func test_mockSession_recordsRequests() async throws {
        sut.mockData = Data()
        sut.mockStatusCode = 200

        var request1 = URLRequest(url: URL(string: "https://api.openai.com/v1/chat")!)
        request1.httpMethod = "POST"
        request1.httpBody = "test body".data(using: .utf8)

        var request2 = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request2.httpMethod = "GET"

        let _ = try await sut.data(for: request1)
        let _ = try await sut.data(for: request2)

        XCTAssertEqual(sut.recordedRequests.count, 2)
        XCTAssertEqual(sut.recordedRequests[0].url?.path, "/v1/chat")
        XCTAssertEqual(sut.recordedRequests[1].url?.path, "/v1/models")
    }

    func test_mockSession_recordsRequestHeaders() async throws {
        sut.mockData = Data()
        sut.mockStatusCode = 200

        var request = URLRequest(url: URL(string: "https://api.openai.com/test")!)
        request.setValue("Bearer sk-test", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let _ = try await sut.data(for: request)

        XCTAssertEqual(sut.recordedRequests[0].value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
        XCTAssertEqual(sut.recordedRequests[0].value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    // MARK: - Call Count

    func test_mockSession_tracksCallCount() async throws {
        sut.mockData = Data()
        sut.mockStatusCode = 200

        let request = URLRequest(url: URL(string: "https://api.openai.com/test")!)

        let _ = try await sut.data(for: request)
        let _ = try await sut.data(for: request)
        let _ = try await sut.data(for: request)

        XCTAssertEqual(sut.callCount, 3)
    }

    // MARK: - Reset

    func test_mockSession_canBeReset() async throws {
        sut.mockData = "initial".data(using: .utf8)!
        sut.mockStatusCode = 200

        let request = URLRequest(url: URL(string: "https://api.openai.com/test")!)
        let _ = try await sut.data(for: request)

        sut.reset()

        XCTAssertEqual(sut.callCount, 0)
        XCTAssertTrue(sut.recordedRequests.isEmpty)
    }
}
