import Foundation
import XCTest
@testable import BuySellAI

final class AccountClientTests: XCTestCase {
    override func tearDown() {
        AccountMockURLProtocol.handler = nil
        super.tearDown()
    }

    func testDeleteAccountBuildsSupabaseFunctionRequest() async throws {
        let client = try makeClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/delete-account")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertTrue(json.isEmpty)

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        try await client.deleteAccount(accessToken: "access-token")
    }

    func testDeleteAccountMapsRateLimitToFriendlyError() async {
        let client: AccountClient
        do {
            client = try makeClient { request in
                let response = try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 429,
                    httpVersion: nil,
                    headerFields: nil
                ))
                return (response, Data())
            }
        } catch {
            XCTFail("Could not make client: \(error)")
            return
        }

        do {
            try await client.deleteAccount(accessToken: "access-token")
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(error as? APIError, .rateLimited)
        }
    }

    func testDeleteAccountTimeoutMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.timedOut)
        }

        do {
            try await client.deleteAccount(accessToken: "access-token")
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }

    func testDeleteAccountOfflineMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            try await client.deleteAccount(accessToken: "access-token")
            XCTFail("Expected offline error")
        } catch {
            XCTAssertEqual(error as? APIError, .offline)
        }
    }

    func testDeleteAccountUnauthorizedStatusMapsToSessionExpiredError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 403,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            try await client.deleteAccount(accessToken: "access-token")
            XCTFail("Expected session expired error")
        } catch {
            XCTAssertEqual(error as? APIError, .sessionExpired)
        }
    }

    func testDeleteAccountTransientServerErrorRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: attempts == 1 ? 503 : 204,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        try await client.deleteAccount(accessToken: "access-token")

        XCTAssertEqual(attempts, 2)
    }

    func testDeleteAccountNetworkConnectionLostRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            if attempts == 1 {
                throw URLError(.networkConnectionLost)
            }

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        try await client.deleteAccount(accessToken: "access-token")

        XCTAssertEqual(attempts, 2)
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) throws -> AccountClient {
        AccountMockURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AccountMockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration)
        let url = try XCTUnwrap(URL(string: "https://example.supabase.co"))
        let config = AppConfig(supabaseURL: url, anonKey: "anon-test-key")
        return AccountClient(session: session, config: config)
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let httpBody = request.httpBody {
            return httpBody
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count < 0 {
                return nil
            }
            if count == 0 {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }
}

private final class AccountMockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
