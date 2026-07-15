import XCTest
@testable import BuySellAI

final class MarketplaceEstimatorTests: XCTestCase {
    func testMarketplaceCatalogMatchesSpecOrderAndBlurbs() {
        let expected: [(Marketplace, String, String)] = [
            (.ebay, "eBay", "Broadest audience, small fees"),
            (.craigslist, "Craigslist", "Local, no fees, cash"),
            (.facebook, "Facebook", "Facebook Marketplace — free local reach"),
            (.poshmark, "Poshmark", "Fashion & closet items"),
            (.mercari, "Mercari", "Ship anything, casual buyers"),
            (.offerup, "OfferUp", "Local pickup, mobile-first"),
            (.depop, "Depop", "Vintage & Gen-Z fashion"),
            (.whatnot, "Whatnot", "Live-stream selling"),
            (.grailed, "Grailed", "Menswear, streetwear, designer"),
            (.reverb, "Reverb", "Music gear"),
            (.etsy, "Etsy", "Handmade, vintage, craft"),
            (.stockx, "StockX", "Sneakers & collectibles"),
            (.goat, "GOAT", "Sneakers, authenticated"),
            (.kidizen, "Kidizen", "Kids clothes"),
            (.vinted, "Vinted", "Fashion, no seller fees"),
            (.vestiaire, "Vestiaire", "Luxury pre-owned"),
            (.therealreal, "The RealReal", "Authenticated luxury"),
            (.swappa, "Swappa", "Used tech & phones"),
            (.tradesy, "Tradesy", "Designer bags & shoes"),
            (.chairish, "Chairish", "Vintage furniture & decor"),
            (.bonanza, "Bonanza", "General resale, low fees"),
            (.curtsy, "Curtsy", "Women's fashion (mobile)"),
            (.nextdoor, "Nextdoor", "Neighborhood local sales"),
            (.amazon, "Amazon", "Amazon seller — high reach, high fee"),
            (.shopify, "Shopify", "Your own storefront"),
            (.rubylane, "Ruby Lane", "Antiques & fine art"),
            (.tcgplayer, "TCGplayer", "Trading cards")
        ]

        XCTAssertEqual(Marketplace.allCases, expected.map(\.0))
        XCTAssertEqual(Marketplace.allCases.count, 27)

        for (marketplace, displayName, blurb) in expected {
            XCTAssertEqual(marketplace.displayName, displayName)
            XCTAssertEqual(marketplace.blurb, blurb)
        }
    }

    func testMarketplaceCatalogCopyHasLocalizationEntries() throws {
        let localizedStrings = try loadLocalizedStrings()

        for marketplace in Marketplace.allCases {
            XCTAssertEqual(
                localizedStrings[marketplace.displayName],
                marketplace.displayName,
                "\(marketplace.displayName) display name should have a Localizable.strings entry."
            )
            XCTAssertEqual(
                localizedStrings[marketplace.blurb],
                marketplace.blurb,
                "\(marketplace.displayName) blurb should have a Localizable.strings entry."
            )
        }
    }

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

    private func loadLocalizedStrings() throws -> [String: String] {
        let data = try Data(contentsOf: projectURL("BuySellAI/Resources/Localizable.strings"))
        let propertyList = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(propertyList as? [String: String])
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
