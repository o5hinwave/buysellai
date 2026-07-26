import XCTest
import UIKit
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

    func testTargetedScanReturnsToItemQuestionsWithSupplementalPhotoAndOriginalPhotoPreserved() async throws {
        let store = makeStore()
        let originalData = Data([1, 2, 3])
        let scanData = Data([9, 9, 9])
        let analysis = AnalyzeIntelligence(
            itemFacts: [],
            missingFacts: ["barcode"],
            photoPrompt: "Scan the barcode"
        )
        let comparison = MarketplaceComparison(
            marketplace: .ebay,
            recommendationLabel: "Best overall",
            evidenceStatus: .grounded,
            evidenceSources: [
                ListingEvidenceSource(
                    sourceMarketplace: "eBay",
                    title: "Sold lamp comp",
                    url: "https://example.com/sold-lamp",
                    dateChecked: "2026-07-25",
                    listingStatus: "Sold",
                    comparability: "Close match",
                    price: Decimal(42)
                )
            ]
        )

        store.presentItemQuestions(
            item: lamp,
            imageData: originalData,
            preferredMarketplace: .ebay,
            marketplaceComparison: comparison,
            analysis: analysis,
            answers: ItemDetailAnswers()
        )
        let context = try XCTUnwrap(store.itemQuestionsContext)
        let request = try XCTUnwrap(analysis.targetedScanRequest)

        store.startTargetedScan(
            request: request,
            context: context,
            answers: ItemDetailAnswers()
        )
        XCTAssertTrue(store.isShowingCamera)

        store.handleCapturedPhoto(scanData)
        store.presentPendingCapturedPhoto()
        await waitForTransitionTasks()

        let updated = try XCTUnwrap(store.itemQuestionsContext)
        XCTAssertEqual(updated.item, lamp)
        XCTAssertEqual(updated.imageData, originalData)
        XCTAssertEqual(updated.supplementalPhotos.count, 1)
        XCTAssertEqual(updated.supplementalPhotos.first?.itemID, lamp.id)
        XCTAssertEqual(updated.supplementalPhotos.first?.role, .label)
        XCTAssertEqual(updated.supplementalPhotos.first?.imageData, scanData)
        XCTAssertEqual(updated.marketplaceComparison, comparison)
        XCTAssertTrue(updated.answers?.hasAnsweredOrSkipped(.targetedScan) ?? false)
        guard case .itemQuestions(let flowContext) = store.flowSheetContext else {
            return XCTFail("Expected item questions flow sheet.")
        }
        XCTAssertEqual(flowContext.imageData, originalData)
        XCTAssertEqual(flowContext.supplementalPhotos.first?.imageData, scanData)
        XCTAssertEqual(flowContext.marketplaceComparison, comparison)
    }

    func testMarketplaceTargetedScanUsesSeparateAnsweredMarker() async throws {
        let store = makeStore()
        let originalData = Data([1, 2, 3])
        let scanData = Data([8, 8, 8])
        var answers = ItemDetailAnswers()
        answers.markAnswered(.targetedScan)

        store.presentItemQuestions(
            item: lamp,
            imageData: originalData,
            preferredMarketplace: .facebook,
            answers: answers
        )
        let context = try XCTUnwrap(store.itemQuestionsContext)
        let request = TargetedScanRequest(
            prompt: "Show the whole item",
            benefit: "Buyers will want to see this.",
            role: .fullItem
        )

        store.startTargetedScan(
            request: request,
            context: context,
            answers: answers,
            answeredField: .marketplaceTargetedScan
        )
        store.handleCapturedPhoto(scanData)
        store.presentPendingCapturedPhoto()
        await waitForTransitionTasks()

        let updated = try XCTUnwrap(store.itemQuestionsContext)
        XCTAssertTrue(updated.answers?.hasAnsweredOrSkipped(.targetedScan) ?? false)
        XCTAssertTrue(updated.answers?.hasAnsweredOrSkipped(.marketplaceTargetedScan) ?? false)
        XCTAssertEqual(updated.supplementalPhotos.first?.role, .fullItem)
        XCTAssertEqual(updated.imageData, originalData)
    }

    func testPoorTargetedScanShowsReviewBeforeAttachingPhotoAndUsePhotoContinues() async throws {
        let store = makeStore()
        let originalData = Data([1, 2, 3])
        let scanData = try makeSolidJPEG(color: UIColor(white: 0.05, alpha: 1))
        let request = TargetedScanRequest(
            prompt: "Scan the model label.",
            benefit: "This can confirm the exact model.",
            role: .label
        )

        store.presentItemQuestions(
            item: lamp,
            imageData: originalData,
            analysis: AnalyzeIntelligence(itemFacts: [], missingFacts: ["model"], photoPrompt: request.prompt),
            answers: ItemDetailAnswers()
        )
        let context = try XCTUnwrap(store.itemQuestionsContext)

        store.startTargetedScan(request: request, context: context, answers: ItemDetailAnswers())
        store.handleCapturedPhoto(scanData)
        store.presentPendingCapturedPhoto()
        await waitForTransitionTasks()

        guard case .targetedScanReview(let review) = store.flowSheetContext else {
            return XCTFail("Expected targeted scan review before accepting poor photo.")
        }
        XCTAssertEqual(review.imageData, scanData)
        XCTAssertEqual(review.request, request)
        XCTAssertEqual(review.fixPrompt, "Move it into better light.")
        XCTAssertEqual(store.itemQuestionsContext?.supplementalPhotos.count, 0)

        store.useTargetedScanPhoto()

        let updated = try XCTUnwrap(store.itemQuestionsContext)
        XCTAssertEqual(updated.supplementalPhotos.count, 1)
        XCTAssertEqual(updated.supplementalPhotos.first?.imageData, scanData)
        XCTAssertTrue(updated.answers?.hasAnsweredOrSkipped(.targetedScan) ?? false)
    }

    func testPoorTargetedScanReviewCanRetakeSameRequestWithoutSavingPhoto() async throws {
        let store = makeStore()
        let scanData = try makeSolidJPEG(color: UIColor(white: 0.05, alpha: 1))
        let request = TargetedScanRequest(
            prompt: "Scan the size tag.",
            benefit: "This helps us match closer sold listings.",
            role: .sizeTag
        )

        store.presentItemQuestions(
            item: lamp,
            imageData: ImageTools.sampleJPEG(),
            analysis: AnalyzeIntelligence(itemFacts: [], missingFacts: ["size"], photoPrompt: request.prompt),
            answers: ItemDetailAnswers()
        )
        let context = try XCTUnwrap(store.itemQuestionsContext)

        store.startTargetedScan(request: request, context: context, answers: ItemDetailAnswers())
        store.handleCapturedPhoto(scanData)
        store.presentPendingCapturedPhoto()
        await waitForTransitionTasks()

        guard case .targetedScanReview = store.flowSheetContext else {
            return XCTFail("Expected targeted scan review.")
        }

        store.retakeTargetedScanPhoto()

        XCTAssertTrue(store.isShowingCamera)
        XCTAssertEqual(store.activeCameraScanRequest, request)
        XCTAssertEqual(store.itemQuestionsContext?.supplementalPhotos.count, 0)
        XCTAssertFalse(store.itemQuestionsContext?.answers?.hasAnsweredOrSkipped(.targetedScan) ?? false)
        guard case .itemQuestions = store.flowSheetContext else {
            return XCTFail("Expected item questions behind retake camera.")
        }
    }

    func testCameraDeniedTargetedScanSkipReturnsToSameQuestionFlowMarkedSkipped() throws {
        let store = makeStore()
        let originalData = ImageTools.sampleJPEG()
        let request = TargetedScanRequest(
            prompt: "Scan the model label.",
            benefit: "This can confirm the exact model.",
            role: .label
        )

        store.presentItemQuestions(
            item: lamp,
            imageData: originalData,
            analysis: AnalyzeIntelligence(itemFacts: [], missingFacts: ["model"], photoPrompt: request.prompt),
            answers: ItemDetailAnswers()
        )
        let context = try XCTUnwrap(store.itemQuestionsContext)

        store.startTargetedScan(request: request, context: context, answers: ItemDetailAnswers())
        XCTAssertTrue(store.isShowingCamera)

        store.skipActiveTargetedScanFromCamera()

        XCTAssertFalse(store.isShowingCamera)
        XCTAssertNil(store.activeCameraScanRequest)
        let updated = try XCTUnwrap(store.itemQuestionsContext)
        XCTAssertEqual(updated.imageData, originalData)
        XCTAssertTrue(updated.supplementalPhotos.isEmpty)
        XCTAssertTrue(updated.answers?.hasAnsweredOrSkipped(.targetedScan) ?? false)
        guard case .itemQuestions(let flowContext) = store.flowSheetContext else {
            return XCTFail("Expected item questions after targeted scan skip.")
        }
        XCTAssertTrue(flowContext.answers?.hasAnsweredOrSkipped(.targetedScan) ?? false)
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

    func testMarketplaceComparisonSurvivesQuestionAndListingTransitions() {
        let store = makeStore()
        let comparison = MarketplaceComparison(
            marketplace: .ebay,
            recommendationLabel: "Best overall",
            listPrice: Decimal(45),
            compLowPrice: Decimal(30),
            compMedianPrice: Decimal(42),
            compHighPrice: Decimal(61),
            evidenceStatus: .grounded,
            evidenceSources: [
                ListingEvidenceSource(
                    sourceMarketplace: "eBay",
                    title: "Sold brass lamp",
                    url: "https://example.com/sold-lamp",
                    dateChecked: "2026-07-25",
                    listingStatus: "Sold",
                    conditionAndVariant: "Good brass lamp",
                    comparability: "Close match",
                    price: Decimal(42)
                )
            ]
        )

        store.presentItemQuestions(
            item: lamp,
            imageData: nil,
            preferredMarketplace: .ebay,
            marketplaceComparison: comparison
        )

        XCTAssertEqual(store.itemQuestionsContext?.marketplaceComparison, comparison)

        store.presentListing(
            item: lamp,
            imageData: nil,
            marketplace: .ebay,
            marketplaceComparison: store.itemQuestionsContext?.marketplaceComparison
        )

        XCTAssertEqual(store.listingContext?.marketplaceComparison, comparison)
        guard case .listing(let context) = store.flowSheetContext else {
            return XCTFail("Expected listing flow sheet.")
        }
        XCTAssertEqual(context.marketplaceComparison, comparison)
    }

    func testListingDraftWarningCarriesIntoMarketplaceQuestionContext() throws {
        let store = makeStore()
        let draft = GeneratedListingDraft(
            title: "Lamp",
            description: "Lamp in good condition.",
            missingInfoWarnings: ["Add model number before posting on eBay."]
        )

        store.presentItemQuestions(
            item: lamp,
            imageData: nil,
            preferredMarketplace: .ebay,
            listingDraft: draft,
            answers: ItemDetailAnswers()
        )

        XCTAssertEqual(store.itemQuestionsContext?.listingDraft?.missingInfoWarnings, ["Add model number before posting on eBay."])
        guard case .itemQuestions(let context) = store.flowSheetContext else {
            return XCTFail("Expected item questions flow sheet.")
        }
        XCTAssertEqual(context.listingDraft?.missingInfoWarnings, ["Add model number before posting on eBay."])
    }

    func testMarketplaceQuestionsReuseRememberedPreferenceForSameMarketplaceOnly() throws {
        let store = makeStore()
        let details = ItemDetailAnswers(
            labelOrBrand: "Stiffel",
            marketplaceNotes: [.ebay: "Prefer fixed price"]
        )

        store.presentListing(item: lamp, imageData: nil, marketplace: .ebay, details: details)
        store.closeFlow()
        store.presentItemQuestions(item: lamp, imageData: nil, preferredMarketplace: .ebay)

        let ebayAnswers = try XCTUnwrap(store.itemQuestionsContext?.answers)
        XCTAssertEqual(ebayAnswers.marketplaceNote(for: .ebay), "Prefer fixed price")
        XCTAssertEqual(ebayAnswers.labelOrBrand, "")

        store.closeFlow()
        store.presentItemQuestions(item: lamp, imageData: nil, preferredMarketplace: .facebook)

        XCTAssertNil(store.itemQuestionsContext?.answers)
    }

    func testRememberedMarketplacePreferencePersistsAndCanBeCleared() throws {
        let suiteName = "AppStoreRememberedSellingPreferences-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let firstStore = AppStore(defaults: defaults, flowTransitionDelayNanoseconds: transitionDelay)
        firstStore.presentListing(
            item: lamp,
            imageData: nil,
            marketplace: .facebook,
            details: ItemDetailAnswers(marketplaceNotes: [.facebook: "Can deliver nearby"])
        )

        let secondStore = AppStore(defaults: defaults, flowTransitionDelayNanoseconds: transitionDelay)
        secondStore.presentItemQuestions(item: lamp, imageData: nil, preferredMarketplace: .facebook)

        XCTAssertEqual(secondStore.itemQuestionsContext?.answers?.marketplaceNote(for: .facebook), "Can deliver nearby")

        secondStore.presentListing(
            item: lamp,
            imageData: nil,
            marketplace: .facebook,
            details: ItemDetailAnswers(answeredMarketplaces: [.facebook])
        )

        let thirdStore = AppStore(defaults: defaults, flowTransitionDelayNanoseconds: transitionDelay)
        thirdStore.presentItemQuestions(item: lamp, imageData: nil, preferredMarketplace: .facebook)

        XCTAssertNil(thirdStore.itemQuestionsContext?.answers)
    }

    func testRememberedMarketplacePreferencesCanForgetOneOrClearAll() throws {
        let suiteName = "AppStoreRememberedSellingPreferenceControls-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let firstStore = AppStore(defaults: defaults, flowTransitionDelayNanoseconds: transitionDelay)
        firstStore.presentListing(
            item: lamp,
            imageData: nil,
            marketplace: .ebay,
            details: ItemDetailAnswers(marketplaceNotes: [
                .ebay: "Prefer fixed price",
                .facebook: "Can deliver nearby"
            ])
        )

        XCTAssertTrue(firstStore.hasRememberedSellingPreferences)

        firstStore.forgetSellingPreference(for: .facebook)

        let secondStore = AppStore(defaults: defaults, flowTransitionDelayNanoseconds: transitionDelay)
        secondStore.presentItemQuestions(item: lamp, imageData: nil, preferredMarketplace: .ebay)
        XCTAssertEqual(secondStore.itemQuestionsContext?.answers?.marketplaceNote(for: .ebay), "Prefer fixed price")

        secondStore.updateRememberedSellingPreference("  Auction is okay if the comps are strong.  ", for: .ebay)
        secondStore.closeFlow()
        secondStore.presentItemQuestions(item: lamp, imageData: nil, preferredMarketplace: .ebay)
        XCTAssertEqual(secondStore.itemQuestionsContext?.answers?.marketplaceNote(for: .ebay), "Auction is okay if the comps are strong.")

        secondStore.closeFlow()
        secondStore.presentItemQuestions(item: lamp, imageData: nil, preferredMarketplace: .facebook)
        XCTAssertNil(secondStore.itemQuestionsContext?.answers)

        secondStore.clearRememberedSellingPreferences()

        let thirdStore = AppStore(defaults: defaults, flowTransitionDelayNanoseconds: transitionDelay)
        thirdStore.presentItemQuestions(item: lamp, imageData: nil, preferredMarketplace: .ebay)
        XCTAssertNil(thirdStore.itemQuestionsContext?.answers)
        XCTAssertFalse(thirdStore.hasRememberedSellingPreferences)
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

    func testEarlyAccessEntitlementSnapshotPersistsForSettingsCopy() {
        let suiteName = "AppStoreFlowTransitionTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let entitlement = EntitlementSnapshot(
            state: .earlyAccess,
            completeFeatureAccess: true,
            futurePaidAccessEnabled: false,
            remainingAnalyses: 12,
            remainingAiActions: 33
        )
        let store = AppStore(
            defaults: defaults,
            flowTransitionDelayNanoseconds: transitionDelay
        )

        XCTAssertEqual(store.earlyAccessStatusValue, "Full access right now")

        store.updateEntitlementSnapshot(entitlement)

        XCTAssertEqual(store.latestEntitlementSnapshot, entitlement)
        XCTAssertEqual(store.earlyAccessStatusValue, "12 analyses left today")

        store.updateEntitlementSnapshot(EntitlementSnapshot(
            state: .earlyAccess,
            completeFeatureAccess: true,
            futurePaidAccessEnabled: false,
            remainingAnalyses: 0,
            remainingAiActions: 3
        ))

        XCTAssertEqual(store.earlyAccessStatusValue, "Short break before the next scan")

        let reopenedStore = AppStore(
            defaults: defaults,
            flowTransitionDelayNanoseconds: transitionDelay
        )

        XCTAssertEqual(reopenedStore.earlyAccessStatusValue, "Short break before the next scan")
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

    private func makeSolidJPEG(color: UIColor) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 480), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 0.85))
    }
}
