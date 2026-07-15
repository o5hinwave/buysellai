import XCTest
@testable import BuySellAI

final class APIErrorTests: XCTestCase {
    func testUserFriendlyErrorMessagesDoNotExposeRawTransportNames() {
        XCTAssertEqual(APIError.offline.localizedDescription, "You're offline. Reconnect and try again.")
        XCTAssertEqual(APIError.timeout.localizedDescription, "That took too long. Try again.")
        XCTAssertEqual(APIError.rateLimited.localizedDescription, "Too many tries right now. Give it a minute.")
        XCTAssertEqual(APIError.server(500).localizedDescription, "BuySell is having trouble. Try again.")
        XCTAssertEqual(APIError.decoding.localizedDescription, "BuySell got an answer it couldn't read.")
        XCTAssertEqual(APIError.notConfigured.localizedDescription, "Backend is not configured yet.")
        XCTAssertEqual(APIError.unknown.localizedDescription, "Something went wrong. Try again.")
    }

    func testCameraCaptureFailureUsesFriendlyCopy() {
        XCTAssertEqual(CameraError.captureFailed.localizedDescription, "Photo couldn't be captured.")
    }

    func testTransportMappingClassifiesCommonOfflineFailures() {
        let offlineCodes: [URLError.Code] = [
            .notConnectedToInternet,
            .networkConnectionLost,
            .dataNotAllowed,
            .cannotFindHost,
            .cannotConnectToHost,
            .dnsLookupFailed,
            .internationalRoamingOff
        ]

        for code in offlineCodes {
            XCTAssertEqual(APIError.mapTransport(URLError(code)), .offline, "\(code) should show the offline message")
        }
    }

    func testTransportMappingClassifiesTimeoutAndUnknownFailures() {
        XCTAssertEqual(APIError.mapTransport(URLError(.timedOut)), .timeout)
        XCTAssertEqual(APIError.mapTransport(URLError(.badURL)), .unknown)
        XCTAssertEqual(APIError.mapTransport(APIError.rateLimited), .rateLimited)
        XCTAssertEqual(APIError.mapTransport(NSError(domain: "Test", code: 1)), .unknown)
    }
}
