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
            imageData: nil,
            marketplace: .ebay,
            listingText: "  \n\t  "
        )

        XCTAssertTrue(store.history.isEmpty)
        XCTAssertEqual(store.toast?.text, APIError.decoding.localizedDescription)
        store.toast = nil

        var blankNameItem = item
        blankNameItem.name = "  \n\t  "
        store.saveListing(
            item: blankNameItem,
            imageData: nil,
            marketplace: .ebay,
            listingText: "TITLE:\nLamp\n\nDESCRIPTION:\nLamp in good condition."
        )

        XCTAssertTrue(store.history.isEmpty)
        XCTAssertEqual(store.toast?.text, APIError.decoding.localizedDescription)
        store.toast = nil

        var freeItem = item
        freeItem.priceEstimate = Decimal(0)
        store.saveListing(
            item: freeItem,
            imageData: nil,
            marketplace: .ebay,
            listingText: "TITLE:\nLamp\n\nDESCRIPTION:\nLamp in good condition."
        )

        XCTAssertTrue(store.history.isEmpty)
        XCTAssertEqual(store.toast?.text, APIError.decoding.localizedDescription)
        store.toast = nil

        store.saveListing(
            item: item,
            imageData: ImageTools.sampleJPEG(),
            marketplace: .ebay,
            listingText: "TITLE:\nLamp\n\nDESCRIPTION:\nLamp in good condition."
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
        XCTAssertEqual(persistedEntry.listingText, "TITLE:\nLamp\n\nDESCRIPTION:\nLamp in good condition.")
        try assertThumbnailIsCappedAtListingSize(persistedEntry.imageThumbnail)

        store.history.removeAll()
        await store.loadHistory()

        let reloadedEntry = try XCTUnwrap(store.history.first)
        XCTAssertEqual(store.history.count, 1)
        XCTAssertEqual(reloadedEntry.id, immediateEntry.id)
        XCTAssertEqual(reloadedEntry.itemName, "Lamp")
        XCTAssertEqual(store.historySyncState, .idle)
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
        let blankListingEntry = historyEntry(
            id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD") ?? UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_300),
            itemName: "Blank listing",
            marketplace: .ebay,
            listingText: "  \n\t  "
        )
        let blankNameEntry = historyEntry(
            id: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE") ?? UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_400),
            itemName: "  \n\t  ",
            marketplace: .ebay,
            listingText: "TITLE:\nBlank name\n\nDESCRIPTION:\nBlank name in good condition."
        )

        [oldEntry, newestEntry, middleEntry, blankListingEntry, blankNameEntry].forEach { entry in
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

    func testGuestCopyFromReopenedListingUpdatesExistingHistoryRow() async throws {
        let context = try makeModelContext()
        let suiteName = "AppStoreLocalHistoryReopenTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let originalEntry = historyEntry(
            id: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF") ?? UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            itemName: "Desk lamp",
            marketplace: .ebay,
            listingText: "TITLE:\nDesk lamp\n\nDESCRIPTION:\nDesk lamp in good condition.",
            identificationProfile: Self.sampleIdentificationProfile
        )
        context.insert(HistoryEntryModel(entry: originalEntry))
        try context.save()

        let store = AppStore(defaults: defaults)
        store.configure(modelContext: context)
        await store.loadHistory()

        let reopenedEntry = try XCTUnwrap(store.history.first)
        store.reopenListing(reopenedEntry)
        guard case .listing(let listingContext) = store.flowSheetContext else {
            return XCTFail("Expected reopened history entry to present listing context")
        }
        XCTAssertEqual(listingContext.analysis?.identificationProfile?.confirmedFacts, ["Brand: Lumina"])
        XCTAssertEqual(listingContext.analysis?.identificationProfile?.unknownDetails, ["Check base stamp"])

        let updatedItem = DetectedItem(
            name: "Desk lamp",
            category: .home,
            condition: .likeNew,
            priceEstimate: Decimal(60)
        )
        store.saveListing(
            item: updatedItem,
            imageData: nil,
            marketplace: .craigslist,
            listingText: "TITLE:\nUpdated desk lamp\n\nDESCRIPTION:\nUpdated desk lamp in like new condition.",
            replacing: originalEntry
        )

        XCTAssertEqual(store.history.count, 1)
        let visibleEntry = try XCTUnwrap(store.history.first)
        XCTAssertEqual(visibleEntry.id, originalEntry.id)
        XCTAssertEqual(visibleEntry.createdAt, originalEntry.createdAt)
        XCTAssertEqual(visibleEntry.marketplace, .craigslist)
        XCTAssertEqual(visibleEntry.condition, .likeNew)
        XCTAssertEqual(visibleEntry.listingText, "TITLE:\nUpdated desk lamp\n\nDESCRIPTION:\nUpdated desk lamp in like new condition.")
        XCTAssertEqual(visibleEntry.identificationProfile?.confirmedFacts, ["Brand: Lumina"])
        XCTAssertEqual(visibleEntry.identificationProfile?.confidenceState, .stillChecking)

        let models = try context.fetch(FetchDescriptor<HistoryEntryModel>())
        XCTAssertEqual(models.count, 1)
        let persistedEntry = try XCTUnwrap(models.first?.entry)
        XCTAssertEqual(persistedEntry.id, originalEntry.id)
        XCTAssertEqual(persistedEntry.createdAt, originalEntry.createdAt)
        XCTAssertEqual(persistedEntry.marketplace, .craigslist)
        XCTAssertEqual(persistedEntry.listingText, "TITLE:\nUpdated desk lamp\n\nDESCRIPTION:\nUpdated desk lamp in like new condition.")
        XCTAssertEqual(persistedEntry.identificationProfile?.unknownDetails, ["Check base stamp"])
    }

    func testClearHistoryWithoutModelContextStillClearsVisibleRowsAndShowsToast() throws {
        let suiteName = "AppStoreLocalHistoryClearFallbackTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let entry = historyEntry(
            id: UUID(uuidString: "ABBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB") ?? UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            itemName: "Desk lamp",
            marketplace: .ebay
        )
        let store = AppStore(defaults: defaults)
        store.history = [entry]

        store.clearHistory()

        XCTAssertTrue(store.history.isEmpty)
        XCTAssertEqual(store.toast?.text, "History cleared.")
        XCTAssertEqual(store.toast?.style, .success)
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
        marketplace: Marketplace,
        listingText: String? = nil,
        identificationProfile: AnalyzeIdentificationProfile? = nil
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
            listingText: listingText ?? "TITLE:\n\(itemName)\n\nDESCRIPTION:\n\(itemName) in good condition.",
            identificationProfile: identificationProfile
        )
    }

    private static var sampleIdentificationProfile: AnalyzeIdentificationProfile {
        AnalyzeIdentificationProfile(
            confirmedFacts: ["Brand: Lumina"],
            likelyFacts: ["Brass desk lamp"],
            unknownDetails: ["Check base stamp"],
            evidenceNeeded: ["Photo of underside label"],
            confidenceState: .stillChecking
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
