import SwiftData
import UIKit
import XCTest
@testable import BuySellAI

@MainActor
final class AppStoreLocalHistoryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        clearStoredSession()
    }

    override func tearDown() {
        clearStoredSession()
        super.tearDown()
    }

    func testGuestSaveListingStoresImmediateThumbnailAndPersistsLocally() async throws {
        let context = try makeModelContext()
        let suiteName = "AppStoreLocalHistoryTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = AppStore(defaults: defaults)
        store.configure(modelContext: context)

        let item = DetectedItem(
            name: "Lamp",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )
        store.saveListing(
            item: item,
            imageData: ImageTools.sampleJPEG(),
            marketplace: .ebay,
            listingText: "TITLE:\nLamp"
        )

        let immediateEntry = try XCTUnwrap(store.history.first)
        XCTAssertEqual(store.history.count, 1)
        XCTAssertEqual(immediateEntry.itemName, "Lamp")
        XCTAssertEqual(immediateEntry.marketplace, .ebay)
        try assertThumbnailIsCappedAtListingSize(immediateEntry.imageThumbnail)

        let models = try context.fetch(FetchDescriptor<HistoryEntryModel>())
        XCTAssertEqual(models.count, 1)
        let persistedEntry = try XCTUnwrap(models.first?.entry)
        XCTAssertEqual(persistedEntry.id, immediateEntry.id)
        XCTAssertEqual(persistedEntry.listingText, "TITLE:\nLamp")
        try assertThumbnailIsCappedAtListingSize(persistedEntry.imageThumbnail)

        store.history.removeAll()
        await store.loadHistory()

        let reloadedEntry = try XCTUnwrap(store.history.first)
        XCTAssertEqual(store.history.count, 1)
        XCTAssertEqual(reloadedEntry.id, immediateEntry.id)
        XCTAssertEqual(reloadedEntry.itemName, "Lamp")
        try assertThumbnailIsCappedAtListingSize(reloadedEntry.imageThumbnail)
    }

    func testGuestHistoryReloadsNewestFirstForMultipleRows() async throws {
        let context = try makeModelContext()
        let suiteName = "AppStoreLocalHistoryOrderingTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let oldEntry = historyEntry(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA") ?? UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            itemName: "Desk lamp",
            marketplace: .ebay
        )
        let newestEntry = historyEntry(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB") ?? UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_200),
            itemName: "Oak chair",
            marketplace: .craigslist
        )
        let middleEntry = historyEntry(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC") ?? UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            itemName: "Coffee mug",
            marketplace: .facebook
        )

        [oldEntry, newestEntry, middleEntry].forEach { entry in
            context.insert(HistoryEntryModel(entry: entry))
        }
        try context.save()

        let store = AppStore(defaults: defaults)
        store.configure(modelContext: context)
        await store.loadHistory()

        XCTAssertEqual(store.history.map(\.id), [newestEntry.id, middleEntry.id, oldEntry.id])
        XCTAssertEqual(store.history.map(\.itemName), ["Oak chair", "Coffee mug", "Desk lamp"])
        XCTAssertEqual(store.history.map(\.marketplace), [.craigslist, .facebook, .ebay])
    }

    private func makeModelContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HistoryEntryModel.self, configurations: configuration)
        return ModelContext(container)
    }

    private func historyEntry(
        id: UUID,
        createdAt: Date,
        itemName: String,
        marketplace: Marketplace
    ) -> HistoryEntry {
        HistoryEntry(
            id: id,
            createdAt: createdAt,
            itemName: itemName,
            category: .home,
            condition: .good,
            suggestedPrice: Decimal(25),
            imageThumbnail: ImageTools.jpegDataDownscaled(from: ImageTools.sampleJPEG(), maxLongEdge: 200, compression: 0.75),
            marketplace: marketplace,
            listingText: "TITLE:\n\(itemName)"
        )
    }

    private func assertThumbnailIsCappedAtListingSize(
        _ data: Data?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let thumbnail = try XCTUnwrap(data, file: file, line: line)
        let decoded = try XCTUnwrap(UIImage(data: thumbnail)?.cgImage, file: file, line: line)
        XCTAssertEqual(max(decoded.width, decoded.height), 200, file: file, line: line)
        XCTAssertEqual(min(decoded.width, decoded.height), 150, file: file, line: line)
    }

    private func clearStoredSession() {
        Keychain.delete("appleUserID")
        Keychain.delete("authUserID")
        Keychain.delete("authEmail")
        Keychain.delete("supabaseAccessToken")
        Keychain.delete("supabaseRefreshToken")
    }
}
