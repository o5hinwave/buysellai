import XCTest
@testable import BuySellAI

final class ModelFormattingTests: XCTestCase {
    func testCategoryDisplayIsLocalizedButAPIValueStaysBackendStable() {
        XCTAssertEqual(Category.home.display, "Home")
        XCTAssertEqual(Category.home.apiValue, "Home")
        XCTAssertEqual(
            Category.allCases.map(\.apiValue),
            [
                "Electronics", "Furniture", "Clothing", "Shoes", "Bags", "Jewelry",
                "Toys", "Kids", "Home", "Tools", "Sports", "Books", "Media", "Music",
                "Collectibles", "Art", "Other"
            ]
        )
        XCTAssertEqual(Category(apiValue: "Home"), .home)
        XCTAssertEqual(Category(apiValue: "home"), .home)
        XCTAssertEqual(Category(apiValue: "Collectibles"), .collectibles)
        XCTAssertEqual(Category.knownAPIValue("Home"), .home)
        XCTAssertEqual(Category.knownAPIValue("home"), .home)
        XCTAssertEqual(Category.knownAPIValue("collectibles"), .collectibles)
        XCTAssertNil(Category.knownAPIValue("Pets"))
        XCTAssertEqual(Category(apiValue: "Pets"), .other)
    }

    func testConditionDisplayIsLocalizedButAPIValueStaysBackendStable() {
        XCTAssertEqual(Condition.likeNew.display, "Like New")
        XCTAssertEqual(Condition.likeNew.apiValue, "likeNew")
        XCTAssertEqual(Condition.good.display, "Good")
        XCTAssertEqual(Condition.good.apiValue, "good")
        XCTAssertEqual(Condition(apiValue: "Like New"), .likeNew)
        XCTAssertEqual(Condition(apiValue: "for_parts"), .forParts)
        XCTAssertEqual(Condition.knownAPIValue("Like New"), .likeNew)
        XCTAssertEqual(Condition.knownAPIValue("for_parts"), .forParts)
        XCTAssertNil(Condition.knownAPIValue("broken"))
        XCTAssertEqual(Condition(apiValue: "broken"), .good)
    }

    func testThemePreferenceDisplayIsLocalizedAndRawValuesStayPersistent() {
        XCTAssertEqual(ThemePreference.system.display, "System")
        XCTAssertEqual(ThemePreference.light.display, "Light")
        XCTAssertEqual(ThemePreference.dark.display, "Dark")
        XCTAssertEqual(ThemePreference.allCases.map(\.rawValue), ["system", "light", "dark"])
    }

    func testDecimalCurrencyFormattingAvoidsDoublePrecisionLoss() throws {
        let value = try XCTUnwrap(Decimal(string: "9007199254740993"))

        XCTAssertEqual(
            value.currency(),
            value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        )
        XCTAssertNotEqual(
            value.currency(),
            value.doubleValue.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        )
    }

    func testDecimalCurrencyFormattingSupportsFractionDigits() throws {
        let value = try XCTUnwrap(Decimal(string: "45.5"))

        XCTAssertEqual(
            value.currency(fractionLength: 2),
            value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
        )
    }

    func testItemDetailAnswersRememberHandledUnknownsWithoutBoostingFactQuality() throws {
        var answers = ItemDetailAnswers()

        answers.markAnswered(.labelOrBrand)
        answers.markAnswered(.largeOrFragile)

        let sanitized = try XCTUnwrap(answers.sanitizedForUse)
        XCTAssertTrue(sanitized.hasAnsweredOrSkipped(.labelOrBrand))
        XCTAssertTrue(sanitized.hasAnsweredOrSkipped(.largeOrFragile))
        XCTAssertFalse(sanitized.hasListingPayloadDetails)
        XCTAssertEqual(sanitized.marketplaceFactQualityBonus, 0)
        XCTAssertEqual(sanitized.displayValues, ["Brand: I don't know", "Large or fragile: No"])

        answers.labelOrBrand = "Stiffel"
        answers.clearAnswered(.labelOrBrand)

        let confirmed = try XCTUnwrap(answers.sanitizedForUse)
        XCTAssertTrue(confirmed.hasListingPayloadDetails)
        XCTAssertEqual(confirmed.marketplaceFactQualityBonus, 4)
        XCTAssertEqual(confirmed.displayValues, ["Brand: Stiffel", "Large or fragile: No"])
    }

    func testItemDetailAnswersKeepMarketplaceNotesSeparate() throws {
        var answers = ItemDetailAnswers(extraDetails: "Brass finish")

        answers.setMarketplaceNote("Prefer fixed price", for: .ebay)
        answers.markMarketplaceAnswered(.facebook)

        let sanitized = try XCTUnwrap(answers.sanitizedForUse)
        XCTAssertEqual(sanitized.extraDetails, "Brass finish")
        XCTAssertEqual(sanitized.marketplaceNote(for: .ebay), "Prefer fixed price")
        XCTAssertTrue(sanitized.hasMarketplaceNoteOrSkipped(.ebay))
        XCTAssertTrue(sanitized.hasMarketplaceNoteOrSkipped(.facebook))
        XCTAssertFalse(sanitized.hasMarketplaceNoteOrSkipped(.poshmark))
        XCTAssertEqual(sanitized.marketplaceFactQualityBonus, 8)
        XCTAssertEqual(
            sanitized.displayValues,
            [
                "Other: Brass finish",
                "eBay: Prefer fixed price",
                "Facebook: I don't know"
            ]
        )
    }

    func testItemDetailAnswersRememberHandledMarketplaceUnknownsWithoutBoostingFactQuality() throws {
        var answers = ItemDetailAnswers()

        answers.markMarketplaceAnswered(.facebook)

        let sanitized = try XCTUnwrap(answers.sanitizedForUse)
        XCTAssertTrue(sanitized.hasMarketplaceNoteOrSkipped(.facebook))
        XCTAssertFalse(sanitized.hasListingPayloadDetails)
        XCTAssertEqual(sanitized.marketplaceFactQualityBonus, 0)
        XCTAssertEqual(sanitized.displayValues, ["Facebook: I don't know"])
    }

    func testItemDetailAnswersDecodeOldPayloadWithoutMarketplaceNotes() throws {
        let data = Data(
            """
            {
              "labelOrBrand": "Stiffel",
              "sizeOrModel": "",
              "flaws": "",
              "included": "",
              "extraDetails": "",
              "isLargeOrFragile": false,
              "answeredFieldKeys": ["labelOrBrand"]
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(ItemDetailAnswers.self, from: data)
        XCTAssertEqual(decoded.labelOrBrand, "Stiffel")
        XCTAssertTrue(decoded.marketplaceNotes.isEmpty)
        XCTAssertTrue(decoded.answeredMarketplaces.isEmpty)
    }

    func testItemDetailAnswersRoundTripMarketplaceNotes() throws {
        let answers = ItemDetailAnswers(
            marketplaceNotes: [.ebay: "Prefer fixed price", .facebook: "Can deliver nearby"],
            answeredMarketplaces: [.ebay, .facebook]
        )

        let data = try JSONEncoder().encode(answers)
        let decoded = try JSONDecoder().decode(ItemDetailAnswers.self, from: data)

        XCTAssertEqual(decoded.marketplaceNote(for: .ebay), "Prefer fixed price")
        XCTAssertEqual(decoded.marketplaceNote(for: .facebook), "Can deliver nearby")
        XCTAssertTrue(decoded.hasMarketplaceNoteOrSkipped(.ebay))
        XCTAssertTrue(decoded.hasMarketplaceNoteOrSkipped(.facebook))
    }
}
