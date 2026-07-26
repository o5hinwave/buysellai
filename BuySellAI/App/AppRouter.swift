import AuthenticationServices
import Observation
import os
import SwiftData
import SwiftUI
import UIKit

enum FlowSheetContext: Equatable {
    case snapResult(SnapResultContext)
    case itemQuestions(ItemQuestionsContext)
    case targetedScanReview(TargetedScanReviewContext)
    case marketplacePicker(MarketplacePickerContext)
    case listing(ListingContext)
}

enum HistorySyncState: Equatable, Sendable {
    case idle
    case loading
    case failed(String)
}

private struct PendingTargetedScan {
    let context: ItemQuestionsContext
    let answers: ItemDetailAnswers
    let request: TargetedScanRequest
    let answeredField: ItemDetailFieldKey
}

struct TargetedScanReviewContext: Equatable {
    let imageData: Data
    let request: TargetedScanRequest
    let fixPrompt: String
    let itemName: String
}

private struct PendingTargetedScanReview {
    let imageData: Data
    let evidence: NativeScanEvidence?
    let pendingTargetedScan: PendingTargetedScan
}

@MainActor
@Observable
final class AppStore {
    var session: AuthSession?
    var history: [HistoryEntry] = []
    var historySyncState: HistorySyncState = .idle
    var theme: ThemePreference {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }
    var reduceMotion: Bool {
        didSet { defaults.set(reduceMotion, forKey: Keys.reduceMotion) }
    }
    var rememberedSellingPreferences: ItemDetailAnswers?
    var hasRememberedSellingPreferences: Bool {
        rememberedSellingPreferences?.marketplaceNotes.isEmpty == false
    }
    var latestEntitlementSnapshot: EntitlementSnapshot?
    var earlyAccessStatusValue: String {
        guard let latestEntitlementSnapshot else {
            return "Full access right now".localized
        }
        guard latestEntitlementSnapshot.completeFeatureAccess else {
            return "Saved listings stay available".localized
        }
        let remaining = min(
            latestEntitlementSnapshot.remainingAnalyses,
            latestEntitlementSnapshot.remainingAiActions
        )
        return remaining > 0
            ? String.localizedFormat("%d analyses left today".localized, remaining)
            : "Short break before the next scan".localized
    }

    var isShowingCamera = false
    var isShowingTutorial = false
    var isShowingAuth = false
    var isShowingSettings = false
    var snapResultContext: SnapResultContext?
    var itemQuestionsContext: ItemQuestionsContext?
    var marketplacePickerContext: MarketplacePickerContext?
    var listingContext: ListingContext?
    var flowSheetContext: FlowSheetContext?
    var toast: ToastMessage?
    var uiTestClipboardStatus: String?
    var activeCameraScanRequest: TargetedScanRequest?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var historyReader: HistoryReader?
    @ObservationIgnored private let remoteHistoryClient: RemoteHistoryClient
    @ObservationIgnored private let accountClient: AccountClient
    @ObservationIgnored private let supabaseAuthClient: SupabaseAuthClient
    @ObservationIgnored private let logger = Logger(subsystem: "BuySellAI", category: "Persistence")
    @ObservationIgnored private let flowTransitionDelayNanoseconds: UInt64
    @ObservationIgnored private var pendingCapturedPhotoData: Data?
    @ObservationIgnored private var pendingTargetedScan: PendingTargetedScan?
    @ObservationIgnored private var pendingTargetedScanReview: PendingTargetedScanReview?
    @ObservationIgnored private var flowGeneration = 0
    @ObservationIgnored private var modalPresentationGeneration = 0
    @ObservationIgnored private var historyMutationGeneration = 0
    @ObservationIgnored private var credentialRevocationObserver: NSObjectProtocol?
    @ObservationIgnored private var modalPresentationTask: Task<Void, Never>?
    @ObservationIgnored private var flowTransitionTask: Task<Void, Never>?
    @ObservationIgnored private var sessionResetHistoryTask: Task<Void, Never>?
    @ObservationIgnored private var remoteHistoryMutationTasks: [UUID: Task<Void, Never>] = [:]

    init(
        defaults: UserDefaults = .standard,
        remoteHistoryClient: RemoteHistoryClient = RemoteHistoryClient(),
        accountClient: AccountClient = AccountClient(),
        supabaseAuthClient: SupabaseAuthClient = SupabaseAuthClient(),
        flowTransitionDelayNanoseconds: UInt64 = 320_000_000
    ) {
        self.defaults = defaults
        self.remoteHistoryClient = remoteHistoryClient
        self.accountClient = accountClient
        self.supabaseAuthClient = supabaseAuthClient
        self.flowTransitionDelayNanoseconds = flowTransitionDelayNanoseconds
        if LaunchArguments.contains(LaunchArguments.resetAuth) {
            Self.clearStoredSessionValues()
        }
        if LaunchArguments.contains(LaunchArguments.resetTutorial) {
            defaults.removeObject(forKey: Keys.hasSeenHowItWorks)
        }
        if LaunchArguments.contains(LaunchArguments.skipTutorial) {
            defaults.set(true, forKey: Keys.hasSeenHowItWorks)
        }
        if LaunchArguments.contains(LaunchArguments.resetPreferences) {
            defaults.removeObject(forKey: Keys.theme)
            defaults.removeObject(forKey: Keys.reduceMotion)
            defaults.removeObject(forKey: Keys.sellingPreferences)
        }
        let storedTheme = defaults.string(forKey: Keys.theme).flatMap(ThemePreference.init(rawValue:))
        self.theme = storedTheme ?? .system
        self.reduceMotion = defaults.bool(forKey: Keys.reduceMotion)
        self.rememberedSellingPreferences = Self.storedSellingPreferences(from: defaults)
        self.latestEntitlementSnapshot = Self.storedEntitlementSnapshot(from: defaults)

        if let userID = Keychain.load(Keys.authUserID) ?? Keychain.load(Keys.appleUserID) {
            self.session = AuthSession(
                userID: userID,
                email: Keychain.load(Keys.authEmail),
                accessToken: Keychain.load(Keys.supabaseAccessToken),
                refreshToken: Keychain.load(Keys.supabaseRefreshToken),
                appleUserID: Keychain.load(Keys.appleUserID)
            )
        }
        if LaunchArguments.contains(LaunchArguments.uiTestingSignedIn) {
            self.session = AuthSession(
                userID: "ui-test-user",
                email: "person@example.com"
            )
        }
        ProductAnalytics.recordAppOpened(defaults: defaults)
        observeAppleCredentialRevocation()
    }

    deinit {
        modalPresentationTask?.cancel()
        flowTransitionTask?.cancel()
        sessionResetHistoryTask?.cancel()
        remoteHistoryMutationTasks.values.forEach { $0.cancel() }
        remoteHistoryMutationTasks.removeAll()
        if let credentialRevocationObserver {
            NotificationCenter.default.removeObserver(credentialRevocationObserver)
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var uiTestSettingsStateDescription: String {
        let reduceMotionValue = reduceMotion ? "on" : "off"
        return "Settings state: \(theme.rawValue), reduce motion \(reduceMotionValue)"
    }

    var shouldShowTutorialOnLaunch: Bool {
        defaults.bool(forKey: Keys.hasSeenHowItWorks) == false
    }

    func presentAuth() {
        advanceModalPresentationGeneration()
        isShowingSettings = false
        isShowingAuth = true
    }

    func presentSettings() {
        advanceModalPresentationGeneration()
        isShowingAuth = false
        isShowingSettings = true
    }

    func presentTutorial() {
        advanceModalPresentationGeneration()
        isShowingTutorial = true
    }

    func presentAuthAfterSettingsDismissal() {
        let generation = advanceModalPresentationGeneration()
        let delay = flowTransitionDelayNanoseconds
        isShowingSettings = false
        isShowingAuth = false
        modalPresentationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard
                let self,
                Task.isCancelled == false,
                self.isCurrentModalPresentationGeneration(generation),
                self.session == nil
            else { return }
            self.isShowingAuth = true
            self.modalPresentationTask = nil
        }
    }

    func presentTutorialAfterSettingsDismissal() {
        let generation = advanceModalPresentationGeneration()
        let delay = flowTransitionDelayNanoseconds
        isShowingSettings = false
        isShowingTutorial = false
        modalPresentationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard
                let self,
                Task.isCancelled == false,
                self.isCurrentModalPresentationGeneration(generation)
            else { return }
            self.isShowingTutorial = true
            self.modalPresentationTask = nil
        }
    }

