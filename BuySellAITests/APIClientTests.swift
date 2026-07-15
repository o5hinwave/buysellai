import Foundation
import XCTest
@testable import BuySellAI

final class APIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testAnalyzeBuildsSupabaseFunctionRequest() async throws {
        let client = try makeClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/analyze-image")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let imageDataURL = try XCTUnwrap(json["imageDataUrl"] as? String)
            XCTAssertTrue(imageDataURL.hasPrefix("data:image/jpeg;base64,"))

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"name":"Mug","category":"Home","condition":"good","currentPrice":12}"#.utf8))
        }

        let response = try await client.analyze(image: Data([1, 2, 3]), accessToken: "access-token")

        XCTAssertEqual(response.name, "Mug")
        XCTAssertEqual(response.category, "Home")
        XCTAssertEqual(response.condition, "good")
        XCTAssertEqual(response.currentPrice, Decimal(12))
    }

    func testAnalyzeIgnoresWebOnlyFollowUpAndTaxFields() async throws {
        let client = try makeClient { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(
                """
                {
                  "name": "Ceramic mug",
                  "category": "Home",
                  "condition": "good",
                  "currentPrice": 9,
                  "followUpQuestions": ["Is it deductible?"],
                  "isDeductible": true,
                  "taxCategory": "household"
                }
                """.utf8
            ))
        }

        let response = try await client.analyze(image: Data([1, 2, 3]))

        XCTAssertEqual(response.name, "Ceramic mug")
        XCTAssertEqual(response.category, "Home")
        XCTAssertEqual(response.condition, "good")
        XCTAssertEqual(response.currentPrice, Decimal(9))
    }

    func testAnalyzeGuestRequestOmitsAuthorizationHeader() async throws {
        let client = try makeClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/analyze-image")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let imageDataURL = try XCTUnwrap(json["imageDataUrl"] as? String)
            XCTAssertTrue(imageDataURL.hasPrefix("data:image/jpeg;base64,"))

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"name":"Guest mug","category":"Home","condition":"good","currentPrice":10}"#.utf8))
        }

        let response = try await client.analyze(image: Data([1, 2, 3]))

        XCTAssertEqual(response.name, "Guest mug")
        XCTAssertEqual(response.currentPrice, Decimal(10))
    }

    func testGenerateListingBuildsRequestAndPreservesListingText() async throws {
        let item = DetectedItem(name: "Lamp", category: .home, condition: .good, priceEstimate: Decimal(45))
        let client = try makeClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/generate-listing")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["platform"] as? String, "ebay")
            let item = try XCTUnwrap(json["item"] as? [String: Any])
            XCTAssertEqual(item["name"] as? String, "Lamp")
            XCTAssertEqual(item["category"] as? String, "Home")
            XCTAssertEqual(item["condition"] as? String, "good")
            XCTAssertEqual((item["originalPrice"] as? NSNumber)?.decimalValue, Decimal(45))
            XCTAssertEqual((item["currentPrice"] as? NSNumber)?.decimalValue, Decimal(45))

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"listing":"TITLE:\nLamp\n\nDESCRIPTION:\nWorks well.\n"}"#.utf8))
        }

        let listing = try await client.generateListing(item: item, marketplace: .ebay, accessToken: "access-token")

        XCTAssertEqual(listing, "TITLE:\nLamp\n\nDESCRIPTION:\nWorks well.\n")
    }

    func testGenerateListingGuestRequestOmitsAuthorizationHeader() async throws {
        let item = DetectedItem(name: "Lamp", category: .home, condition: .good, priceEstimate: Decimal(45))
        let client = try makeClient { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/generate-listing")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.timeoutInterval, 20)
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test-key")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))

            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["platform"] as? String, "craigslist")
            let item = try XCTUnwrap(json["item"] as? [String: Any])
            XCTAssertEqual(item["name"] as? String, "Lamp")
            XCTAssertEqual((item["currentPrice"] as? NSNumber)?.decimalValue, Decimal(45))

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"listing":"TITLE:\nGuest Lamp\n\nDESCRIPTION:\nReady to list."}"#.utf8))
        }

        let listing = try await client.generateListing(item: item, marketplace: .craigslist)

        XCTAssertEqual(listing, "TITLE:\nGuest Lamp\n\nDESCRIPTION:\nReady to list.")
    }

    func testRateLimitMapsToFriendlyError() async {
        let client: APIClient
        do {
            client = try makeClient { request in
                let url = try XCTUnwrap(request.url)
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil))
                return (response, Data())
            }
        } catch {
            XCTFail("Could not make client: \(error)")
            return
        }

        do {
            _ = try await client.analyze(image: Data([1]))
            XCTFail("Expected rate limit error")
        } catch {
            XCTAssertEqual(error as? APIError, .rateLimited)
        }
    }

    func testMalformedAnalyzeJSONMapsToDecodingError() async throws {
        let client = try makeClient { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"name":"Lamp","category":"Home"}"#.utf8))
        }

        do {
            _ = try await client.analyze(image: Data([1]))
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertEqual(error as? APIError, .decoding)
        }
    }

    func testMalformedGenerateListingJSONMapsToDecodingError() async throws {
        let item = DetectedItem(name: "Lamp", category: .home, condition: .good, priceEstimate: Decimal(45))
        let client = try makeClient { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"title":"Lamp"}"#.utf8))
        }

        do {
            _ = try await client.generateListing(item: item, marketplace: .ebay)
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertEqual(error as? APIError, .decoding)
        }
    }

    func testTimeoutMapsToFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await client.analyze(image: Data([1]))
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }

    func testCannotFindHostMapsToOfflineFriendlyError() async throws {
        let client = try makeClient { _ in
            throw URLError(.cannotFindHost)
        }

        do {
            _ = try await client.analyze(image: Data([1]))
            XCTFail("Expected offline error")
        } catch {
            XCTAssertEqual(error as? APIError, .offline)
        }
    }

    func testNonSuccessStatusMapsToServerError() async throws {
        let client = try makeClient { request in
            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 418, httpVersion: nil, headerFields: nil))
            return (response, Data())
        }

        do {
            _ = try await client.analyze(image: Data([1]))
            XCTFail("Expected server error")
        } catch {
            XCTAssertEqual(error as? APIError, .server(418))
        }
    }

    func testNetworkConnectionLostRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            if attempts == 1 {
                throw URLError(.networkConnectionLost)
            }

            let url = try XCTUnwrap(request.url)
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"name":"Book","category":"Books","condition":"good","currentPrice":8}"#.utf8))
        }

        let response = try await client.analyze(image: Data([1]))

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(response.name, "Book")
        XCTAssertEqual(response.currentPrice, Decimal(8))
    }

    func testTransientServerErrorRetriesOnce() async throws {
        var attempts = 0
        let client = try makeClient { request in
            attempts += 1
            let url = try XCTUnwrap(request.url)
            if attempts == 1 {
                let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil))
                return (response, Data())
            }

            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, Data(#"{"name":"Chair","category":"Furniture","condition":"fair","currentPrice":25}"#.utf8))
        }

        let response = try await client.analyze(image: Data([1]))

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(response.name, "Chair")
        XCTAssertEqual(response.currentPrice, Decimal(25))
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) throws -> APIClient {
        MockURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration)
        let url = try XCTUnwrap(URL(string: "https://example.supabase.co"))
        let config = AppConfig(supabaseURL: url, anonKey: "anon-test-key")
        return APIClient(session: session, config: config, isUITesting: false)
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

private final class MockURLProtocol: URLProtocol {
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
