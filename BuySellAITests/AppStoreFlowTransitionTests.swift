import XCTest
@testable import BuySellAI

@MainActor
final class AppStoreFlowTransitionTests: XCTestCase {
    private let transitionDelay: UInt64 = 20_000_000

    func testCapturedPhotoPresentsSnapResultAfterCameraDismissalWithThumbnailData() {
        let store = makeStore()
        let imageData = ImageTools.sampleJPEG()

        store.isShowingCamera = true
        store.handleCapturedPhoto(imageData)

        XCTAssertFalse(store.isShowingCamera)
        XCTAssertNil(store.snapResultContext)
        XCTAssertNil(store.flowSheetContext)

        store.presentPendingCapturedPhoto()

        XCTAssertEqual(store.snapResultContext?.imageData, imageData)
        XCTAssertNil(store.marketplacePickerContext)
        XCTAssertNil(store.listingContext)
        guard case .snapResult(let context) = store.flowSheetContext else {
            return XCTFail("Expected snap result flow sheet.")
        }
        XCTAssertEqual(context.imageData, imageData)
    }

    func testMarketplacePickerUpdatesSingleFlowSheetImmediately() {
        let store = makeStore()
        let item = lamp
        let imageData = Data([1, 2, 3])
        let analysis = AnalyzeIntelligence(
            itemFacts: [AnalyzeItemFact(label: "Material", value: "Brass", confidence: 0.8)],
            missingFacts: ["maker mark"],
            photoPrompt: "Show the maker mark."
        )

        store.presentMarketplacePicker(item: item, imageData: imageData, analysis: analysis)

        XCTAssertNil(store.snapResultContext)
        XCTAssertEqual(store.marketplacePickerContext?.item, item)
        XCTAssertEqual(store.marketplacePickerContext?.imageData, Optional(imageData))
        XCTAssertEqual(store.marketplacePickerContext?.analysis, analysis)
        XCTAssertNil(store.listingContext)
        guard case .marketplacePicker(let context) = store.flowSheetContext else {
            return XCTFail("Expected marketplace picker flow sheet.")
        }
        XCTAssertEqual(context.item, item)
        XCTAssertEqual(context.imageData, Optional(imageData))
        XCTAssertEqual(context.analysis, analysis)
    }

    func testMarketplacePickerCanOpenFromSavedListingWithoutFullPhotoData() {
        let store = makeStore()
        let item = lamp

        store.presentMarketplacePicker(item: item, imageData: nil)

        XCTAssertNil(store.snapResultContext)
        XCTAssertEqual(store.marketplacePickerContext?.item, item)
        XCTAssertNil(store.marketplacePickerContext?.imageData)
        XCTAssertNil(store.listingContext)
        guard case .marketplacePicker(let context) = store.flowSheetContext else {
            return XCTFail("Expected marketplace picker flow sheet.")
        }
        XCTAssertEqual(context.item, item)
        XCTAssertNil(context.imageData)
    }

    func testListingUpdatesSingleFlowSheetImmediately() {
        let store = makeStore()
        let item = lamp
        let imageData = Data([1, 2, 3])

        store.presentListing(item: item, imageData: imageData, marketplace: .ebay)

        XCTAssertNil(store.snapResultContext)
        XCTAssertNil(store.marketplacePickerContext)
        XCTAssertEqual(store.listingContext?.item, item)
        XCTAssertEqual(store.listingContext?.marketplace, .ebay)
        guard case .listing(let context) = store.flowSheetContext else {
            return XCTFail("Expected listing flow sheet.")
        }
        XCTAssertEqual(context.item, item)
        XCTAssertEqual(context.imageData, imageData)
        XCTAssertEqual(context.marketplace, .ebay)
    }

    func testCloseFlowCancelsPendingMarketplacePickerPresentation() async {
        let store = makeStore()

        store.presentMarketplacePicker(item: lamp, imageData: Data([1, 2, 3]))
        store.closeFlow()
        await waitForTransitionTasks()

        XCTAssertNil(store.snapResultContext)
        XCTAssertNil(store.marketplacePickerContext)
        XCTAssertNil(store.listingContext)
        XCTAssertNil(store.flowSheetContext)
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
        XCTAssertNil(store.flowSheetContext)
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
        XCTAssertNil(store.flowSheetContext)
        XCTAssertTrue(store.isShowingCamera)
    }

    func testSettingsSignInWaitsForSettingsDismissalBeforeShowingAuth() async {
        let store = makeStore()

        store.presentSettings()
        XCTAssertTrue(store.isShowingSettings)

        store.presentAuthAfterSettingsDismissal()
        XCTAssertFalse(store.isShowingSettings)
        XCTAssertFalse(store.isShowingAuth)

        await waitForTransitionTasks()

        XCTAssertTrue(store.isShowingAuth)
        XCTAssertFalse(store.isShowingSettings)
    }

    func testSettingsTutorialWaitsForSettingsDismissalBeforeShowingTutorial() async {
        let store = makeStore()

        store.presentSettings()
        XCTAssertTrue(store.isShowingSettings)

        store.presentTutorialAfterSettingsDismissal()
        XCTAssertFalse(store.isShowingSettings)
        XCTAssertFalse(store.isShowingTutorial)

        await waitForTransitionTasks()

        XCTAssertTrue(store.isShowingTutorial)
        XCTAssertFalse(store.isShowingSettings)
    }

    func testNewModalPresentationCancelsPendingSettingsAuthPresentation() async {
        let store = makeStore()

        store.presentSettings()
        store.presentAuthAfterSettingsDismissal()
        store.presentSettings()

        await waitForTransitionTasks()

        XCTAssertFalse(store.isShowingAuth)
        XCTAssertTrue(store.isShowingSettings)
    }

    func testSignedInSessionCancelsPendingSettingsAuthPresentation() async {
        let store = makeStore()

        store.presentSettings()
        store.presentAuthAfterSettingsDismissal()
        await store.setSession(AuthSession(userID: "user-123", email: "person@example.com"))

        await waitForTransitionTasks()

        XCTAssertFalse(store.isShowingAuth)
        XCTAssertFalse(store.isShowingSettings)
        XCTAssertEqual(store.session?.userID, "user-123")
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