    func configure(modelContext: ModelContext) {
        guard self.modelContext == nil else { return }
        self.modelContext = modelContext
        self.historyReader = HistoryReader(modelContainer: modelContext.container)
        if LaunchArguments.contains(LaunchArguments.resetHistory) {
            let didClearLocalHistory = clearLocalHistoryReportingFailure()
            advanceHistoryMutationGeneration()
            history.removeAll()
            if didClearLocalHistory == false {
                showToast("Couldn't clear history.".localized, style: .error)
            }
        }
    }

    func markTutorialSeen() {
        defaults.set(true, forKey: Keys.hasSeenHowItWorks)
        isShowingTutorial = false
    }

    func startSnapFlow() {
        advanceFlowGeneration()
        activeCameraScanRequest = nil
        pendingTargetedScan = nil
        pendingCapturedPhotoData = nil
#if DEBUG
        let uiTestingCameraMode = LaunchArguments.contains(LaunchArguments.uiTestingCameraDenied) ||
            LaunchArguments.contains(LaunchArguments.uiTestingCameraReady)
        if LaunchArguments.isUITesting,
           uiTestingCameraMode == false {
            presentFlowSheet(.snapResult(SnapResultContext(imageData: ImageTools.sampleJPEG())))
            return
        }
#endif
        isShowingCamera = true
    }

    func handleCapturedPhoto(_ data: Data) {
        if pendingTargetedScan == nil {
            advanceFlowGeneration()
        }
        pendingCapturedPhotoData = data
        isShowingCamera = false
        ProductAnalytics.record(
            .photoCaptured,
            properties: ["image_bytes_bucket": Self.imageSizeBucket(for: data.count)]
        )
    }

    func presentPendingCapturedPhoto() {
        guard let data = pendingCapturedPhotoData else { return }
        pendingCapturedPhotoData = nil
        if let pendingTargetedScan {
            Task { [weak self] in
                await self?.presentTargetedScanReviewOrResult(data, pendingTargetedScan: pendingTargetedScan)
            }
            return
        }
        presentFlowSheet(.snapResult(SnapResultContext(imageData: data)))
    }

    private func presentTargetedScanReviewOrResult(
        _ data: Data,
        pendingTargetedScan: PendingTargetedScan
    ) async {
        let evidence = await NativeScanAnalyzer.evidence(from: data)
        if let fixPrompt = evidence?.photoQuality?.fixPrompt,
           fixPrompt.isEmpty == false {
            pendingTargetedScanReview = PendingTargetedScanReview(
                imageData: data,
                evidence: evidence,
                pendingTargetedScan: pendingTargetedScan
            )
            flowSheetContext = .targetedScanReview(
                TargetedScanReviewContext(
                    imageData: data,
                    request: pendingTargetedScan.request,
                    fixPrompt: fixPrompt,
                    itemName: pendingTargetedScan.context.item.name
                )
            )
            showToast("Photo needs a quick check.".localized, style: .warning)
            return
        }
        acceptTargetedScanResult(data, evidence: evidence, pendingTargetedScan: pendingTargetedScan)
    }

    private func acceptTargetedScanResult(
        _ data: Data,
        evidence: NativeScanEvidence?,
        pendingTargetedScan: PendingTargetedScan
    ) {
        var updatedAnswers = pendingTargetedScan.answers
        updatedAnswers.applyTargetedScanEvidence(
            evidence,
            request: pendingTargetedScan.request,
            answeredField: pendingTargetedScan.answeredField
        )
        var supplementalPhotos = pendingTargetedScan.context.supplementalPhotos
        if let scanPhoto = ItemPhotoAsset.targetedScan(
            item: pendingTargetedScan.context.item,
            imageData: data,
            request: pendingTargetedScan.request,
            evidence: evidence
        ) {
            supplementalPhotos.append(scanPhoto)
        }
        let updatedAnalysis = pendingTargetedScan.context.analysis?.applyingTargetedScanEvidence(
            evidence,
            request: pendingTargetedScan.request
        )
        presentItemQuestions(
            item: pendingTargetedScan.context.item,
            imageData: pendingTargetedScan.context.imageData ?? data,
            supplementalPhotos: supplementalPhotos,
            preferredMarketplace: pendingTargetedScan.context.preferredMarketplace,
            marketplaceComparison: pendingTargetedScan.context.marketplaceComparison,
            listingDraft: pendingTargetedScan.context.listingDraft,
            analysis: updatedAnalysis,
            answers: updatedAnswers
        )
        showToast(
            Self.targetedScanToastText(for: evidence).localized,
            style: Self.targetedScanToastStyle(for: evidence)
        )
        pendingTargetedScanReview = nil
        self.pendingTargetedScan = nil
        activeCameraScanRequest = nil
    }

    private static func targetedScanToastText(for evidence: NativeScanEvidence?) -> String {
        guard let fixPrompt = evidence?.photoQuality?.fixPrompt,
              fixPrompt.isEmpty == false
        else {
            return "Scan added."
        }
        return "Scan added. \(fixPrompt)"
    }

    private static func targetedScanToastStyle(for evidence: NativeScanEvidence?) -> ToastStyle {
        evidence?.photoQuality?.fixPrompt == nil ? .success : .warning
    }

    func cancelCamera() {
        pendingCapturedPhotoData = nil
        pendingTargetedScan = nil
        pendingTargetedScanReview = nil
        activeCameraScanRequest = nil
        isShowingCamera = false
    }

    func retakeTargetedScanPhoto() {
        guard let review = pendingTargetedScanReview else { return }
        Haptics.impact(.medium)
        pendingCapturedPhotoData = nil
        pendingTargetedScan = review.pendingTargetedScan
        pendingTargetedScanReview = nil
        activeCameraScanRequest = review.pendingTargetedScan.request
        flowSheetContext = .itemQuestions(review.pendingTargetedScan.context)
        isShowingCamera = true
    }

    func useTargetedScanPhoto() {
        guard let review = pendingTargetedScanReview else { return }
        Haptics.impact(.medium)
        acceptTargetedScanResult(
            review.imageData,
            evidence: review.evidence,
            pendingTargetedScan: review.pendingTargetedScan
        )
    }

    func skipTargetedScanPhoto() {
        guard let review = pendingTargetedScanReview else { return }
        Haptics.impact(.light)
        pendingTargetedScanReview = nil
        skipTargetedScan(review.pendingTargetedScan)
    }

    func skipActiveTargetedScanFromCamera() {
        guard let pendingTargetedScan else {
            cancelCamera()
            return
        }
        pendingCapturedPhotoData = nil
        pendingTargetedScanReview = nil
        isShowingCamera = false
        skipTargetedScan(pendingTargetedScan)
    }

