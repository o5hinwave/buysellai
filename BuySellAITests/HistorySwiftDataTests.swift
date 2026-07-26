import SwiftData
import XCTest
@testable import BuySellAI

@MainActor
final class HistorySwiftDataTests: XCTestCase {
    func testHistoryEntryRoundTripsThroughSwiftDataModel() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HistoryEntryModel.self, configurations: configuration)
        let context = ModelContext(container)

        let suggestedPrice = try XCTUnwrap(Decimal(string: "19.99", locale: Locale(identifier: "en_US_POSIX")))
        let identificationProfile = AnalyzeIdentificationProfile(
            confirmedFacts: ["Brand: BrightHome", "Material: brass"],
            likelyFacts: ["Likely 1970s style"],
            unknownDetails: ["Check base stamp"],
            evidenceNeeded: ["Photo of underside label"],
            confidenceState: .stillChecking
        )
        let entry = HistoryEntry(
            id: UUID(),
            createdAt: Date(),
            itemName: "Lamp",
            category: .home,
            condition: .good,
            suggestedPrice: suggestedPrice,
            imageThumbnail: Data([1, 2, 3]),
            marketplace: .ebay,
            listingText: "TITLE:\nLamp\n\nDESCRIPTION:\nLamp in good condition.",
            itemDetails: ItemDetailAnswers(labelOrBrand: "Brass", flaws: "Small scratch"),
            marketplaceComparison: MarketplaceComparison(
                marketplace: .ebay,
                recommendationLabel: "Best overall",
                listPrice: Decimal(48),
                takeHomeEstimate: Decimal(41),
                compLowPrice: Decimal(38),
                compMedianPrice: Decimal(42),
                compHighPrice: Decimal(55),
                feeSummary: "Fees estimated from marketplace rules.",
                evidenceSummary: "Checked recent sold lamps.",
                evidenceStatus: .grounded,
                evidenceSources: [
                    ListingEvidenceSource(
                        sourceMarketplace: "eBay",
                        title: "Sold brass lamp",
                        url: "https://example.com/sold-lamp",
                        dateChecked: "2026-07-24",
                        listingStatus: "sold",
                        conditionAndVariant: "Good brass lamp",
                        comparability: "Close match",
                        price: Decimal(42)
                    )
                ]
            ),
            listingDraft: GeneratedListingDraft(
                title: "Brass Lamp",
                description: "Brass lamp in good condition.",
                evidenceSummary: "Checked recent sold lamps.",
                evidenceSources: [
                    ListingEvidenceSource(
                        sourceMarketplace: "eBay",
                        title: "Sold brass lamp",
                        url: "https://example.com/sold-lamp",
                        dateChecked: "2026-07-24",
                        listingStatus: "sold",
                        conditionAndVariant: "Good brass lamp",
                        comparability: "Close match",
                        price: Decimal(42)
                    )
                ]
            ),
            identificationProfile: identificationProfile,
            supplementalPhotos: [
                ItemPhotoAsset(
                    itemID: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                    imageData: ImageTools.sampleJPEG(),
                    source: .camera,
                    role: .label,
                    verifies: "Model label: BL-42",
                    isListingSafe: true
                )
            ]
        )

        context.insert(HistoryEntryModel(entry: entry))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<HistoryEntryModel>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].entry.itemName, "Lamp")
        XCTAssertEqual(fetched[0].entry.category, .home)
        XCTAssertEqual(fetched[0].suggestedPriceRawValue, "19.99")
        XCTAssertEqual(fetched[0].entry.suggestedPrice, suggestedPrice)
        XCTAssertEqual(fetched[0].entry.marketplace, .ebay)
        XCTAssertEqual(fetched[0].entry.listingText, "TITLE:\nLamp\n\nDESCRIPTION:\nLamp in good condition.")
        XCTAssertEqual(fetched[0].entry.itemDetails?.labelOrBrand, "Brass")
        XCTAssertEqual(fetched[0].entry.marketplaceComparison?.recommendationLabel, "Best overall")
        XCTAssertEqual(fetched[0].entry.marketplaceComparison?.compMedianPrice, Decimal(42))
        XCTAssertEqual(fetched[0].entry.marketplaceComparison?.evidenceSources?.first?.listingStatus, "sold")
        XCTAssertEqual(fetched[0].entry.listingDraft?.evidenceSummary, "Checked recent sold lamps.")
        XCTAssertEqual(fetched[0].entry.listingDraft?.evidenceSources?.first?.listingStatus, "sold")
        XCTAssertEqual(fetched[0].entry.identificationProfile?.confirmedFacts, ["Brand: BrightHome", "Material: brass"])
        XCTAssertEqual(fetched[0].entry.identificationProfile?.unknownDetails, ["Check base stamp"])
        XCTAssertEqual(fetched[0].entry.identificationProfile?.confidenceState, .stillChecking)
        XCTAssertEqual(fetched[0].entry.supplementalPhotos.count, 1)
        XCTAssertEqual(fetched[0].entry.supplementalPhotos.first?.role, .label)
        XCTAssertEqual(fetched[0].entry.supplementalPhotos.first?.verifies, "Model label: BL-42")
        XCTAssertFalse(fetched[0].entry.supplementalPhotos.first?.imageData?.isEmpty ?? true)
    }
}
