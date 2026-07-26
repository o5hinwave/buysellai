import XCTest
@testable import BuySellAI

final class APIErrorTests: XCTestCase {
    func testUserFriendlyErrorMessagesDoNotExposeRawTransportNames() {
        XCTAssertEqual(APIError.offline.localizedDescription, "You're offline. Reconnect and try again.")
        XCTAssertEqual(APIError.timeout.localizedDescription, "That took too long. Try again.")
        XCTAssertEqual(APIError.rateLimited.localizedDescription, "You've analyzed a lot of items today. BuySell needs a little time before the next one. Your saved listings are still available.")
        XCTAssertEqual(APIError.server(500).localizedDescription, "BuySell is having trouble. Try again.")
        XCTAssertEqual(APIError.decoding.localizedDescription, "BuySell got an answer it couldn't read.")
        XCTAssertEqual(APIError.notConfigured.localizedDescription, "BuySell isn't ready yet. Try again later.")
        XCTAssertEqual(APIError.sessionExpired.localizedDescription, "Sign in again to continue.")
        XCTAssertEqual(
            APIError.accountAlreadyLinked.localizedDescription,
            "That Apple account is already linked to another BuySell account."
        )
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

    func testCancellationDetectionCoversTaskAndURLSessionCancellation() {
        XCTAssertTrue(APIError.isCancellation(CancellationError()))
        XCTAssertTrue(APIError.isCancellation(URLError(.cancelled)))
        XCTAssertFalse(APIError.isCancellation(URLError(.timedOut)))
        XCTAssertFalse(APIError.isCancellation(APIError.timeout))
    }

    func testRethrowCancellationPreservesSilentCancellationErrors() {
        XCTAssertThrowsError(try APIError.rethrowCancellation(CancellationError())) { error in
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertThrowsError(try APIError.rethrowCancellation(URLError(.cancelled))) { error in
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertNoThrow(try APIError.rethrowCancellation(APIError.timeout))
    }
}
