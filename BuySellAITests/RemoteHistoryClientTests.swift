import Foundation
import XCTest
@testable import BuySellAI

final class RemoteHistoryClientTests: XCTestCase {
    override func tearDown() {
        RemoteHistoryMockURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchHistoryBuildsPostgRESTRequestAndMapsRows() async throws {
        let entryID = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let client = try makeClient { request in
            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.scheme, "https")
            XCTAssertEqual(components.host, "example.supabase.co")
            XCTAssertEqual(components.path, "/rest/v1/history")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "order" })?.value, "created_at.desc")
            XCTAssertNotNil(components.queryItems?.first(where: { $0.name == "select" })?.value)
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            let data = Data("""
            [{
              "id": "\(entryID.uuidString)",
              "created_at": "2026-07-14T19:00:00Z",
              "item_name": "Lamp",
              "category": "home",
              "condition": "good",
              "suggested_price": 45,
              "image_thumbnail_base64": "AQID",
              "marketplace": "ebay",
              "listing_text": "TITLE:\\nLamp"
            }]
            """.utf8)
            return (response, data)
        }

        let entries = try await client.fetchHistory(accessToken: "access-token")

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].id, entryID)
        XCTAssertEqual(entries[0].itemName, "Lamp")
        XCTAssertEqual(entries[0].category, .home)
        XCTAssertEqual(entries[0].condition, .good)
        XCTAssertEqual(entries[0].suggestedPrice, Decimal(45))
        XCTAssertEqual(entries[0].imageThumbnail, Data([1, 2, 3]))
        XCTAssertEqual(entries[0].marketplace, .ebay)
        XCTAssertEqual(entries[0].listingText, "TITLE:\nLamp")
    }

    func testUpsertHistoryBuildsBatchPostgRESTRequest() async throws {
        let entryID = try XCTUnwrap(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let createdAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-14T19:30:00Z"))
        let entry = HistoryEntry(
            id: entryID,
            createdAt: createdAt,
            itemName: "Chair",
            category: .furniture,
            condition: .fair,
            suggestedPrice: Decimal(30),
            imageThumbnail: Data([4, 5, 6]),
            marketplace: .craigslist,
            listingText: "TITLE:\nChair"
        )
        let client = try makeClient { request in
            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.path, "/rest/v1/history")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "on_conflict" })?.value, "id")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "resolution=merge-duplicates,return=minimal")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [[String: Any]])
            let row = try XCTUnwrap(rows.first)
            XCTAssertEqual(row["id"] as? String, entryID.uuidString)
            XCTAssertEqual(row["item_name"] as? String, "Chair")
            XCTAssertEqual(row["category"] as? String, "furniture")
            XCTAssertEqual(row["condition"] as? String, "fair")
            XCTAssertEqual(row["suggested_price"] as? Int, 30)
            XCTAssertEqual(row["image_thumbnail_base64"] as? String, "BAUG")
            XCTAssertEqual(row["marketplace"] as? String, "craigslist")
            XCTAssertEqual(row["listing_text"] as? String, "TITLE:\nChair")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        try await client.upsertHistory([entry], accessToken: "access-token")
    }

    func testFetchHistoryMalformedJSONMapsToDecodingError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(#"{"id":"not an array"}"#.utf8))
        }

        do {
            _ = try await client.fetchHistory(accessToken: "access-token")
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertEqual(error as? APIError, .decoding)
        }
    }

    func testFetchHistoryTimeoutMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await client.fetchHistory(accessToken: "access-token")
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }

    func testUpsertHistoryNonSuccessStatusMapsToServerError() async throws {
        let entry = HistoryEntry(
            id: UUID(),
            createdAt: Date(),
            itemName: "Lamp",
            category: .home,
            condition: .good,
            suggestedPrice: Decimal(20),
            imageThumbnail: nil,
            marketplace: .ebay,
            listingText: "TITLE:\nLamp"
        )
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
            try await client.upsertHistory([entry], accessToken: "access-token")
            XCTFail("Expected server error")
        } catch {
            XCTAssertEqual(error as? APIError, .server(403))
        }
    }

    func testDeleteHistoryRateLimitMapsToFriendlyError() async throws {
        let client = try makeClient { request in
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }

        do {
            try await client.deleteHistory(id: UUID(), accessToken: "access-token")
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(error as? APIError, .rateLimited)
        }
    }

    func testClearHistoryTransientServerErrorRetriesOnce() async throws {
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

        try await client.clearHistory(accessToken: "access-token")

        XCTAssertEqual(attempts, 2)
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) throws -> RemoteHistoryClient {
        RemoteHistoryMockURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RemoteHistoryMockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration)
        let url = try XCTUnwrap(URL(string: "https://example.supabase.co"))
        let config = AppConfig(supabaseURL: url, anonKey: "anon-test-key")
        return RemoteHistoryClient(session: session, config: config)
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

private final class RemoteHistoryMockURLProtocol: URLProtocol {
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
