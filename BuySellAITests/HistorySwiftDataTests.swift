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
        let entry = HistoryEntry(
            id: UUID(),
            createdAt: Date(),
            itemName: "Lamp",
            category: .home,
            condition: .good,
            suggestedPrice: suggestedPrice,
            imageThumbnail: Data([1, 2, 3]),
            marketplace: .ebay,
            listingText: "TITLE:\nLamp\n\nDESCRIPTION:\nLamp in good condition."
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
    }
}
