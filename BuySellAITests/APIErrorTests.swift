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
}
