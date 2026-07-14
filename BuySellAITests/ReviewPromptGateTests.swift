import XCTest
@testable import BuySellAI

final class ReviewPromptGateTests: XCTestCase {
    func testReviewPromptGateAllowsOnePromptPerVersion() throws {
        let suiteName = "ReviewPromptGateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let gate = ReviewPromptGate(defaults: defaults)

        XCTAssertTrue(gate.shouldRequestReview(for: "1.0"))
        XCTAssertFalse(gate.shouldRequestReview(for: "1.0"))
        XCTAssertTrue(gate.shouldRequestReview(for: "1.1"))
        XCTAssertFalse(gate.shouldRequestReview(for: "1.1"))
    }
}