    private func skipTargetedScan(_ pendingTargetedScan: PendingTargetedScan) {
        var updatedAnswers = pendingTargetedScan.answers
        updatedAnswers.markAnswered(pendingTargetedScan.answeredField)
        self.pendingTargetedScan = nil
        activeCameraScanRequest = nil
        presentItemQuestions(
            item: pendingTargetedScan.context.item,
            imageData: pendingTargetedScan.context.imageData,
            supplementalPhotos: pendingTargetedScan.context.supplementalPhotos,
            preferredMarketplace: pendingTargetedScan.context.preferredMarketplace,
            marketplaceComparison: pendingTargetedScan.context.marketplaceComparison,
            listingDraft: pendingTargetedScan.context.listingDraft,
            analysis: pendingTargetedScan.context.analysis,
            answers: updatedAnswers
        )
        showToast("Scan skipped.".localized, style: .info)
    }

    func startTargetedScan(
        request: TargetedScanRequest,
        context: ItemQuestionsContext,
        answers: ItemDetailAnswers,
        answeredField: ItemDetailFieldKey = .targetedScan
    ) {
        pendingCapturedPhotoData = nil
        pendingTargetedScanReview = nil
        activeCameraScanRequest = request
        pendingTargetedScan = PendingTargetedScan(
            context: context,
            answers: answers,
            request: request,
            answeredField: answeredField
        )
#if DEBUG
        if LaunchArguments.isUITesting {
            handleCapturedPhoto(ImageTools.sampleJPEG())
            return
        }
#endif
        isShowingCamera = true
    }

    func presentItemQuestions(
        item: DetectedItem,
        imageData: Data?,
        supplementalPhotos: [ItemPhotoAsset] = [],
        preferredMarketplace: Marketplace? = nil,
        marketplaceComparison: MarketplaceComparison? = nil,
        listingDraft: GeneratedListingDraft? = nil,
        analysis: AnalyzeIntelligence? = nil,
        answers: ItemDetailAnswers? = nil
    ) {
        advanceFlowGeneration()
        let rememberedAnswers = answersApplyingRememberedPreferences(
            answers,
            preferredMarketplace: preferredMarketplace
        )
        presentFlowSheet(
            .itemQuestions(
                ItemQuestionsContext(
                    item: item,
                    imageData: imageData,
                    supplementalPhotos: supplementalPhotos,
                    preferredMarketplace: preferredMarketplace,
                    marketplaceComparison: marketplaceComparison,
                    listingDraft: listingDraft,
                    analysis: analysis,
                    answers: rememberedAnswers
                )
            )
        )
    }

    func presentMarketplacePicker(
        item: DetectedItem,
        imageData: Data?,
        supplementalPhotos: [ItemPhotoAsset] = [],
        details: ItemDetailAnswers? = nil,
        analysis: AnalyzeIntelligence? = nil
    ) {
        advanceFlowGeneration()
        rememberSellingPreferences(from: details)
        presentFlowSheet(
            .marketplacePicker(
                MarketplacePickerContext(
                    item: item,
                    imageData: imageData,
                    supplementalPhotos: supplementalPhotos,
                    details: details,
                    analysis: analysis
                )
            )
        )
    }

    func presentListing(
        item: DetectedItem,
        imageData: Data?,
        supplementalPhotos: [ItemPhotoAsset] = [],
        marketplace: Marketplace,
        details: ItemDetailAnswers? = nil,
        marketplaceComparison: MarketplaceComparison? = nil,
        analysis: AnalyzeIntelligence? = nil,
        existingListingText: String? = nil,
        existingListingDraft: GeneratedListingDraft? = nil,
        existingHistoryEntry: HistoryEntry? = nil
    ) {
        advanceFlowGeneration()
        rememberSellingPreferences(from: details)
        presentFlowSheet(
            .listing(
                ListingContext(
                    item: item,
                    imageData: imageData,
                    supplementalPhotos: supplementalPhotos,
                    marketplace: marketplace,
                    details: details,
                    marketplaceComparison: marketplaceComparison,
                    analysis: analysis,
                    existingListingText: existingListingText,
                    existingListingDraft: existingListingDraft,
                    existingHistoryEntry: existingHistoryEntry
                )
            )
        )
    }

    func forgetSellingPreference(for marketplace: Marketplace) {
        guard var updatedPreferences = rememberedSellingPreferences else { return }
        updatedPreferences.setMarketplaceNote("", for: marketplace)
        rememberedSellingPreferences = Self.marketplacePreferenceSnapshot(from: updatedPreferences)
        persistRememberedSellingPreferences()
        showToast("Selling preference cleared.".localized, style: .success)
    }

    func updateRememberedSellingPreference(_ note: String, for marketplace: Marketplace) {
        guard let cleanNote = cleanMarketplacePreference(note) else {
            forgetSellingPreference(for: marketplace)
            return
        }
        var updatedPreferences = rememberedSellingPreferences ?? ItemDetailAnswers()
        updatedPreferences.setMarketplaceNote(cleanNote, for: marketplace)
        rememberedSellingPreferences = Self.marketplacePreferenceSnapshot(from: updatedPreferences)
        persistRememberedSellingPreferences()
        showToast("Selling preference updated.".localized, style: .success)
    }

    func clearRememberedSellingPreferences() {
        guard hasRememberedSellingPreferences else { return }
        rememberedSellingPreferences = nil
        defaults.removeObject(forKey: Keys.sellingPreferences)
        showToast("Selling preferences cleared.".localized, style: .success)
    }

