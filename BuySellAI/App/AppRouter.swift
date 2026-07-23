import AuthenticationServices
import Observation
import os
import SwiftData
import SwiftUI
import UIKit

enum FlowSheetContext: Equatable {
    case snapResult(SnapResultContext)
    case marketplacePicker(MarketplacePickerContext)
    case listing(ListingContext)
}

@MainActor
@Observable
final class AppStore {
    var session: AuthSession?
    var history: [HistoryEntry] = []
    var theme: ThemePreference {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }
    var reduceMotion: Bool {
        didSet { defaults.set(reduceMotion, forKey: Keys.reduceMotion) }
    }

    var isShowingCamera = false
    var isShowingTutorial = false
    var isShowingAuth = false
    var isShowingSettings = false
    var snapResultContext: SnapResultContext?
    var marketplacePickerContext: MarketplacePickerContext?
    var listingContext: ListingContext?
    var flowSheetContext: FlowSheetContext?
    var toast: ToastMessage?
    var uiTestClipboardStatus: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var historyReader: HistoryReader?
    @ObservationIgnored private let remoteHistoryClient: RemoteHistoryClient
    @ObservationIgnored private let accountClient: AccountClient
    @ObservationIgnored private let supabaseAuthClient: SupabaseAuthClient
    @ObservationIgnored private let logger = Logger(subsystem: "BuySellAI", category: "Persistence")
    @ObservationIgnored private let flowTransitionDelayNanoseconds: UInt64
    @ObservationIgnored private var pendingCapturedPhotoData: Data?
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
        }
        let storedTheme = defaults.string(forKey: Keys.theme).flatMap(ThemePreference.init(rawValue:))
        self.theme = storedTheme ?? .system
        self.reduceMotion = defaults.bool(forKey: Keys.reduceMotion)

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
        advanceFlowGeneration()
        pendingCapturedPhotoData = data
        isShowingCamera = false
    }

    func presentPendingCapturedPhoto() {
        guard let data = pendingCapturedPhotoData else { return }
        pendingCapturedPhotoData = nil
        presentFlowSheet(.snapResult(SnapResultContext(imageData: data)))
    }

    func cancelCamera() {
        pendingCapturedPhotoData = nil
        isShowingCamera = false
    }

    func presentMarketplacePicker(item: DetectedItem, imageData: Data) {
        advanceFlowGeneration()
        presentFlowSheet(.marketplacePicker(MarketplacePickerContext(item: item, imageData: imageData)))
    }

    func presentListing(
        item: DetectedItem,
        imageData: Data?,
        marketplace: Marketplace,
        existingListingText: String? = nil,
        existingHistoryEntry: HistoryEntry? = nil
    ) {
        advanceFlowGeneration()
        presentFlowSheet(
            .listing(
                ListingContext(
                    item: item,
                    imageData: imageData,
                    marketplace: marketplace,
                    existingListingText: existingListingText,
                    existingHistoryEntry: existingHistoryEntry
                )
            )
        )
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
        marketplacePickerContext = nil
        listingContext = nil

        switch context {
        case .snapResult(let snapResult):
            snapResultContext = snapResult
        case .marketplacePicker(let marketplacePicker):
            marketplacePickerContext = marketplacePicker
        case .listing(let listing):
            listingContext = listing
        }

        flowSheetContext = context
    }

    private func clearFlowSheetState() {
        snapResultContext = nil
        marketplacePickerContext = nil
        listingContext = nil
        flowSheetContext = nil
    }

    func loadHistory() async {
        let refreshGeneration = historyMutationGeneration

#if DEBUG
        if LaunchArguments.contains(LaunchArguments.uiTestingSlowHistoryLoad) {
            do {
                try await Task.sleep(nanoseconds: 4_000_000_000)
            } catch {
                return
            }
        }

        if LaunchArguments.contains(LaunchArguments.seedLargeHistory) {
            guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
            history = Self.uiTestingHistoryEntries(count: 500)
            return
        }

        if LaunchArguments.contains(LaunchArguments.seedHistory) {
            guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
            history = [Self.uiTestingHistoryEntry]
            return
        }
#endif

        if hasRemoteSessionCredentials {
            do {
                guard let accessToken = try await authenticatedAccessTokenForSignedRequest(), accessToken.isEmpty == false else {
                    guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
                    showSessionExpiredToast()
                    return
                }
                let remoteHistory = try await remoteHistoryClient.fetchHistory(accessToken: accessToken)
                guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
                history = remoteHistory
            } catch let error where APIError.isCancellation(error) {
                return
            } catch {
                guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
                showToast(APIError.userMessage(for: error), style: .error)
            }
            return
        }

        do {
            let localHistory = try await loadLocalHistory()
            guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
            history = localHistory
        } catch let error where APIError.isCancellation(error) {
            return
        } catch {
            guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
            showToast("Couldn't load recent listings.".localized, style: .error)
        }
    }

    func saveListing(
        item: DetectedItem,
        imageData: Data?,
        marketplace: Marketplace,
        listingText: String,
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
        let entry = HistoryEntry(
            id: existingEntry?.id ?? UUID(),
            createdAt: existingEntry?.createdAt ?? Date(),
            itemName: cleanItemName,
            category: item.category,
            condition: item.condition,
            suggestedPrice: item.priceEstimate,
            imageThumbnail: thumbnail,
            marketplace: marketplace,
            listingText: cleanListingText
        )

        let previousHistory = history
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
            } catch {
                history = previousHistory
                showToast("Couldn't save this listing.".localized, style: .error)
            }
        }
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
        let item = DetectedItem(
            name: entry.itemName,
            category: entry.category ?? .other,
            condition: entry.condition ?? .good,
            priceEstimate: entry.suggestedPrice ?? Decimal(1)
        )
        presentListing(
            item: item,
            imageData: entry.imageThumbnail,
            marketplace: entry.marketplace,
            existingListingText: entry.listingText,
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
                onCapture: { data in appStore.handleCapturedPhoto(data) },
                onCancel: { appStore.cancelCamera() }
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
        .overlay {
            if let flowSheetContext = appStore.flowSheetContext {
                FlowSheetOverlay(context: flowSheetContext, reduceMotion: shouldReduceMotion)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
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

}

private struct FlowSheetOverlay: View {
    let context: FlowSheetContext
    let reduceMotion: Bool

    @Environment(AppStore.self) private var appStore
    @State private var snapResultDetent: FlowSheetDetent = .medium
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.brand.shadow.opacity(0.10)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)

                sheetCard(height: sheetHeight(in: proxy), bottomInset: proxy.safeAreaInsets.bottom)
                    .offset(y: dragOffset)
                    .gesture(dismissDragGesture)
            }
            .ignoresSafeArea(edges: .bottom)
            .animation(reduceMotion ? AppMotion.quick : AppMotion.sheet, value: dragOffset)
            .animation(reduceMotion ? AppMotion.quick : AppMotion.sheet, value: snapResultDetent)
        }
        .onChange(of: context) { _, newContext in
            if case .snapResult = newContext {
                snapResultDetent = .medium
            }
            dragOffset = 0
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel(flowSheetAccessibilityLabel)
        .accessibilityValue(flowSheetAccessibilityValue)
        .accessibilityHint(flowSheetAccessibilityHint)
        .accessibilityAction(.escape) {
            dismiss()
        }
        .modifier(FlowSheetAdjustableActionModifier(isEnabled: isSnapResultSheet) { direction in
            adjustSnapResultDetent(direction)
        })
        .accessibilitySortPriority(1_000)
    }

    private func sheetCard(height: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.brand.mutedForeground.opacity(0.32))
                .frame(width: 54, height: 6)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xs)
                .accessibilityHidden(true)

            content

            Color.clear
                .frame(height: bottomInset)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .nativeMaterialSheet(cornerRadius: 28, tintOpacity: 0.88, strokeOpacity: 0.68)
        .modifier(AppShadow.elevated())
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var content: some View {
        switch context {
        case .snapResult(let context):
            SnapResultSheet(context: context)
        case .marketplacePicker(let context):
            MarketplacePickerSheet(context: context)
        case .listing(let context):
            ListingSheet(context: context)
        }
    }

    private func sheetHeight(in proxy: GeometryProxy) -> CGFloat {
        switch context {
        case .snapResult:
            switch snapResultDetent {
            case .medium:
                mediumSheetHeight(in: proxy)
            case .large:
                largeSheetHeight(in: proxy)
            }
        case .marketplacePicker, .listing:
            largeSheetHeight(in: proxy)
        }
    }

    private func mediumSheetHeight(in proxy: GeometryProxy) -> CGFloat {
        min(max(proxy.size.height * 0.64, 520), largeSheetHeight(in: proxy))
    }

    private func largeSheetHeight(in proxy: GeometryProxy) -> CGFloat {
        proxy.size.height - largeSheetTopInset(in: proxy)
    }

    private func largeSheetTopInset(in proxy: GeometryProxy) -> CGFloat {
        max(proxy.safeAreaInsets.top + Spacing.md, 68)
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                dragOffset = interactiveDragOffset(for: value.translation.height)
            }
            .onEnded { value in
                if shouldExpandSnapResult(for: value) {
                    snapResultDetent = .large
                    dragOffset = 0
                } else if shouldCollapseSnapResult(for: value) {
                    snapResultDetent = .medium
                    dragOffset = 0
                } else if shouldDismiss(for: value) {
                    dismiss()
                } else {
                    dragOffset = 0
                }
            }
    }

    private var isSnapResultSheet: Bool {
        if case .snapResult = context {
            return true
        }
        return false
    }

    private func interactiveDragOffset(for translationHeight: CGFloat) -> CGFloat {
        guard isSnapResultSheet, snapResultDetent == .medium, translationHeight < 0 else {
            return max(0, translationHeight)
        }
        return max(translationHeight * 0.22, -44)
    }

    private func shouldExpandSnapResult(for value: DragGesture.Value) -> Bool {
        guard isSnapResultSheet, snapResultDetent == .medium else { return false }
        return value.translation.height < -72 || value.predictedEndTranslation.height < -132
    }

    private func shouldCollapseSnapResult(for value: DragGesture.Value) -> Bool {
        guard isSnapResultSheet, snapResultDetent == .large else { return false }
        guard shouldDismiss(for: value) == false else { return false }
        return value.translation.height > 72 || value.predictedEndTranslation.height > 132
    }

    private func shouldDismiss(for value: DragGesture.Value) -> Bool {
        if isSnapResultSheet, snapResultDetent == .large {
            return value.translation.height > 220 || value.predictedEndTranslation.height > 320
        }
        return value.translation.height > 110 || value.predictedEndTranslation.height > 180
    }

    private func dismiss() {
        withAnimation(reduceMotion ? AppMotion.quick : AppMotion.sheet) {
            appStore.dismissFlowSheet()
            dragOffset = 0
        }
    }

    private var flowSheetAccessibilityLabel: Text {
        switch context {
        case .snapResult:
            Text("Item details".localized)
        case .marketplacePicker:
            Text("Marketplace choices".localized)
        case .listing:
            Text("Listing draft".localized)
        }
    }

    private var flowSheetAccessibilityValue: Text {
        if isSnapResultSheet {
            switch snapResultDetent {
            case .medium:
                Text("Half height".localized)
            case .large:
                Text("Expanded".localized)
            }
        } else {
            Text("Expanded".localized)
        }
    }

    private var flowSheetAccessibilityHint: Text {
        isSnapResultSheet
            ? Text("Swipe up or down to resize. Escape closes the sheet.".localized)
            : Text("Escape closes the sheet.".localized)
    }

    private func adjustSnapResultDetent(_ direction: AccessibilityAdjustmentDirection) {
        guard isSnapResultSheet else { return }
        switch direction {
        case .increment:
            snapResultDetent = .large
            dragOffset = 0
        case .decrement:
            if snapResultDetent == .large {
                snapResultDetent = .medium
                dragOffset = 0
            } else {
                dismiss()
            }
        @unknown default:
            break
        }
    }
}

private struct FlowSheetAdjustableActionModifier: ViewModifier {
    let isEnabled: Bool
    let action: (AccessibilityAdjustmentDirection) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.accessibilityAdjustableAction(action)
        } else {
            content
        }
    }
}

private enum FlowSheetDetent: Equatable {
    case medium
    case large
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
