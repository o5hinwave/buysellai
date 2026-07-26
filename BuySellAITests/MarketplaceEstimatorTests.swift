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

    func testActiveMarketplacePostingDestinationsAreValidOfficialHTTPSLinks() {
        for marketplace in Marketplace.activeRecommendationCases {
            let destination = marketplace.postingDestination
            let postURL = destination.postURL
            let howToURL = destination.howToURL

            XCTAssertEqual(postURL?.scheme, "https", marketplace.displayName)
            XCTAssertEqual(howToURL?.scheme, "https", marketplace.displayName)
            XCTAssertNotNil(postURL?.host, marketplace.displayName)
            XCTAssertNotNil(howToURL?.host, marketplace.displayName)
            XCTAssertFalse(destination.sourceTitle.isEmpty, marketplace.displayName)
            XCTAssertEqual(destination.lastChecked, "2026-07-25", marketplace.displayName)
            XCTAssertNotEqual(destination.postingSurface, .unavailable, marketplace.displayName)
        }

        XCTAssertEqual(Marketplace.kidizen.postingDestination.postingSurface, .unavailable)
        XCTAssertEqual(Marketplace.tradesy.postingDestination.postingSurface, .unavailable)
    }

    func testActiveMarketplaceListingPlaybooksAreStructuredAndVersioned() {
        for marketplace in Marketplace.activeRecommendationCases {
            let playbook = marketplace.listingPlaybook

            XCTAssertEqual(playbook.marketplace, marketplace)
            XCTAssertEqual(playbook.version.identifier, "marketplace-playbook-v1-2026-07-25", marketplace.displayName)
            XCTAssertEqual(playbook.version.schemaVersion, 1, marketplace.displayName)
            XCTAssertEqual(playbook.version.feeSourcesLastChecked, "2026-07-23", marketplace.displayName)
            XCTAssertEqual(playbook.version.ruleSourcesLastVerified, "2026-07-25", marketplace.displayName)
            XCTAssertGreaterThan(playbook.titleCharacterLimit, 0, marketplace.displayName)
            XCTAssertEqual(playbook.titleCharacterLimit, marketplace.optimizationProfile.titleMaxCharacters, marketplace.displayName)
            XCTAssertFalse(playbook.titleFormula.isEmpty, marketplace.displayName)
            XCTAssertFalse(playbook.descriptionGuidance.isEmpty, marketplace.displayName)
            XCTAssertFalse(playbook.requiredFields.isEmpty, marketplace.displayName)
            XCTAssertFalse(playbook.highImpactOptionalFields.isEmpty, marketplace.displayName)
            XCTAssertFalse(playbook.recommendedPhotoSequence.isEmpty, marketplace.displayName)
            XCTAssertFalse(playbook.pricingFormat.isEmpty, marketplace.displayName)
            XCTAssertFalse(playbook.shippingOrPickupGuidance.isEmpty, marketplace.displayName)
            XCTAssertFalse(playbook.feeModelSourceTitle.isEmpty, marketplace.displayName)
            XCTAssertEqual(playbook.feeModelLastChecked, "2026-07-23", marketplace.displayName)
            XCTAssertEqual(playbook.ruleSourceLastVerified, "2026-07-25", marketplace.displayName)
            XCTAssertNotEqual(playbook.postingSurface, .unavailable, marketplace.displayName)
            XCTAssertEqual(URL(string: playbook.officialPostURLString)?.scheme, "https", marketplace.displayName)
            XCTAssertEqual(URL(string: playbook.officialHowToURLString)?.scheme, "https", marketplace.displayName)
            XCTAssertGreaterThanOrEqual(playbook.ruleSourceURLs.count, 2, marketplace.displayName)
            for sourceURL in playbook.ruleSourceURLs {
                XCTAssertEqual(URL(string: sourceURL)?.scheme, "https", "\(marketplace.displayName): \(sourceURL)")
            }
        }
    }

    func testRetiredMarketplaceListingPlaybooksRemainUnavailable() {
        XCTAssertEqual(Marketplace.kidizen.listingPlaybook.postingSurface, .unavailable)
        XCTAssertEqual(Marketplace.tradesy.listingPlaybook.postingSurface, .unavailable)
        XCTAssertEqual(Marketplace.kidizen.listingPlaybook.requiredFields, ["Marketplace unavailable"])
        XCTAssertEqual(Marketplace.tradesy.listingPlaybook.requiredFields, ["Marketplace unavailable"])
    }

    func testMarketplaceCatalogProvidesNativeSystemIconSymbols() {
        let expectedSymbols: [Marketplace: String] = [
            .ebay: "cart.fill",
            .craigslist: "mappin.circle.fill",
            .facebook: "person.2.fill",
            .poshmark: "tshirt.fill",
            .mercari: "shippingbox.fill",
            .offerup: "mappin.circle.fill",
            .depop: "tshirt.fill",
            .whatnot: "play.rectangle.fill",
            .grailed: "tshirt.fill",
            .reverb: "music.note",
            .etsy: "paintpalette.fill",
            .stockx: "checkmark.seal.fill",
            .goat: "checkmark.seal.fill",
            .kidizen: "tshirt.fill",
            .vinted: "tshirt.fill",
            .vestiaire: "handbag.fill",
            .therealreal: "handbag.fill",
            .swappa: "iphone",
            .tradesy: "handbag.fill",
            .chairish: "house.fill",
            .bonanza: "cart.fill",
            .curtsy: "tshirt.fill",
            .nextdoor: "mappin.circle.fill",
            .amazon: "cart.fill",
            .shopify: "cart.fill",
            .rubylane: "clock.fill",
            .tcgplayer: "rectangle.stack.fill"
        ]

        XCTAssertEqual(Set(expectedSymbols.keys), Set(Marketplace.allCases))

        for marketplace in Marketplace.allCases {
            XCTAssertEqual(marketplace.iconSystemName, expectedSymbols[marketplace], marketplace.displayName)
            XCTAssertFalse(marketplace.iconSystemName.isEmpty, marketplace.displayName)
            XCTAssertTrue(
                AppSymbol.familiarSellingSymbols.contains(marketplace.iconSystemName),
                "\(marketplace.displayName) should use the shared familiar icon vocabulary."
            )
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

    func testMarketplaceComparisonNamesMissingSoldPricesWithoutInventingSales() {
        let comparison = MarketplaceComparison(
            marketplace: .ebay,
            listPrice: Decimal(100),
            expectedSpeed: "Steady sale",
            shippingExpectation: "Easy shipping",
            evidenceStatus: .limited
        )

        XCTAssertNil(comparison.soldPriceRange(currencyCode: "USD"))
        XCTAssertEqual(comparison.soldPriceSignal(currencyCode: "USD"), "No sold prices found")
        XCTAssertEqual(
            comparison.rowSignal(currencyCode: "USD"),
            "List around \(Decimal(100).currency(code: "USD")) · No sold prices found · Steady sale"
        )
        XCTAssertEqual(
            comparison.accessibilitySignal(currencyCode: "USD"),
            "List around \(Decimal(100).currency(code: "USD")), No sold prices found, Steady sale"
        )
        XCTAssertEqual(
            comparison.marketEvidenceFacts(currencyCode: "USD"),
            [
                MarketplaceEvidenceFact(label: "Evidence", value: "No verified sold comps"),
                MarketplaceEvidenceFact(label: "Sold", value: "No sold prices found"),
                MarketplaceEvidenceFact(label: "Speed", value: "Steady sale"),
                MarketplaceEvidenceFact(label: "Shipping", value: "Easy shipping")
            ]
        )

        let soldComparison = MarketplaceComparison(
            marketplace: .ebay,
            compMedianPrice: Decimal(84),
            evidenceStatus: .grounded
        )
        XCTAssertEqual(soldComparison.soldPriceSignal(currencyCode: "USD"), "Typical sold price \(Decimal(84).currency(code: "USD"))")
        XCTAssertEqual(soldComparison.verifiedSoldPriceSignal(currencyCode: "USD"), "No sold prices found")
        XCTAssertEqual(
            soldComparison.marketEvidenceFacts(currencyCode: "USD"),
            [
                MarketplaceEvidenceFact(label: "Evidence", value: "No verified sold comps"),
                MarketplaceEvidenceFact(label: "Sold", value: "No sold prices found")
            ]
        )

        let groundedWithoutSoldPrices = MarketplaceComparison(
            marketplace: .ebay,
            evidenceStatus: .grounded,
            evidenceSources: [
                ListingEvidenceSource(
                    sourceMarketplace: "eBay",
                    title: "Active lamp",
                    dateChecked: "2026-07-25",
                    listingStatus: "active",
                    price: Decimal(99)
                )
            ]
        )
        XCTAssertEqual(
            groundedWithoutSoldPrices.marketEvidenceFacts(currencyCode: "USD").first,
            MarketplaceEvidenceFact(label: "Evidence", value: "No verified sold comps")
        )

        let soldRangeComparison = MarketplaceComparison(
            marketplace: .ebay,
            compLowPrice: Decimal(70),
            compHighPrice: Decimal(120),
            evidenceStatus: .grounded
        )
        XCTAssertEqual(
            soldRangeComparison.soldPriceSignal(currencyCode: "USD"),
            "Sold prices \(Decimal(70).currency(code: "USD")) to \(Decimal(120).currency(code: "USD"))"
        )
    }

    func testMarketplaceComparisonBuildsCompactEvidenceFactsForPickerRows() {
        let comparison = MarketplaceComparison(
            marketplace: .ebay,
            listPrice: Decimal(100),
            likelyRangeLow: Decimal(85),
            likelyRangeHigh: Decimal(115),
            compLowPrice: Decimal(70),
            compHighPrice: Decimal(120),
            expectedSpeed: "Steady sale",
            shippingExpectation: "Easy shipping",
            feeSummary: "Final value fee applies.",
            evidenceStatus: .grounded,
            evidenceSources: [
                ListingEvidenceSource(
                    sourceMarketplace: "eBay",
                    title: "Sold brass lamp",
                    url: "https://example.com/sold-brass-lamp",
                    dateChecked: "2026-07-25",
                    listingStatus: "sold",
                    conditionAndVariant: "Good brass lamp",
                    comparability: "Close match",
                    price: Decimal(90)
                )
            ]
        )

        XCTAssertEqual(
            comparison.marketEvidenceFacts(currencyCode: "USD"),
            [
                MarketplaceEvidenceFact(label: "Evidence", value: "Sold comps checked"),
                MarketplaceEvidenceFact(label: "Sources", value: "1 source(s) · Checked 2026-07-25"),
                MarketplaceEvidenceFact(label: "Range", value: "\(Decimal(85).currency(code: "USD")) to \(Decimal(115).currency(code: "USD"))"),
                MarketplaceEvidenceFact(label: "Sold", value: "Sold prices \(Decimal(70).currency(code: "USD")) to \(Decimal(120).currency(code: "USD"))"),
                MarketplaceEvidenceFact(label: "Fees", value: "Final value fee applies."),
                MarketplaceEvidenceFact(label: "Speed", value: "Steady sale"),
                MarketplaceEvidenceFact(label: "Shipping", value: "Easy shipping")
            ]
        )
        XCTAssertEqual(
            comparison.marketEvidenceAccessibilityText(currencyCode: "USD"),
            "Evidence: Sold comps checked, Sources: 1 source(s) · Checked 2026-07-25, Range: \(Decimal(85).currency(code: "USD")) to \(Decimal(115).currency(code: "USD")), Sold: Sold prices \(Decimal(70).currency(code: "USD")) to \(Decimal(120).currency(code: "USD")), Fees: Final value fee applies., Speed: Steady sale, Shipping: Easy shipping"
        )
    }

    func testMarketplaceComparisonEvidenceFactsRequireVerifiedSoldSourceForSoldComps() {
        let missingDate = MarketplaceComparison(
            marketplace: .ebay,
            compMedianPrice: Decimal(84),
            evidenceStatus: .grounded,
            evidenceSources: [
                ListingEvidenceSource(
                    sourceMarketplace: "eBay",
                    title: "Sold lamp",
                    url: "https://example.com/sold-lamp",
                    listingStatus: "sold",
                    price: Decimal(84)
                )
            ]
        )

        XCTAssertEqual(missingDate.verifiedSoldPriceSignal(currencyCode: "USD"), "No sold prices found")
        XCTAssertEqual(missingDate.verifiedRowSignal(currencyCode: "USD"), "No sold prices found")
        XCTAssertEqual(
            missingDate.marketEvidenceFacts(currencyCode: "USD").first,
            MarketplaceEvidenceFact(label: "Evidence", value: "No verified sold comps")
        )

        let missingReference = MarketplaceComparison(
            marketplace: .ebay,
            compMedianPrice: Decimal(84),
            evidenceStatus: .grounded,
            evidenceSources: [
                ListingEvidenceSource(
                    sourceMarketplace: "eBay",
                    dateChecked: "2026-07-25",
                    listingStatus: "sold",
                    price: Decimal(84)
                )
            ]
        )

        XCTAssertEqual(missingReference.verifiedSoldPriceSignal(currencyCode: "USD"), "No sold prices found")
    }

    func testMarketplaceComparisonEvidenceFactsIncludeSourceCountAndSharedCheckedDate() {
        let comparison = MarketplaceComparison(
            marketplace: .ebay,
            compMedianPrice: Decimal(84),
            evidenceStatus: .grounded,
            evidenceSources: [
                ListingEvidenceSource(
                    sourceMarketplace: "eBay",
                    title: "Sold lamp",
                    dateChecked: "2026-07-25",
                    listingStatus: "sold",
                    conditionAndVariant: "Good brass lamp",
                    comparability: "Close match",
                    price: Decimal(80)
                ),
                ListingEvidenceSource(
                    sourceMarketplace: "eBay",
                    title: "Another sold lamp",
                    dateChecked: "2026-07-25",
                    listingStatus: "sold",
                    conditionAndVariant: "Good brass lamp",
                    comparability: "Similar",
                    price: Decimal(88)
                )
            ]
        )

        XCTAssertEqual(
            Array(comparison.marketEvidenceFacts(currencyCode: "USD").prefix(3)),
            [
                MarketplaceEvidenceFact(label: "Evidence", value: "Sold comps checked"),
                MarketplaceEvidenceFact(label: "Sources", value: "2 source(s) · Checked 2026-07-25"),
                MarketplaceEvidenceFact(label: "Sold", value: "Typical sold price \(Decimal(84).currency(code: "USD"))")
            ]
        )
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

    func testSummaryPlannerBuildsUsefulDistinctComparisonLabels() throws {
        let guitar = DetectedItem(
            name: "Fender Stratocaster Electric Guitar",
            category: .music,
            condition: .good,
            priceEstimate: Decimal(650)
        )

        let ranked = MarketplaceEstimator.estimates(for: guitar)
        let picks = MarketplaceSummaryPlanner.picks(from: ranked, item: guitar)

        XCTAssertEqual(picks.map(\.kind), [.bestOverall, .mostMoney, .fastestSale, .easiestOption])
        XCTAssertEqual(picks.first?.estimate.id, .reverb)
        XCTAssertEqual(picks[1].estimate.payout, ranked.map(\.payout).max())
        XCTAssertEqual(Set(picks.map(\.estimate.id)).count, picks.count)
    }

    func testSummaryPlannerKeepsSpecificLabelsWhenBestOverallAlsoPaysMost() {
        let lamp = DetectedItem(
            name: "Vintage brass table lamp",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )

        let picks = MarketplaceSummaryPlanner.picks(
            from: MarketplaceEstimator.estimates(for: lamp),
            item: lamp
        )

        XCTAssertEqual(picks.map(\.kind), [.bestOverall, .mostMoney, .fastestSale, .easiestOption])
        XCTAssertEqual(picks.first?.estimate.id, .craigslist)
        XCTAssertEqual(Set(picks.map(\.estimate.id)).count, picks.count)
    }

    func testSummaryPlannerUsesGroundedRecommendationLabelsBeforeLocalHeuristics() {
        let lamp = DetectedItem(
            name: "Vintage brass table lamp",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )
        let estimates = MarketplaceEstimator.estimates(for: lamp)
        let comparisons: [Marketplace: MarketplaceComparison] = [
            .ebay: MarketplaceComparison(
                marketplace: .ebay,
                recommendationLabel: "Best overall",
                marketplaceFitScore: 96,
                evidenceStatus: .limited
            ),
            .mercari: MarketplaceComparison(
                marketplace: .mercari,
                recommendationLabel: "Most money",
                marketplaceFitScore: 88,
                evidenceStatus: .limited
            ),
            .facebook: MarketplaceComparison(
                marketplace: .facebook,
                recommendationLabel: "Fastest sale",
                marketplaceFitScore: 91,
                evidenceStatus: .limited
            ),
            .nextdoor: MarketplaceComparison(
                marketplace: .nextdoor,
                recommendationLabel: "Easiest option",
                marketplaceFitScore: 84,
                evidenceStatus: .limited
            )
        ]

        let picks = MarketplaceSummaryPlanner.picks(
            from: estimates,
            item: lamp,
            comparisons: comparisons
        )

        XCTAssertEqual(picks.map(\.kind), [.bestOverall, .mostMoney, .fastestSale, .easiestOption])
        XCTAssertEqual(picks.map(\.estimate.id), [.ebay, .mercari, .facebook, .nextdoor])
        XCTAssertEqual(Set(picks.map(\.estimate.id)).count, picks.count)
    }

    func testSummaryPlannerIgnoresUnavailableGroundedRecommendationLabels() {
        let phone = DetectedItem(
            name: "iPhone 15 128 GB",
            category: .electronics,
            condition: .good,
            priceEstimate: Decimal(520)
        )
        let estimates = MarketplaceEstimator.estimates(for: phone)
        let localBest = estimates.first?.id
        let comparisons: [Marketplace: MarketplaceComparison] = [
            .craigslist: MarketplaceComparison(
                marketplace: .craigslist,
                recommendationLabel: "Best overall",
                marketplaceFitScore: 99,
                evidenceStatus: .unavailable
            )
        ]

        let picks = MarketplaceSummaryPlanner.picks(
            from: estimates,
            item: phone,
            comparisons: comparisons
        )

        XCTAssertEqual(picks.first?.kind, .bestOverall)
        XCTAssertEqual(picks.first?.estimate.id, localBest)
        XCTAssertNotEqual(picks.first?.estimate.id, Marketplace.craigslist)
        XCTAssertEqual(Set(picks.map(\.estimate.id)).count, picks.count)
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
            MarketplaceSummaryKind.bestOverall,
            .mostMoney,
            .fastestSale,
            .easiestOption
        ] {
            XCTAssertEqual(localizedStrings[kind.label], kind.label)
            XCTAssertTrue(kind.systemImage.hasSuffix(".fill"), "\(kind.label) should use a filled native symbol.")
        }

        for cue in [
            "List around %@",
            "Fast sale",
            "Steady sale",
            "Slower sale",
            "Local pickup",
            "Easy shipping",
            "Pack carefully",
            "Shipping okay",
            "Evidence",
            "Estimate only",
            "Grounded check",
            "No verified sold comps",
            "Sold comps checked",
            "Sources",
            "%d source(s)",
            "%@ · Checked %@",
            "Market check",
            "Sold price range",
            "Sold prices",
            "No sold prices found",
            "Fee source",
            "Last checked",
            "Fee note",
            "Image search",
            "Reference only",
            "Open reference image",
            "Open fee source",
            "Open source",
            "Source",
            "Source details",
            "Checked %@",
            "Photo check",
            "What does the label say?",
            "What exact detail can you see?",
            "Anything wrong with it?",
            "Fixed price or auction?",
            "Where can someone pick it up?",
            "Any fit or measurement note?",
            "Any maker mark, signature, or label?",
            "Do you know the exact size or SKU?",
            "Is the original box included?",
            "What storage or carrier do you know?",
            "Does it turn on?",
            "Can someone pick it up?",
            "The photo did not clearly show %@. Add it only if you can see it.",
            "Fixed price is easier. Auction can help when the price is hard to judge.",
            "A pickup area, stairs, or loading note keeps messages easier.",
            "A fit note helps clothing feel safer to buy.",
            "A visible mark helps this place trust what the item is.",
            "Exact model, size, and colorway matter here.",
            "Box condition can change what people will pay.",
            "Phones need storage, carrier, battery, unlock status, and condition.",
            "Working condition and obvious scratches need to be clear.",
            "Music gear needs exact model details before the price is reliable.",
            "Music gear listings need working condition and accessories.",
            "Pickup or delivery notes help avoid confusing messages.",
            "Model, storage, carrier, and working condition help match sold prices.",
            "Size, brand, and material help people find the listing.",
            "Edition, maker marks, and condition help match sold prices.",
            "A model number, measurement, or maker mark can change the price.",
            "Charger, cable, box...",
            "Battery, charger, case...",
            "Case, cable, strap...",
            "Box, certificate, sleeve...",
            "Fixed price, auction, shipping note...",
            "Runs small, pit to pit, inseam...",
            "SKU, size, colorway...",
            "Original box, no box, box damage...",
            "128 GB, unlocked, 89% battery...",
            "Turns on, scratches, battery issue...",
            "Works, case, cables, power supply...",
            "Near downtown, pickup only, can help load...",
            "Shows the checks behind this listing.",
            "Show proof",
            "Hide proof",
            "Shows the market checks behind this recommendation.",
            "Proof",
            "Use this to check the item, not as a listing photo.",
            "Use these to check the item. Keep your own photos for the listing.",
            "Reliable sold prices were not available. Use the price plan as an estimate, not a confirmed sale.",
            "Sold prices %@ to %@",
            "%@ to %@",
            "%@, typical %@",
            "Typical %@",
            "Typical sold price %@",
            "From %@",
            "Up to %@"
        ] {
            XCTAssertEqual(localizedStrings[cue], cue)
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
            #"\bplacement\b"#,
            #"\btraffic\b"#,
            #"\bpay for\b"#,
            #"\bpaying for\b"#,
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