    func retakePhoto(keeping marketplace: Marketplace? = nil) {
        let generation = advanceFlowGeneration()
        let delay = flowTransitionDelayNanoseconds
        clearFlowSheetState()
        flowTransitionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard
                let self,
                Task.isCancelled == false,
                self.isCurrentFlowGeneration(generation)
            else { return }
#if DEBUG
            if LaunchArguments.isUITesting {
                self.presentFlowSheet(
                    .snapResult(SnapResultContext(imageData: ImageTools.sampleJPEG(), preferredMarketplace: marketplace))
                )
                self.flowTransitionTask = nil
                return
            }
#endif
            self.isShowingCamera = true
            self.flowTransitionTask = nil
        }
    }

    func closeFlow() {
        advanceFlowGeneration()
        pendingCapturedPhotoData = nil
        clearFlowSheetState()
        isShowingCamera = false
    }

    func dismissFlowSheet() {
        advanceFlowGeneration()
        pendingCapturedPhotoData = nil
        clearFlowSheetState()
    }

    private func presentFlowSheet(_ context: FlowSheetContext) {
        snapResultContext = nil
        itemQuestionsContext = nil
        marketplacePickerContext = nil
        listingContext = nil

        switch context {
        case .snapResult(let snapResult):
            snapResultContext = snapResult
        case .itemQuestions(let itemQuestions):
            itemQuestionsContext = itemQuestions
        case .targetedScanReview:
            break
        case .marketplacePicker(let marketplacePicker):
            marketplacePickerContext = marketplacePicker
        case .listing(let listing):
            listingContext = listing
        }

        flowSheetContext = context
    }

    private func clearFlowSheetState() {
        snapResultContext = nil
        itemQuestionsContext = nil
        marketplacePickerContext = nil
        listingContext = nil
        flowSheetContext = nil
        pendingTargetedScanReview = nil
        pendingTargetedScan = nil
        activeCameraScanRequest = nil
    }

    func loadHistory() async {
        let refreshGeneration = historyMutationGeneration
        historySyncState = .loading

#if DEBUG
        if LaunchArguments.contains(LaunchArguments.uiTestingSlowHistoryLoad) {
            do {
                try await Task.sleep(nanoseconds: 4_000_000_000)
            } catch {
                guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
                historySyncState = .idle
                return
            }
        }

        if LaunchArguments.contains(LaunchArguments.seedLargeHistory) {
            guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
            history = Self.uiTestingHistoryEntries(count: 500)
            historySyncState = .idle
            return
        }

        if LaunchArguments.contains(LaunchArguments.seedHistory) {
            guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
            history = [Self.uiTestingHistoryEntry]
            historySyncState = .idle
            return
        }
#endif

        if hasRemoteSessionCredentials {
            do {
                guard let accessToken = try await authenticatedAccessTokenForSignedRequest(), accessToken.isEmpty == false else {
                    guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
                    historySyncState = .failed(APIError.sessionExpired.localizedDescription)
                    showSessionExpiredToast()
                    return
                }
                let remoteHistory = try await remoteHistoryClient.fetchHistory(accessToken: accessToken)
                guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
                history = remoteHistory
                historySyncState = .idle
            } catch let error where APIError.isCancellation(error) {
                guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
                historySyncState = .idle
                return
            } catch {
                guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
                let message = APIError.userMessage(for: error)
                historySyncState = .failed(message)
                showToast(message, style: .error)
            }
            return
        }

        do {
            let localHistory = try await loadLocalHistory()
            guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
            history = localHistory
            historySyncState = .idle
        } catch let error where APIError.isCancellation(error) {
            guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
            historySyncState = .idle
            return
        } catch {
            guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
            let message = "Couldn't load recent listings.".localized
            historySyncState = .failed(message)
            showToast(message, style: .error)
        }
    }

    func saveListing(
        item: DetectedItem,
        imageData: Data?,
        supplementalPhotos: [ItemPhotoAsset] = [],
        marketplace: Marketplace,
        listingText: String,
        details: ItemDetailAnswers? = nil,
        marketplaceComparison: MarketplaceComparison? = nil,
        listingDraft: GeneratedListingDraft? = nil,
        identificationProfile: AnalyzeIdentificationProfile? = nil,
        replacing existingEntry: HistoryEntry? = nil
    ) {
        let cleanItemName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanListingText = (try? ListingTextContract.validatedStored(listingText))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard cleanItemName.isEmpty == false, cleanListingText.isEmpty == false, item.priceEstimate > 0 else {
            showToast(APIError.decoding.localizedDescription, style: .error)
            return
        }
        let thumbnail = imageData.flatMap {
            ImageTools.jpegDataDownscaled(from: $0, maxLongEdge: 200, compression: 0.75)
        } ?? existingEntry?.imageThumbnail
        let historyPhotos = Self.historySupplementalPhotos(
            item: item,
            imageData: imageData,
            supplementalPhotos: supplementalPhotos,
            existingEntry: existingEntry
        )
        let entry = HistoryEntry(
            id: existingEntry?.id ?? UUID(),
            createdAt: existingEntry?.createdAt ?? Date(),
            itemName: cleanItemName,
            category: item.category,
            condition: item.condition,
            suggestedPrice: item.priceEstimate,
            imageThumbnail: thumbnail,
            marketplace: marketplace,
            listingText: cleanListingText,
            itemDetails: details?.sanitizedForUse ?? existingEntry?.itemDetails,
            marketplaceComparison: marketplaceComparison?.sanitizedForDisplay() ?? existingEntry?.marketplaceComparison,
            listingDraft: listingDraft?.sanitizedForDisplay() ?? existingEntry?.listingDraft,
            identificationProfile: identificationProfile?.sanitizedForDisplay() ?? existingEntry?.identificationProfile,
            supplementalPhotos: historyPhotos
        )

        let previousHistory = history
        let isNewListing = existingEntry == nil && history.contains(where: { $0.id == entry.id }) == false
        let createsSecondListing = isNewListing && history.count == 1
        let saveGeneration = advanceHistoryMutationGeneration()
        upsertVisibleHistory(entry, replacing: existingEntry)

        if hasRemoteSessionCredentials {
            scheduleRemoteHistoryMutation { store in
                do {
                    guard let accessToken = try await store.authenticatedAccessTokenForSignedRequest(), accessToken.isEmpty == false else {
                        guard store.isCurrentHistoryMutationGeneration(saveGeneration) else { return }
                        store.history = previousHistory
                        store.showSessionExpiredToast()
                        return
                    }
                    try await store.remoteHistoryClient.upsertHistory([entry], accessToken: accessToken)
                    guard store.isCurrentHistoryMutationGeneration(saveGeneration) else { return }
                    store.recordSavedListingAnalytics(entry, isNewListing: isNewListing, createsSecondListing: createsSecondListing)
                } catch let error where APIError.isCancellation(error) {
                    guard store.isCurrentHistoryMutationGeneration(saveGeneration) else { return }
                } catch {
                    guard store.isCurrentHistoryMutationGeneration(saveGeneration) else { return }
                    store.history = previousHistory
                    store.showToast(APIError.userMessage(for: error), style: .error)
                }
            }
            return
        }

        if let modelContext {
            do {
                try upsertLocalHistory(entry, in: modelContext)
                try modelContext.save()
                recordSavedListingAnalytics(entry, isNewListing: isNewListing, createsSecondListing: createsSecondListing)
            } catch {
                history = previousHistory
                showToast("Couldn't save this listing.".localized, style: .error)
            }
        }
    }

    private static func historySupplementalPhotos(
        item: DetectedItem,
        imageData: Data?,
        supplementalPhotos: [ItemPhotoAsset],
        existingEntry: HistoryEntry?
    ) -> [ItemPhotoAsset] {
        var photos: [ItemPhotoAsset] = []
        if let original = ItemPhotoAsset.originalUserPhoto(item: item, imageData: imageData) {
            photos.append(original)
        }
        photos.append(contentsOf: supplementalPhotos.filter { $0.itemID == item.id })

        let compactPhotos = photos.compactMap { photo -> ItemPhotoAsset? in
            guard photo.canExportToListing,
                  let imageData = photo.imageData,
                  imageData.isEmpty == false,
                  let compactData = ImageTools.jpegDataDownscaled(from: imageData, maxLongEdge: 1200, compression: 0.82)
            else { return nil }

            return ItemPhotoAsset(
                id: photo.id,
                itemID: photo.itemID,
                imageData: compactData,
                source: photo.source,
                role: photo.role,
                dateAdded: photo.dateAdded,
                verifies: photo.verifies,
                isListingSafe: photo.isListingSafe,
                isAIEdited: photo.isAIEdited,
                relatedOriginalID: photo.relatedOriginalID
            )
        }

        return compactPhotos.isEmpty ? existingEntry?.supplementalPhotos ?? [] : compactPhotos
    }

    func deleteHistory(_ entry: HistoryEntry, emitsFeedback: Bool = true) {
        if hasRemoteSessionCredentials {
            let previous = history
            let deleteGeneration = advanceHistoryMutationGeneration()
            history.removeAll { $0.id == entry.id }
            scheduleRemoteHistoryMutation { store in
                do {
                    guard let accessToken = try await store.authenticatedAccessTokenForSignedRequest(), accessToken.isEmpty == false else {
                        guard store.isCurrentHistoryMutationGeneration(deleteGeneration) else { return }
                        store.history = previous
                        store.showSessionExpiredToast()
                        return
                    }
                    try await store.remoteHistoryClient.deleteHistory(id: entry.id, accessToken: accessToken)
                    guard store.isCurrentHistoryMutationGeneration(deleteGeneration) else { return }
                    if emitsFeedback {
                        HistoryDeletionFeedback.perform()
                    }
                } catch let error where APIError.isCancellation(error) {
                    guard store.isCurrentHistoryMutationGeneration(deleteGeneration) else { return }
                } catch {
                    guard store.isCurrentHistoryMutationGeneration(deleteGeneration) else { return }
                    store.history = previous
                    store.showToast(APIError.userMessage(for: error), style: .error)
                }
            }
            return
        }

        guard let modelContext else {
            advanceHistoryMutationGeneration()
            history.removeAll { $0.id == entry.id }
            if emitsFeedback {
                HistoryDeletionFeedback.perform()
            }
            return
        }
        do {
            advanceHistoryMutationGeneration()
            let id = entry.id
            let descriptor = FetchDescriptor<HistoryEntryModel>(
                predicate: #Predicate { $0.id == id }
            )
            let matches = try modelContext.fetch(descriptor)
            matches.forEach(modelContext.delete)
            try modelContext.save()
            history.removeAll { $0.id == entry.id }
            if emitsFeedback {
                HistoryDeletionFeedback.perform()
            }
        } catch {
            showToast("Couldn't delete this listing.".localized, style: .error)
        }
    }

    func clearHistory() {
        if hasRemoteSessionCredentials {
            let previous = history
            let clearGeneration = advanceHistoryMutationGeneration()
            history.removeAll()
            scheduleRemoteHistoryMutation { store in
                do {
                    guard let accessToken = try await store.authenticatedAccessTokenForSignedRequest(), accessToken.isEmpty == false else {
                        guard store.isCurrentHistoryMutationGeneration(clearGeneration) else { return }
                        store.history = previous
                        store.showSessionExpiredToast()
                        return
                    }
                    try await store.remoteHistoryClient.clearHistory(accessToken: accessToken)
                    guard store.isCurrentHistoryMutationGeneration(clearGeneration) else { return }
                    store.completeHistoryClear()
                } catch let error where APIError.isCancellation(error) {
                    guard store.isCurrentHistoryMutationGeneration(clearGeneration) else { return }
                } catch {
                    guard store.isCurrentHistoryMutationGeneration(clearGeneration) else { return }
                    store.history = previous
                    store.showToast(APIError.userMessage(for: error), style: .error)
                }
            }
            return
        }

        guard let modelContext else {
            advanceHistoryMutationGeneration()
            completeHistoryClear()
            return
        }
        do {
            advanceHistoryMutationGeneration()
            try modelContext.delete(model: HistoryEntryModel.self)
            try modelContext.save()
            completeHistoryClear()
        } catch {
            showToast("Couldn't clear history.".localized, style: .error)
        }
    }

    private func completeHistoryClear() {
        history.removeAll()
        HistoryDeletionFeedback.perform()
        showToast("History cleared.".localized, style: .success)
    }

    func reopenListing(_ entry: HistoryEntry) {
        let reopenedItemID = entry.supplementalPhotos.first?.itemID ?? UUID()
        let item = DetectedItem(
            id: reopenedItemID,
            name: entry.itemName,
            category: entry.category ?? .other,
            condition: entry.condition ?? .good,
            priceEstimate: entry.suggestedPrice ?? Decimal(1)
        )
        let reopenedImageData = entry.supplementalPhotos.first { $0.role == .cover }?.imageData ?? entry.imageThumbnail
        let analysis = entry.identificationProfile.map {
            AnalyzeIntelligence(
                itemFacts: [],
                missingFacts: [],
                photoPrompt: nil,
                identificationProfile: $0
            )
        }
        presentListing(
            item: item,
            imageData: reopenedImageData,
            supplementalPhotos: entry.supplementalPhotos,
            marketplace: entry.marketplace,
            details: entry.itemDetails,
            marketplaceComparison: entry.marketplaceComparison,
            analysis: analysis,
            existingListingText: entry.listingText,
            existingListingDraft: entry.listingDraft,
            existingHistoryEntry: entry
        )
    }

    func signOut() {
        cancelRemoteHistoryMutationTasks()
        session = nil
        clearStoredSession()
        advanceHistoryMutationGeneration()
        scheduleSessionResetHistoryLoad()
        showToast("Signed out.".localized, style: .success)
    }

    func handleAppleCredentialRevoked() {
        guard session?.appleUserID != nil else { return }
        cancelRemoteHistoryMutationTasks()
        session = nil
        clearStoredSession()
        advanceHistoryMutationGeneration()
        scheduleSessionResetHistoryLoad()
        showToast("Apple sign-in was disconnected.".localized, style: .info)
    }

    func deleteAccount() async -> Bool {
        guard hasRemoteSessionCredentials else {
            showSessionExpiredToast()
            return false
        }

        do {
            guard let accessToken = try await authenticatedAccessTokenForSignedRequest(), accessToken.isEmpty == false else {
                showSessionExpiredToast()
                return false
            }
            cancelRemoteHistoryMutationTasks()
            try await accountClient.deleteAccount(accessToken: accessToken)
            session = nil
            clearStoredSession()
            advanceHistoryMutationGeneration()
            history.removeAll()
            let didClearLocalHistory = clearLocalHistoryReportingFailure()
            let toastText = didClearLocalHistory
                ? "Account deleted.".localized
                : "Account deleted. Local history couldn't be cleared.".localized
            showToast(toastText, style: didClearLocalHistory ? .success : .error)
            return true
        } catch let error where APIError.isCancellation(error) {
            return false
        } catch {
            showToast(APIError.userMessage(for: error), style: .error)
            return false
        }
    }

    func setSession(_ session: AuthSession) async {
        let sessionGeneration = advanceHistoryMutationGeneration()
        self.session = session
        persist(session)

        var localHistoryFallback: [HistoryEntry] = []
        var didClearLocalHistory = true
        do {
            guard let accessToken = try await authenticatedAccessTokenForSignedRequest(), accessToken.isEmpty == false else {
                guard isCurrentSessionIdentity(session),
                      isCurrentHistoryMutationGeneration(sessionGeneration) else { return }
                showToast("Signed in.".localized, style: .success)
                return
            }

            let localHistory = try await loadLocalHistory()
            localHistoryFallback = localHistory
            guard isCurrentSessionIdentity(session),
                  isCurrentHistoryMutationGeneration(sessionGeneration) else { return }
            if localHistory.isEmpty == false {
                try await remoteHistoryClient.upsertHistory(localHistory, accessToken: accessToken)
                guard isCurrentSessionIdentity(session),
                      isCurrentHistoryMutationGeneration(sessionGeneration) else { return }
                didClearLocalHistory = clearLocalHistoryReportingFailure()
            }
            let remoteHistory = try await remoteHistoryClient.fetchHistory(accessToken: accessToken)
            guard isCurrentSessionIdentity(session),
                  isCurrentHistoryMutationGeneration(sessionGeneration) else { return }
            history = remoteHistory
            let text: String
            if localHistory.isEmpty {
                text = "Signed in.".localized
            } else if didClearLocalHistory {
                text = "Signed in. Listings synced.".localized
            } else {
                text = "Signed in. Listings synced. Local history couldn't be cleared.".localized
            }
            showToast(text, style: didClearLocalHistory ? .success : .error)
        } catch let error where APIError.isCancellation(error) {
            guard isCurrentSessionIdentity(session),
                  isCurrentHistoryMutationGeneration(sessionGeneration) else { return }
        } catch {
            guard isCurrentSessionIdentity(session),
                  isCurrentHistoryMutationGeneration(sessionGeneration) else { return }
            if localHistoryFallback.isEmpty == false {
                history = localHistoryFallback
            }
            showToast(APIError.userMessage(for: error), style: .error)
        }
    }

    func showToast(_ text: String, style: ToastStyle) {
        toast = ToastMessage(text: text, style: style)
    }

    func updateEntitlementSnapshot(_ snapshot: EntitlementSnapshot?) {
        guard let snapshot = snapshot?.sanitizedForUse else { return }
        latestEntitlementSnapshot = snapshot
        persistEntitlementSnapshot()
    }

    private func showSessionExpiredToast() {
        showToast(APIError.sessionExpired.localizedDescription, style: .error)
    }

    func authenticatedAccessToken() async -> String? {
        try? await authenticatedAccessTokenForSignedRequest()
    }

    private func authenticatedAccessTokenForSignedRequest() async throws -> String? {
        guard let session = try await authenticatedSessionForRequest() else { return nil }
        let accessToken = session.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        return accessToken?.isEmpty == false ? accessToken : nil
    }

    func clearToast(id: UUID) {
        guard toast?.id == id else { return }
        toast = nil
    }

    private func loadLocalHistory() async throws -> [HistoryEntry] {
        if let historyReader {
            return try await historyReader.entries().compactMap { $0.sanitizedForHistory() }
        }
        guard let modelContext else { return [] }
        let descriptor = FetchDescriptor<HistoryEntryModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).compactMap { $0.entry.sanitizedForHistory() }
    }

    private func clearLocalHistory() throws {
        guard let modelContext else { return }
        try modelContext.delete(model: HistoryEntryModel.self)
        try modelContext.save()
    }

    @discardableResult
    private func clearLocalHistoryReportingFailure() -> Bool {
        do {
            try clearLocalHistory()
            return true
        } catch {
            logger.error("Local history clear failed")
            return false
        }
    }

    private func upsertVisibleHistory(_ entry: HistoryEntry, replacing existingEntry: HistoryEntry?) {
        if let existingID = existingEntry?.id,
           let index = history.firstIndex(where: { $0.id == existingID }) {
            history[index] = entry
        } else {
            history.insert(entry, at: 0)
        }
    }

    private func upsertLocalHistory(_ entry: HistoryEntry, in modelContext: ModelContext) throws {
        let id = entry.id
        let descriptor = FetchDescriptor<HistoryEntryModel>(
            predicate: #Predicate { $0.id == id }
        )
        if let existingModel = try modelContext.fetch(descriptor).first {
            existingModel.update(from: entry)
        } else {
            modelContext.insert(HistoryEntryModel(entry: entry))
        }
    }

    private func recordSavedListingAnalytics(
        _ entry: HistoryEntry,
        isNewListing: Bool,
        createsSecondListing: Bool
    ) {
        guard isNewListing else { return }
        ProductAnalytics.record(
            .itemSaved,
            properties: [
                "category": entry.category?.rawValue ?? "unknown",
                "marketplace": entry.marketplace.rawValue,
                "has_thumbnail": entry.imageThumbnail == nil ? "false" : "true",
                "has_answers": entry.itemDetails == nil ? "false" : "true",
                "has_structured_draft": entry.listingDraft == nil ? "false" : "true",
                "has_identification_profile": entry.identificationProfile == nil ? "false" : "true",
                "evidence_source_count": "\(entry.listingDraft?.evidenceSources?.count ?? 0)"
            ]
        )
        if createsSecondListing {
            ProductAnalytics.record(.userCreatedSecondListing)
        }
    }

    private func answersApplyingRememberedPreferences(
        _ answers: ItemDetailAnswers?,
        preferredMarketplace: Marketplace?
    ) -> ItemDetailAnswers? {
        guard let preferredMarketplace,
              let rememberedSellingPreferences,
              let rememberedNote = cleanMarketplacePreference(
                rememberedSellingPreferences.marketplaceNote(for: preferredMarketplace)
              )
        else {
            return answers
        }

        var mergedAnswers = answers ?? ItemDetailAnswers()
        guard mergedAnswers.hasMarketplaceNoteOrSkipped(preferredMarketplace) == false else {
            return answers
        }
        mergedAnswers.setMarketplaceNote(rememberedNote, for: preferredMarketplace)
        return mergedAnswers.sanitizedForUse
    }

    private func rememberSellingPreferences(from details: ItemDetailAnswers?) {
        guard let details else { return }
        var updatedPreferences = rememberedSellingPreferences ?? ItemDetailAnswers()

        details.answeredMarketplaces.forEach { marketplace in
            guard cleanMarketplacePreference(details.marketplaceNote(for: marketplace)) == nil else { return }
            updatedPreferences.setMarketplaceNote("", for: marketplace)
        }

        details.marketplaceNotes.forEach { marketplace, note in
            if let cleanNote = cleanMarketplacePreference(note) {
                updatedPreferences.setMarketplaceNote(cleanNote, for: marketplace)
            }
        }

        rememberedSellingPreferences = Self.marketplacePreferenceSnapshot(from: updatedPreferences)
        persistRememberedSellingPreferences()
    }

    private func persistRememberedSellingPreferences() {
        guard let rememberedSellingPreferences,
              let data = try? JSONEncoder().encode(rememberedSellingPreferences)
        else {
            defaults.removeObject(forKey: Keys.sellingPreferences)
            return
        }
        defaults.set(data, forKey: Keys.sellingPreferences)
    }

    private func persistEntitlementSnapshot() {
        guard let latestEntitlementSnapshot,
              let data = try? JSONEncoder().encode(latestEntitlementSnapshot)
        else {
            defaults.removeObject(forKey: Keys.latestEntitlementSnapshot)
            return
        }
        defaults.set(data, forKey: Keys.latestEntitlementSnapshot)
    }

    private static func storedSellingPreferences(from defaults: UserDefaults) -> ItemDetailAnswers? {
        guard let data = defaults.data(forKey: Keys.sellingPreferences),
              let decoded = try? JSONDecoder().decode(ItemDetailAnswers.self, from: data)
        else {
            return nil
        }
        return marketplacePreferenceSnapshot(from: decoded)
    }

    private static func storedEntitlementSnapshot(from defaults: UserDefaults) -> EntitlementSnapshot? {
        guard let data = defaults.data(forKey: Keys.latestEntitlementSnapshot),
              let decoded = try? JSONDecoder().decode(EntitlementSnapshot.self, from: data)
        else {
            return nil
        }
        return decoded.sanitizedForUse
    }

    private static func marketplacePreferenceSnapshot(from details: ItemDetailAnswers?) -> ItemDetailAnswers? {
        guard let details else { return nil }
        var snapshot = ItemDetailAnswers()
        details.marketplaceNotes.forEach { marketplace, note in
            let cleanNote = cleanMarketplacePreference(note)
            if let cleanNote {
                snapshot.setMarketplaceNote(cleanNote, for: marketplace)
            }
        }
        return snapshot.sanitizedForUse
    }

    private static func cleanMarketplacePreference(_ value: String) -> String? {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanValue.isEmpty == false else { return nil }
        return String(cleanValue.prefix(220))
    }

    private static func imageSizeBucket(for byteCount: Int) -> String {
        switch byteCount {
        case 0..<150_000:
            "small"
        case 150_000..<700_000:
            "medium"
        default:
            "large"
        }
    }

    private func cleanMarketplacePreference(_ value: String) -> String? {
        Self.cleanMarketplacePreference(value)
    }

    private func persist(_ session: AuthSession) {
        saveCredential(session.userID, for: Keys.authUserID)
        saveOptional(session.appleUserID, for: Keys.appleUserID)
        saveOptional(session.email, for: Keys.authEmail)
        saveOptional(session.accessToken, for: Keys.supabaseAccessToken)
        saveOptional(session.refreshToken, for: Keys.supabaseRefreshToken)
    }

    private func saveCredential(_ value: String, for key: String) {
        do {
            try Keychain.save(value, for: key)
        } catch {
            logger.error("Credential persistence write failed")
        }
    }

    private func saveOptional(_ value: String?, for key: String) {
        guard let value, value.isEmpty == false else {
            Keychain.delete(key)
            return
        }
        saveCredential(value, for: key)
    }

    private var hasRemoteSessionCredentials: Bool {
        guard let session else { return false }
        return session.accessToken?.isEmpty == false || session.refreshToken?.isEmpty == false
    }

    private func authenticatedSessionForRequest() async throws -> AuthSession? {
        guard let currentSession = session else { return nil }
        guard isCurrentSession(currentSession) else { return nil }
        let currentAccessToken = currentSession.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let currentAccessToken,
           currentAccessToken.isEmpty == false,
           Self.shouldRefreshAccessToken(currentAccessToken) == false {
            return currentSession
        }

        guard let refreshToken = currentSession.refreshToken, refreshToken.isEmpty == false else {
            guard let currentAccessToken,
                  Self.canUseAccessTokenAfterRefreshFailure(currentAccessToken) else {
                return nil
            }
            return currentSession
        }

        do {
            let refreshedSession = try await supabaseAuthClient.refreshSession(currentSession)
            guard isCurrentSession(currentSession) else { return nil }
            session = refreshedSession
            persist(refreshedSession)
            return refreshedSession
        } catch let error where APIError.isCancellation(error) {
            throw error
        } catch {
            guard let currentAccessToken,
                  Self.canUseAccessTokenAfterRefreshFailure(currentAccessToken) else {
                throw error
            }
            return currentSession
        }
    }

    private static func shouldRefreshAccessToken(_ accessToken: String, now: Date = Date()) -> Bool {
        guard let expirationDate = jwtExpirationDate(in: accessToken) else {
            return true
        }
        return expirationDate <= now.addingTimeInterval(300)
    }

    private static func canUseAccessTokenAfterRefreshFailure(_ accessToken: String, now: Date = Date()) -> Bool {
        guard let expirationDate = jwtExpirationDate(in: accessToken) else {
            return true
        }
        return expirationDate > now
    }

    private static func jwtExpirationDate(in token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2,
              let payloadData = base64URLDecodedData(String(parts[1])),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let expiration = payload["exp"] as? TimeInterval
        else {
            return nil
        }
        return Date(timeIntervalSince1970: expiration)
    }

    private static func base64URLDecodedData(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64.append(String(repeating: "=", count: padding))
        return Data(base64Encoded: base64)
    }

    private func clearStoredSession() {
        Self.clearStoredSessionValues()
    }

    @discardableResult
    private func advanceFlowGeneration() -> Int {
        flowTransitionTask?.cancel()
        flowTransitionTask = nil
        flowGeneration += 1
        return flowGeneration
    }

    private func isCurrentFlowGeneration(_ generation: Int) -> Bool {
        generation == flowGeneration
    }

    @discardableResult
    private func advanceModalPresentationGeneration() -> Int {
        modalPresentationTask?.cancel()
        modalPresentationTask = nil
        modalPresentationGeneration += 1
        return modalPresentationGeneration
    }

    private func isCurrentModalPresentationGeneration(_ generation: Int) -> Bool {
        generation == modalPresentationGeneration
    }

    @discardableResult
    private func advanceHistoryMutationGeneration() -> Int {
        sessionResetHistoryTask?.cancel()
        sessionResetHistoryTask = nil
        historySyncState = .idle
        historyMutationGeneration += 1
        return historyMutationGeneration
    }

    private func isCurrentHistoryMutationGeneration(_ generation: Int) -> Bool {
        generation == historyMutationGeneration
    }

    private func isCurrentSession(_ session: AuthSession) -> Bool {
        self.session?.userID == session.userID &&
            self.session?.accessToken == session.accessToken &&
            self.session?.refreshToken == session.refreshToken
    }

    private func isCurrentSessionIdentity(_ session: AuthSession) -> Bool {
        self.session?.userID == session.userID &&
            self.session?.appleUserID == session.appleUserID
    }

    private static func clearStoredSessionValues() {
        Keychain.delete(Keys.appleUserID)
        Keychain.delete(Keys.authUserID)
        Keychain.delete(Keys.authEmail)
        Keychain.delete(Keys.supabaseAccessToken)
        Keychain.delete(Keys.supabaseRefreshToken)
    }

    private func scheduleSessionResetHistoryLoad() {
        let generation = historyMutationGeneration
        sessionResetHistoryTask?.cancel()
        sessionResetHistoryTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.loadHistory()
            guard
                Task.isCancelled == false,
                self.isCurrentHistoryMutationGeneration(generation)
            else { return }
            self.sessionResetHistoryTask = nil
        }
    }

    private func scheduleRemoteHistoryMutation(
        _ operation: @escaping @MainActor @Sendable (AppStore) async -> Void
    ) {
        let id = UUID()
        remoteHistoryMutationTasks[id] = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.remoteHistoryMutationTasks[id] = nil }
            await operation(self)
        }
    }

    private func cancelRemoteHistoryMutationTasks() {
        remoteHistoryMutationTasks.values.forEach { $0.cancel() }
        remoteHistoryMutationTasks.removeAll()
    }

    private func observeAppleCredentialRevocation() {
        credentialRevocationObserver = NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppleCredentialRevoked()
            }
        }
    }

