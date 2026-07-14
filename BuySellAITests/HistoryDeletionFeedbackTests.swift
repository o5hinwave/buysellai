import XCTest
@testable import BuySellAI

final class HistoryDeletionFeedbackTests: XCTestCase {
    func testHistoryDeletionFeedbackUsesWarningNotification() {
        XCTAssertEqual(HistoryDeletionFeedback.notificationType, .warning)
    }
}
