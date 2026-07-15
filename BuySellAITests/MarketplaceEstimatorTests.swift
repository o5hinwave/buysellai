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

    func testMarketplaceBrandTintsRouteThroughDesignTokens() throws {
        let marketplace = try String(contentsOf: projectURL("BuySellAI/Data/Marketplace.swift"), encoding: .utf8)
        let designTokens = try String(contentsOf: projectURL("BuySellAI/Design/DesignTokens.swift"), encoding: .utf8)

        XCTAssertNil(marketplace.range(of: "Color(hex:"))
        XCTAssertEqual(marketplace.components(separatedBy: "Color.brand.platform").count - 1, Marketplace.allCases.count)

        for token in [
            "platformEbay", "platformMercari", "platformPoshmark", "platformFacebook",
            "platformOfferUp", "platformCraigslist", "platformDepop", "platformWhatnot",
            "platformEtsy", "platformStockX", "platformGrailed", "platformReverb",
            "platformVinted", "platformNextdoor", "platformAmazon", "platformGOAT",
            "platformKidizen", "platformVestiaire", "platformTheRealReal", "platformSwappa",
            "platformTradesy", "platformChairish", "platformBonanza", "platformCurtsy",
            "platformShopify", "platformRubyLane", "platformTCGplayer"
        ] {
            XCTAssertNotNil(designTokens.range(of: "static let \(token) = Color(hex:"))
        }

        for (token, hex) in [
            ("platformEbay", "0x0064D2"),
            ("platformMercari", "0xE60023"),
            ("platformPoshmark", "0xE51A72"),
            ("platformFacebook", "0x1877F2"),
            ("platformOfferUp", "0x16A34A"),
            ("platformCraigslist", "0x6B21A8"),
            ("platformDepop", "0xE11D48"),
            ("platformWhatnot", "0xFF5722"),
            ("platformEtsy", "0xF1641E"),
            ("platformStockX", "0x006340"),
            ("platformGrailed", "0x000000"),
            ("platformReverb", "0xF5A623"),
            ("platformVinted", "0x09B1BA"),
            ("platformNextdoor", "0x00B246"),
            ("platformAmazon", "0xFF9900")
        ] {
            XCTAssertNotNil(
                designTokens.range(of: "static let \(token) = Color(hex: \(hex))"),
                "\(token) should match the brand tint in the rebuild spec."
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

    func testMarketplaceEstimateCodableRoundTripPreservesPayoutAndBadge() throws {
        let estimate = MarketplaceEstimate(
            id: .ebay,
            payout: Decimal(86),
            deltaPct: -4.25,
            badge: .none
        )

        let data = try JSONEncoder().encode(estimate)
        let decoded = try JSONDecoder().decode(MarketplaceEstimate.self, from: data)

        XCTAssertEqual(decoded, estimate)
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