#if DEBUG
    private static var uiTestingHistoryEntry: HistoryEntry {
        HistoryEntry(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            itemName: "Vintage brass table lamp",
            category: .home,
            condition: .good,
            suggestedPrice: Decimal(45),
            imageThumbnail: ImageTools.jpegDataDownscaled(from: ImageTools.sampleJPEG(), maxLongEdge: 200, compression: 0.75),
            marketplace: .ebay,
            listingText: "TITLE:\nVintage brass table lamp\n\nDESCRIPTION:\nWarm brass table lamp in good condition."
        )
    }

    private static func uiTestingHistoryEntries(count: Int) -> [HistoryEntry] {
        let thumbnail = ImageTools.jpegDataDownscaled(from: ImageTools.sampleJPEG(), maxLongEdge: 200, compression: 0.75)
        let marketplaces = Marketplace.allCases

        return (0..<count).map { offset in
            let displayNumber = count - offset
            let marketplace = marketplaces.isEmpty ? Marketplace.ebay : marketplaces[offset % marketplaces.count]

            return HistoryEntry(
                id: UUID(),
                createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(displayNumber)),
                itemName: "Large history item \(displayNumber)",
                category: .home,
                condition: .good,
                suggestedPrice: Decimal(displayNumber),
                imageThumbnail: thumbnail,
                marketplace: marketplace,
                listingText: "TITLE:\nLarge history item \(displayNumber)\n\nDESCRIPTION:\nLarge history item \(displayNumber) in good condition."
            )
        }
    }
