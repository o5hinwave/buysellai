import XCTest
@testable import BuySellAI

@MainActor
final class AppStoreFlowTransitionTests: XCTestCase {
    private let transitionDelay: UInt64 = 20_000_000

    func testCapturedPhotoPresentsSnapResultImmediatelyWithThumbnailData() {
        let store = makeStore()
        let imageData = ImageTools.sampleJPEG()

        store.isShowingCamera = true
        store.handleCapturedPhoto(imageData)

        XCTAssertFalse(store.isShowingCamera)
        XCTAssertEqual(store.snapResultContext?.imageData, imageData)
        XCTAssertNil(store.marketplacePickerContext)
        XCTAssertNil(store.listingContext)
    }

    func testCloseFlowCancelsPendingMarketplacePickerPresentation() async {
        let store = makeStore()

        store.presentMarketplacePicker(item: lamp, imageData: Data([1, 2, 3]))
        store.closeFlow()
        await waitForTransitionTasks()

        XCTAssertNil(store.snapResultContext)
        XCTAssertNil(store.marketplacePickerContext)
        XCTAssertNil(store.listingContext)
        XCTAssertFalse(store.isShowingCamera)
    }

    func testCloseFlowCancelsPendingListingPresentation() async {
        let store = makeStore()

        store.presentListing(item: lamp, imageData: Data([1, 2, 3]), marketplace: .ebay)
        store.closeFlow()
        await waitForTransitionTasks()

        XCTAssertNil(store.snapResultContext)
        XCTAssertNil(store.marketplacePickerContext)
        XCTAssertNil(store.listingContext)
        XCTAssertFalse(store.isShowingCamera)
    }

    func testRetakePhotoCancelsPendingListingPresentationAndShowsCamera() async {
        let store = makeStore()

        store.presentListing(item: lamp, imageData: Data([1, 2, 3]), marketplace: .ebay)
        store.retakePhoto(keeping: .ebay)
        await waitForTransitionTasks()

        XCTAssertNil(store.snapResultContext)
        XCTAssertNil(store.marketplacePickerContext)
        XCTAssertNil(store.listingContext)
        XCTAssertTrue(store.isShowingCamera)
    }

    private var lamp: DetectedItem {
        DetectedItem(
            name: "Lamp",
            category: .home,
            condition: .good,
            priceEstimate: Decimal(45)
        )
    }

    private func makeStore() -> AppStore {
        let suiteName = "AppStoreFlowTransitionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return AppStore(
            defaults: defaults,
            flowTransitionDelayNanoseconds: transitionDelay
        )
    }

    private func waitForTransitionTasks() async {
        try? await Task.sleep(nanoseconds: transitionDelay * 3)
    }
}
