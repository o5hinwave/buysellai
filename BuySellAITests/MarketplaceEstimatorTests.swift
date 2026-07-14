import XCTest
@testable import BuySellAI

final class MarketplaceEstimatorTests: XCTestCase {
    func testEstimatorReturnsEveryMarketplaceWithBestAndLowestBadges() {
        let estimates = MarketplaceEstimator.estimates(for: Decimal(100))

        XCTAssertEqual(estimates.count, Marketplace.allCases.count)
        XCTAssertEqual(estimates.first?.badge, .best)
        XCTAssertEqual(estimates.last?.badge, .lowest)
        XCTAssertEqual(estimates.first?.payout, Decimal(100))
        XCTAssertEqual(estimates.last?.id, .therealreal)
    }

    func testFeeMathForKnownMarketplaces() {
        let estimates = MarketplaceEstimator.estimates(for: Decimal(100))
        let byMarketplace = Dictionary(uniqueKeysWithValues: estimates.map { ($0.id, $0.payout) })

        XCTAssertEqual(byMarketplace[.craigslist], Decimal(100))
        XCTAssertEqual(byMarketplace[.ebay], Decimal(86))
        XCTAssertEqual(byMarketplace[.poshmark], Decimal(79))
        XCTAssertEqual(byMarketplace[.amazon], Decimal(82))
        XCTAssertEqual(byMarketplace[.therealreal], Decimal(65))
    }

    func testEveryMarketplaceHasPositivePayoutForLowBasePrice() {
        let estimates = MarketplaceEstimator.estimates(for: Decimal(3))

        XCTAssertTrue(estimates.allSatisfy { $0.payout.doubleValue >= 1 })
    }
}