#endif
}

private enum Keys {
    static let theme = "themePreference"
    static let reduceMotion = "reduceMotion"
    static let sellingPreferences = "sellingPreferences"
    static let latestEntitlementSnapshot = "latestEntitlementSnapshot"
    static let hasSeenHowItWorks = "hasSeenHowItWorks"
    static let appleUserID = "appleUserID"
    static let authUserID = "authUserID"
    static let authEmail = "authEmail"
    static let supabaseAccessToken = "supabaseAccessToken"
    static let supabaseRefreshToken = "supabaseRefreshToken"
}

struct RootView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var osReduceMotion
    @Environment(\.legibilityWeight) private var legibilityWeight
    @State private var showSplash = true

    var body: some View {
        @Bindable var store = appStore

        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                HomeView()
                    .transition(AppMotion.screenTransition(reduceMotion: shouldReduceMotion))
            }
        }
        .accessibilityHidden(appStore.flowSheetContext != nil)
        .preferredColorScheme(appStore.preferredColorScheme)
        .environment(\.appReduceMotion, appStore.reduceMotion)
        .fontWeight(legibilityWeight == .bold ? .bold : nil)
        .dynamicTypeLimit()
        .fullScreenCover(isPresented: $store.isShowingCamera, onDismiss: {
            appStore.presentPendingCapturedPhoto()
        }) {
            CameraView(
                scanRequest: appStore.activeCameraScanRequest,
                onCapture: { data in appStore.handleCapturedPhoto(data) },
                onCancel: { appStore.cancelCamera() },
                onSkipTargetedScan: { appStore.skipActiveTargetedScanFromCamera() }
            )
        }
        .fullScreenCover(isPresented: $store.isShowingTutorial) {
            HowItWorksView(onClose: { appStore.markTutorialSeen() })
        }
        .sheet(isPresented: $store.isShowingAuth) {
            AuthView()
                .nativeSystemSheetPresentationChrome()
        }
        .sheet(isPresented: $store.isShowingSettings) {
            SettingsView()
                .nativeSystemSheetPresentationChrome()
        }
        .sheet(isPresented: flowSheetBinding) {
            FlowSheetContent()
                .nativeSystemFlowSheetPresentationChrome(detents: flowSheetDetents)
        }
        .overlay(alignment: .top) {
            if let toast = appStore.toast {
                ToastView(toast: toast)
                    .padding(.top, Spacing.md)
                    .transition(AppMotion.toastTransition(reduceMotion: shouldReduceMotion))
                    .task(id: toast.id) {
                        let delay: UInt64 = LaunchArguments.isUITesting ? 5_000_000_000 : 2_300_000_000
                        try? await Task.sleep(nanoseconds: delay)
                        appStore.clearToast(id: toast.id)
                    }
            }
        }
        .overlay(alignment: .bottom) {
            if let uiTestClipboardStatus = appStore.uiTestClipboardStatus {
                Text(uiTestClipboardStatus)
                    .font(.caption2)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .accessibilityIdentifier("ClipboardVerification")
            }
        }
        .overlay(alignment: .bottom) {
            if LaunchArguments.contains(LaunchArguments.uiTestingStateProbe) {
                Text(appStore.uiTestSettingsStateDescription)
                    .font(.caption2)
                    .padding(4)
                    .background(Color.brand.surface)
                    .accessibilityIdentifier("SettingsStateProbe")
            }
        }
        .task {
            appStore.configure(modelContext: modelContext)
            await appStore.loadHistory()
        }
        .task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(AppMotion.screenAnimation(reduceMotion: shouldReduceMotion)) {
                showSplash = false
            }
            if appStore.shouldShowTutorialOnLaunch {
                try? await Task.sleep(nanoseconds: 240_000_000)
                appStore.isShowingTutorial = true
            }
        }
    }

    private var shouldReduceMotion: Bool {
        AppMotion.shouldReduceMotion(os: osReduceMotion, app: appStore.reduceMotion)
    }

    private var flowSheetBinding: Binding<Bool> {
        Binding {
            appStore.flowSheetContext != nil
        } set: { isPresented in
            if isPresented == false {
                appStore.dismissFlowSheet()
            }
        }
    }

    private var flowSheetDetents: Set<PresentationDetent> {
        switch appStore.flowSheetContext {
        case .snapResult:
            [.large]
        case .itemQuestions, .targetedScanReview, .marketplacePicker, .listing:
            [.large]
        case nil:
            [.large]
        }
    }
}

