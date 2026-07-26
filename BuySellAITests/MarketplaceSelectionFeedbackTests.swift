import XCTest
@testable import BuySellAI

final class MarketplaceSelectionFeedbackTests: XCTestCase {
    func testMarketplaceSelectionFeedbackUsesLightImpactAndRunsAction() {
        XCTAssertEqual(MarketplaceSelectionFeedback.impactStyle, .light)

        var didRunAction = false
        MarketplaceSelectionFeedback.perform {
            didRunAction = true
        }

        XCTAssertTrue(didRunAction)
    }
}
