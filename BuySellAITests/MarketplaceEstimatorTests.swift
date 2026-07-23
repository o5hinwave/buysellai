import XCTest
@testable import BuySellAI

final class MarketplaceEstimatorTests: XCTestCase {
    func testMarketplaceCatalogMatchesSpecOrderAndBlurbs() {
        let expected: [(Marketplace, String, String)] = [
            (.ebay, "eBay", "Broadest audience, small fees"),
            (.craigslist, "Craigslist", "Local, no fees, cash"),
            (.facebook, "Facebook", "Facebook Marketplace — free local reach"),
            (.poshmark, "Poshmark", "Fashion & closet items"),
            (.mercari, "Mercari", "Easy shipping for everyday items"),
            (.offerup, "OfferUp", "Local pickup, mobile-first"),
            (.depop, "Depop", "Vintage & Gen-Z fashion"),
            (.whatnot, "Whatnot", "Live-stream selling"),
            (.grailed, "Grailed", "Menswear, streetwear, designer"),
            (.reverb, "Reverb", "Music gear"),
            (.etsy, "Etsy", "Handmade, vintage, craft"),
            (.stockx, "StockX", "Sneakers & collectibles"),
            (.goat, "GOAT", "Sneakers, authenticated"),
            (.kidizen, "Kidizen", "Kids clothes"),
            (.vinted, "Vinted", "Fashion, no listing fees"),
            (.vestiaire, "Vestiaire", "Luxury pre-owned"),
            (.therealreal, "The RealReal", "Authenticated luxury"),
            (.swappa, "Swappa", "Used tech & phones"),
            (.tradesy, "Tradesy", "Designer bags & shoes"),
            (.chairish, "Chairish", "Vintage furniture & decor"),
            (.bonanza, "Bonanza", "General resale, low fees"),
            (.curtsy, "Curtsy", "Women's fashion (mobile)"),
            (.nextdoor, "Nextdoor", "Neighborhood local sales"),
            (.amazon, "Amazon", "Amazon marketplace — high reach, high fee"),
            (.shopify, "Shopify", "Your own storefront"),
            (.rubylane, "Ruby Lane", "Antiques & fine art"),
            (.tcgplayer, "TCGplayer", "Trading cards")
        ]

        XCTAssertEqual(Marketplace.allCases, expected.map(\.0))
        XCTAssertEqual(Marketplace.allCases.count, 27)
        XCTAssertEqual(Marketplace.activeRecommendationCases.count, 25)
        XCTAssertFalse(Marketplace.activeRecommendationCases.contains(.kidizen))
        XCTAssertFalse(Marketplace.activeRecommendationCases.contains(.tradesy))

        for (marketplace, displayName, blurb) in expected {
            XCTAssertEqual(marketplace.displayName, displayName)
            XCTAssertEqual(marketplace.blurb, blurb)
            XCTAssertNil(
                blurb.range(of: #"\bseller\b"#, options: [.regularExpression, .caseInsensitive]),
                "\(displayName) blurb should not call the user a seller."
            )
        }
    }

    func testMarketplacePlaybookEvidenceCoversCurrentFeeSourcesAndActiveTargets() {
        for marketplace in Marketplace.allCases {
            let evidence = marketplace.playbookEvidence
            XCTAssertFalse(evidence.feeModelSourceTitle.isEmpty, marketplace.displayName)
            XCTAssertFalse(evidence.feeModelSummary.isEmpty, marketplace.displayName)
            XCTAssertEqual(evidence.feeModelLastChecked, "2026-07-23", marketplace.displayName)
            XCTAssertEqual(URL(string: evidence.feeModelSourceURL)?.scheme, "https", marketplace.displayName)
            if [.kidizen, .tradesy].contains(marketplace) {
                XCTAssertEqual(evidence.sourceKind, .retiredMarketplace, marketplace.displayName)
            } else {
                XCTAssertNotEqual(evidence.sourceKind, .retiredMarketplace, marketplace.displayName)
                XCTAssertTrue(evidence.isActiveRecommendationTarget, marketplace.displayName)
            }
        }
    }

    func testMarketplaceCatalogProvidesNativeSystemIconSymbols() {
        let expectedSymbols: [Marketplace: String] = [
            .ebay: "cart",
            .craigslist: "mappin.and.ellipse",
            .facebook: "person.2",
            .poshmark: "tshirt",
            .mercari: "shippingbox",
            .offerup: "mappin.and.ellipse",
            .depop: "tshirt",
            .whatnot: "play.rectangle",
            .grailed: "tshirt",
            .reverb: "music.note",
            .etsy: "paintpalette",
            .stockx: "checkmark.seal",
            .goat: "checkmark.seal",
            .kidizen: "tshirt",
            .vinted: "tshirt",
            .vestiaire: "handbag",
            .therealreal: "handbag",
            .swappa: "iphone",
            .tradesy: "handbag",
            .chairish: "house",
            .bonanza: "cart",
            .curtsy: "tshirt",
            .nextdoor: "mappin.and.ellipse",
            .amazon: "cart",
            .shopify: "cart",
            .rubylane: "sparkles",
            .tcgplayer: "rectangle.stack"
        ]

        XCTAssertEqual(Set(expectedSymbols.keys), Set(Marketplace.allCases))

        for marketplace in Marketplace.allCases {
            XCTAssertEqual(marketplace.iconSystemName, expectedSymbols[marketplace], marketplace.displayName)
            XCTAssertFalse(marketplace.iconSystemName.isEmpty, marketplace.displayName)
        }
    }

    func testRetiredMarketplacesRemainDecodableButDoNotAppearInRecommendations() {
        XCTAssertEqual(Marketplace(apiValue: "Kidizen"), .kidizen)
        XCTAssertEqual(Marketplace(apiValue: "Tradesy"), .tradesy)
        XCTAssertFalse(Marketplace.kidizen.playbookEvidence.isActiveRecommendationTarget)
        XCTAssertFalse(Marketplace.tradesy.playbookEvidence.isActiveRecommendationTarget)
        XCTAssertEqual(Marketplace.kidizen.playbookEvidence.sourceKind, .retiredMarketplace)
        XCTAssertEqual(Marketplace.tradesy.playbookEvidence.sourceKind, .retiredMarketplace)

        let estimates = MarketplaceEstimator.estimates(for: Decimal(40))
        XCTAssertFalse(estimates.contains { $0.id == .kidizen })
        XCTAssertFalse(estimates.contains { $0.id == .tradesy })
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

        XCTAssertEqual(estimates.count, Marketplace.activeRecommendationCases.count)
        XCTAssertEqual(estimates.first?.badge, .best)
        XCTAssertEqual(estimates.first?.id, .craigslist)
        XCTAssertEqual(estimates.last?.badge, .lowest)
        XCTAssertEqual(estimates.first?.payout, Decimal(100))
        XCTAssertEqual(estimates.last?.id, .therealreal)

        let craigslistIndex = try? XCTUnwrap(estimates.firstIndex { $0.id == .craigslist })
        let nextdoorIndex = try? XCTUnwrap(estimates.firstIndex { $0.id == .nextdoor })
        XCTAssertEqual(estimates[craigslistIndex ?? 0].payout, estimates[nextdoorIndex ?? 0].payout)
        XCTAssertLessThan(craigslistIndex ?? .max, nextdoorIndex ?? .max)
    }

    func testItemAwareEstimatorRecommendsBestMarketplaceForFiveSampleItems() {
        let samples: [(DetectedItem, Marketplace)] = [
            (
                DetectedItem(
                    name: "Fender Stratocaster Electric Guitar",
                    category: .music,
                    condition: .good,
                    priceEstimate: Decimal(650)
                ),
                .reverb
            ),
            (
                DetectedItem(
                    name: "iPhone 14 Pro 128GB Unlocked",
                    category: .electronics,
                    condition: .good,
                    priceEstimate: Decimal(420)
                ),
                .swappa
            ),
            (
                DetectedItem(
                    name: "Mid Century Walnut Coffee Table",
                    category: .furniture,
                    condition: .good,
                    priceEstimate: Decimal(220)
                ),
                .craigslist
            ),
            (
                DetectedItem(
                    name: "Madewell Denim Jacket Women's Medium",
                    category: .clothing,
                    condition: .good,
                    priceEstimate: Decimal(45)
                ),
                .poshmark
            ),
            (
                DetectedItem(
                    name: "Nike Dunk Low Panda Size 10",
                    category: .shoes,
                    condition: .new,
                    priceEstimate: Decimal(120)
                ),
                .stockx
            )
        ]

        for (item, expectedMarketplace) in samples {
            let estimates = MarketplaceEstimator.estimates(for: item)
            XCTAssertEqual(estimates.count, Marketplace.activeRecommendationCases.count)
            XCTAssertEqual(estimates.first?.id, expectedMarketplace, item.name)
            XCTAssertEqual(estimates.first?.badge, .best, item.name)
            XCTAssertEqual(estimates.prefix(3).count, 3, item.name)
        }
    }

    func testItemAwareEstimatorCarriesPlainBoundedFitScores() {
        let guitar = DetectedItem(
            name: "Fender Stratocaster Electric Guitar",
            category: .music,
            condition: .good,
            priceEstimate: Decimal(650)
        )

        let estimates = MarketplaceEstimator.estimates(for: guitar)
        let baseOnlyEstimates = MarketplaceEstimator.estimates(for: guitar.priceEstimate)

        XCTAssertTrue(estimates.allSatisfy { (1...100).contains($0.fitScore) })
        XCTAssertTrue(baseOnlyEstimates.allSatisfy { $0.fitScore == 0 })
        XCTAssertEqual(estimates.first?.id, .reverb)
        XCTAssertEqual(estimates.first?.fitSummary, "Strong fit")
        XCTAssertEqual(estimates.first?.fitScore, estimates.map(\.fitScore).max())

        for estimate in estimates {
            if let fitSummary = estimate.fitSummary {
                assertPlainMarketplaceCopy(fitSummary, context: "\(estimate.id.displayName) fit summary")
            }
        }
    }

    func testRecommendationScoreAccountsForPickupAndShippingFriction() throws {
        let dresser = DetectedItem(
            name: "Large oak dresser with mirror",
            category: .furniture,
            condition: .fair,
            priceEstimate: Decimal(180)
        )

        let ranked = MarketplaceEstimator.estimates(for: dresser)
        XCTAssertEqual(ranked.first?.id, .craigslist)
        XCTAssertFalse(ranked.prefix(3).map(\.id).contains(.ebay))

        let craigslist = try recommendationComponents(for: .craigslist, item: dresser)
        let ebay = try recommendationComponents(for: .ebay, item: dresser)

        XCTAssertGreaterThan(craigslist.localPickupFit, ebay.localPickupFit)
        XCTAssertGreaterThan(craigslist.shippingFit, ebay.shippingFit)
        XCTAssertGreaterThan(craigslist.listingEffort, ebay.listingEffort)
    }

    func testSummaryPlannerSeparatesBestChanceFromMostMoneyBackWhenTheyDiffer() throws {
        let guitar = DetectedItem(
            name: "Fender Stratocaster Electric Guitar",
            category: .music,
            condition: .good,
            priceEstimate: Decimal(650)
        )

        let ranked = MarketplaceEstimator.estimates(for: guitar)
        let picks = MarketplaceSummaryPlanner.picks(from: ranked)

        XCTAssertEqual(picks.map(\.kind), [.bestChance, .mostMoneyBack, .goodFit])
        XCTAssertEqual(picks.first?.estimate.id, .reverb)
        XCTAssertEqual(picks[1].estimate.payout, ranked.map(\.payout).max())
        XCTAssertNotEqual(picks[0].estimate.id, picks[1].estimate.id)
    }

    func testSummaryPlannerUsesSecondAndThirdWhenBestChanceAlsoPaysMost() {
        let lamp = DetectedItem(
            name: "Vintage brass table lamp",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )

        let picks = MarketplaceSummaryPlanner.picks(from: MarketplaceEstimator.estimates(for: lamp))

        XCTAssertEqual(picks.map(\.kind), [.bestChance, .second, .third])
        XCTAssertEqual(picks.first?.estimate.id, .craigslist)
        XCTAssertFalse(picks.contains { $0.kind == .mostMoneyBack })
    }

    func testMarketplaceRecommendationScoringInputsStayBoundedAndLocalized() throws {
        let localizedStrings = try loadLocalizedStrings()
        let item = DetectedItem(name: "Generic household clutter box", category: .other, condition: .fair, priceEstimate: Decimal(18))

        for marketplace in Marketplace.allCases {
            let profile = marketplace.optimizationProfile
            for score in [
                profile.listingEffort(for: item),
                profile.buyerTrust(for: item),
                profile.localPickupFit(for: item),
                profile.shippingFit(for: item),
                profile.speedScore,
                marketplace.searchFitScore(for: item)
            ] {
                XCTAssertTrue((1...100).contains(score), "\(marketplace.displayName) score should stay bounded")
            }
        }

        for kind in [
            MarketplaceSummaryKind.bestChance,
            .mostMoneyBack,
            .goodFit,
            .second,
            .third
        ] {
            XCTAssertEqual(localizedStrings[kind.label], kind.label)
        }

        for fitSummary in [
            "Strong fit",
            "Good fit",
            "Worth a look",
            "More work"
        ] {
            XCTAssertEqual(localizedStrings[fitSummary], fitSummary)
        }
    }

    func testMarketplaceListingOptimizerKeepsTitlesInsideMarketplaceLimits() {
        let item = DetectedItem(
            name: "Vintage Mid Century Modern Walnut and Brass Adjustable Floor Lamp With Original Shade",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(180)
        )

        for marketplace in Marketplace.allCases {
            let title = MarketplaceListingOptimizer.title(for: item, marketplace: marketplace)
            XCTAssertLessThanOrEqual(
                title.count,
                marketplace.optimizationProfile.titleMaxCharacters,
                "\(marketplace.displayName) title should respect its marketplace limit"
            )
            XCTAssertFalse(title.isEmpty)
        }
    }

    func testMarketplaceRecommendationReasonsAvoidTechnicalOptimizationLanguage() {
        let sampleItems = [
            DetectedItem(name: "Handmade ceramic serving bowl", category: .home, condition: .good, priceEstimate: Decimal(42)),
            DetectedItem(name: "Fender Stratocaster Electric Guitar", category: .music, condition: .good, priceEstimate: Decimal(650)),
            DetectedItem(name: "iPhone 14 Pro 128GB Unlocked", category: .electronics, condition: .good, priceEstimate: Decimal(420)),
            DetectedItem(name: "Mid Century Walnut Coffee Table", category: .furniture, condition: .good, priceEstimate: Decimal(220)),
            DetectedItem(name: "Madewell Denim Jacket Women's Medium", category: .clothing, condition: .good, priceEstimate: Decimal(45)),
            DetectedItem(name: "Nike Dunk Low Panda Size 10", category: .shoes, condition: .new, priceEstimate: Decimal(120))
        ]

        for marketplace in Marketplace.allCases {
            assertPlainMarketplaceCopy(marketplace.blurb, context: "\(marketplace.displayName) blurb")
            assertPlainMarketplaceCopy(
                marketplace.optimizationProfile.searchFocus,
                context: "\(marketplace.displayName) recommendation focus"
            )
            assertPlainMarketplaceCopy(
                marketplace.optimizationProfile.photoGuidance,
                context: "\(marketplace.displayName) photo guidance"
            )
            assertPlainMarketplaceCopy(
                marketplace.optimizationProfile.featuredGuidance,
                context: "\(marketplace.displayName) placement guidance"
            )

            for item in sampleItems {
                let reason = marketplace.recommendationReason(for: item)
                assertPlainMarketplaceCopy(reason, context: "\(marketplace.displayName) recommendation reason for \(item.category.display)")
            }
        }
    }

    func testMarketplaceEstimateCodableRoundTripPreservesPayoutAndBadge() throws {
        let estimate = MarketplaceEstimate(
            id: .ebay,
            payout: Decimal(86),
            deltaPct: -4.25,
            badge: .none,
            fitScore: 72
        )

        let data = try JSONEncoder().encode(estimate)
        let decoded = try JSONDecoder().decode(MarketplaceEstimate.self, from: data)

        XCTAssertEqual(decoded, estimate)
        XCTAssertEqual(decoded.fitSummary, "Good fit")
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

    func testEstimatorPreservesDecimalBaseWithoutDoublePrecisionLoss() throws {
        let base = try XCTUnwrap(Decimal(string: "9007199254740993"))
        let estimates = MarketplaceEstimator.estimates(for: base)
        let byMarketplace = Dictionary(uniqueKeysWithValues: estimates.map { ($0.id, $0.payout) })

        XCTAssertEqual(byMarketplace[.craigslist], base)
        XCTAssertNotEqual(byMarketplace[.craigslist], Decimal(base.doubleValue))
    }

    private func loadLocalizedStrings() throws -> [String: String] {
        let data = try Data(contentsOf: projectURL("BuySellAI/Resources/Localizable.strings"))
        let propertyList = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(propertyList as? [String: String])
    }

    private func recommendationComponents(
        for marketplace: Marketplace,
        item: DetectedItem,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> MarketplaceRecommendationComponents {
        let payoutEstimates = MarketplaceEstimator.estimates(for: item.priceEstimate)
        let payouts = payoutEstimates.map(\.payout)
        let highestPayout = try XCTUnwrap(payouts.max(), file: file, line: line)
        let lowestPayout = try XCTUnwrap(payouts.min(), file: file, line: line)
        let payoutRange = max(highestPayout.doubleValue - lowestPayout.doubleValue, 1)
        let estimate = try XCTUnwrap(
            payoutEstimates.first { $0.id == marketplace },
            file: file,
            line: line
        )

        return MarketplaceEstimator.recommendationComponents(
            for: item,
            estimate: estimate,
            lowestPayout: lowestPayout,
            payoutRange: payoutRange
        )
    }

    private func assertPlainMarketplaceCopy(
        _ text: String,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let bannedPatterns = [
            #"\bSEO\b"#,
            #"\bbuyers?\b"#,
            #"\bsearch\b"#,
            #"\bkeywords?\b"#,
            #"\bconversion\b"#,
            #"\bpromot(e|ed|ing|ion|ions)\b"#,
            #"\bboost(s|ed|ing)?\b"#,
            #"\borganic\b"#,
            #"\bwatchers?\b"#,
            #"\bads?\b"#,
            #"\badvertis(e|ed|ing|ement|ements)\b"#,
            #"\bprice competitiveness\b"#,
            #"\bexact product identity\b"#,
            #"\balgorithmically ranked\b"#,
            #"\bprompt engineered\b"#,
            #"\bmarketplace arbitrage\b"#,
            #"\bkeyword density\b"#,
            #"\bconversion strategy\b"#
        ]

        for pattern in bannedPatterns {
            XCTAssertNil(
                text.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
                "\(context) should use plain marketplace language: \(text)",
                file: file,
                line: line
            )
        }
    }

    private func projectURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(path)
    }
}