private struct FlowSheetContent: View {
    @Environment(AppStore.self) private var appStore

    var body: some View {
        Group {
            switch appStore.flowSheetContext {
            case .snapResult(let context):
                SnapResultSheet(context: context)
            case .itemQuestions(let context):
                ItemQuestionsSheet(context: context)
            case .targetedScanReview(let context):
                TargetedScanReviewSheet(context: context)
            case .marketplacePicker(let context):
                MarketplacePickerSheet(context: context)
            case .listing(let context):
                ListingSheet(context: context)
            case nil:
                Color.clear
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilitySortPriority(1_000)
    }
}

private struct TargetedScanReviewSheet: View {
    let context: TargetedScanReviewContext

    @Environment(AppStore.self) private var appStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        HStack(alignment: .center, spacing: Spacing.md) {
                            PhotoThumbnail(data: context.imageData, size: 72, category: .other)

                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Photo needs a quick check".localized)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Color.brand.foreground)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(context.fixPrompt.localized)
                                    .font(.body)
                                    .foregroundStyle(Color.brand.foregroundSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityElement(children: .combine)

                        Label {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(context.request.title.localized)
                                    .font(.headline)
                                    .foregroundStyle(Color.brand.foreground)
                                Text("A clearer scan helps BuySell confirm this detail. You can still use this photo or skip it.".localized)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.brand.foregroundSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } icon: {
                            Image(systemName: "camera.metering.unknown")
                                .brandSymbol(.controlIcon)
                                .foregroundStyle(Color.brand.primaryText)
                                .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .padding(.vertical, Spacing.sm)
                } footer: {
                    Text("Skipping will keep going without this scan.".localized)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Check photo".localized)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                bottomActions
            }
        }
    }

    @ViewBuilder
    private var bottomActions: some View {
        let usesStack = dynamicTypeSize.isAccessibilitySize
        Group {
            if usesStack {
                VStack(spacing: Spacing.sm) {
                    retakeButton
                    usePhotoButton
                    skipButton
                }
            } else {
                VStack(spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        retakeButton
                        usePhotoButton
                    }
                    skipButton
                }
            }
        }
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .background(.bar)
    }

    private var retakeButton: some View {
        Button {
            appStore.retakeTargetedScanPhoto()
        } label: {
            Label("Retake".localized, systemImage: AppSymbol.Action.retakePhoto)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Color.brand.primary)
        .accessibilityLabel("Retake".localized)
        .accessibilityHint(context.fixPrompt.localized)
    }

    private var usePhotoButton: some View {
        Button {
            appStore.useTargetedScanPhoto()
        } label: {
            Label("Use Photo".localized, systemImage: "checkmark.circle")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(Color.brand.foregroundSecondary)
        .accessibilityLabel("Use Photo".localized)
        .accessibilityHint("Keeps this scan and continues with lower confidence.".localized)
    }

    private var skipButton: some View {
        Button {
            appStore.skipTargetedScanPhoto()
        } label: {
            Text("Skip".localized)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(Color.brand.foregroundSecondary)
        .accessibilityLabel("Skip".localized)
        .accessibilityHint("Keeps going without this scan.".localized)
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.brand.launchBackground.ignoresSafeArea()
            BrandWordmark(
                size: .display,
                foreground: Color.brand.launchForeground,
                periodColor: Color.brand.launchPrimary
            )
        }
    }
}
