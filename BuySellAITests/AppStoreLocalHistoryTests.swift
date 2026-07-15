import SwiftData
import UIKit
import XCTest
@testable import BuySellAI

@MainActor
final class AppStoreLocalHistoryTests: XCTestCase {
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

    private func makeModelContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: HistoryEntryModel.self, configurations: configuration)
        return ModelContext(container)
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
}
