import Observation
import SwiftData
import SwiftUI
import UIKit

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
    var toast: ToastMessage?
    var uiTestClipboardStatus: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var historyReader: HistoryReader?
    @ObservationIgnored private let remoteHistoryClient: RemoteHistoryClient
    @ObservationIgnored private let accountClient: AccountClient
    @ObservationIgnored private let flowTransitionDelayNanoseconds: UInt64
    @ObservationIgnored private var pendingCapturedPhotoData: Data?
    @ObservationIgnored private var flowGeneration = 0
    @ObservationIgnored private var historyMutationGeneration = 0

    init(
        defaults: UserDefaults = .standard,
        remoteHistoryClient: RemoteHistoryClient = RemoteHistoryClient(),
        accountClient: AccountClient = AccountClient(),
        flowTransitionDelayNanoseconds: UInt64 = 320_000_000
    ) {
        self.defaults = defaults
        self.remoteHistoryClient = remoteHistoryClient
        self.accountClient = accountClient
        self.flowTransitionDelayNanoseconds = flowTransitionDelayNanoseconds
        if ProcessInfo.processInfo.arguments.contains("--reset-auth") {
            Self.clearStoredSessionValues()
        }
        if ProcessInfo.processInfo.arguments.contains("--reset-tutorial") {
            defaults.removeObject(forKey: Keys.hasSeenHowItWorks)
        }
        if ProcessInfo.processInfo.arguments.contains("--skip-tutorial") {
            defaults.set(true, forKey: Keys.hasSeenHowItWorks)
        }
        if ProcessInfo.processInfo.arguments.contains("--reset-preferences") {
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
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-signed-in") {
            self.session = AuthSession(
                userID: "ui-test-user",
                email: "person@example.com"
            )
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

    func configure(modelContext: ModelContext) {
        guard self.modelContext == nil else { return }
        self.modelContext = modelContext
        self.historyReader = HistoryReader(modelContainer: modelContext.container)
        if ProcessInfo.processInfo.arguments.contains("--reset-history") {
            try? clearLocalHistory()
            advanceHistoryMutationGeneration()
            history.removeAll()
        }
    }

    func markTutorialSeen() {
        defaults.set(true, forKey: Keys.hasSeenHowItWorks)
        isShowingTutorial = false
    }

    func startSnapFlow() {
        advanceFlowGeneration()
        pendingCapturedPhotoData = nil
        let uiTestingCameraMode = ProcessInfo.processInfo.arguments.contains("--ui-testing-camera-denied") ||
            ProcessInfo.processInfo.arguments.contains("--ui-testing-camera-ready")
        if ProcessInfo.processInfo.arguments.contains("--ui-testing"),
           uiTestingCameraMode == false {
            snapResultContext = SnapResultContext(imageData: ImageTools.sampleJPEG())
        } else {
            isShowingCamera = true
        }
    }

    func handleCapturedPhoto(_ data: Data) {
        advanceFlowGeneration()
        pendingCapturedPhotoData = data
        isShowingCamera = false
    }

    func presentPendingCapturedPhoto() {
        guard let data = pendingCapturedPhotoData else { return }
        pendingCapturedPhotoData = nil
        snapResultContext = SnapResultContext(imageData: data)
    }

    func cancelCamera() {
        pendingCapturedPhotoData = nil
        isShowingCamera = false
    }

    func presentMarketplacePicker(item: DetectedItem, imageData: Data) {
        let generation = advanceFlowGeneration()
        snapResultContext = nil
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: flowTransitionDelayNanoseconds)
            guard isCurrentFlowGeneration(generation) else { return }
            marketplacePickerContext = MarketplacePickerContext(item: item, imageData: imageData)
        }
    }

    func presentListing(item: DetectedItem, imageData: Data?, marketplace: Marketplace, existingListingText: String? = nil) {
        let generation = advanceFlowGeneration()
        marketplacePickerContext = nil
        snapResultContext = nil
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: flowTransitionDelayNanoseconds)
            guard isCurrentFlowGeneration(generation) else { return }
            listingContext = ListingContext(
                item: item,
                imageData: imageData,
                marketplace: marketplace,
                existingListingText: existingListingText
            )
        }
    }

    func retakePhoto(keeping marketplace: Marketplace? = nil) {
        let generation = advanceFlowGeneration()
        listingContext = nil
        marketplacePickerContext = nil
        snapResultContext = nil
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: flowTransitionDelayNanoseconds)
            guard isCurrentFlowGeneration(generation) else { return }
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                snapResultContext = SnapResultContext(imageData: ImageTools.sampleJPEG(), preferredMarketplace: marketplace)
            } else {
                isShowingCamera = true
            }
        }
    }

    func closeFlow() {
        advanceFlowGeneration()
        pendingCapturedPhotoData = nil
        snapResultContext = nil
        marketplacePickerContext = nil
        listingContext = nil
        isShowingCamera = false
    }

    func loadHistory() async {
        let refreshGeneration = historyMutationGeneration

        if ProcessInfo.processInfo.arguments.contains("--ui-testing-slow-history-load") {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
        }

        if ProcessInfo.processInfo.arguments.contains("--seed-large-history") {
            guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
            history = Self.uiTestingHistoryEntries(count: 500)
            return
        }

        if ProcessInfo.processInfo.arguments.contains("--seed-history") {
            guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
            history = [Self.uiTestingHistoryEntry]
            return
        }

        if let accessToken = session?.accessToken, accessToken.isEmpty == false {
            do {
                let remoteHistory = try await remoteHistoryClient.fetchHistory(accessToken: accessToken)
                guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
                history = remoteHistory
            } catch {
                guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
                showToast(error.localizedDescription, style: .error)
            }
            return
        }

        do {
            let localHistory = try await loadLocalHistory()
            guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
            history = localHistory
        } catch {
            guard isCurrentHistoryMutationGeneration(refreshGeneration) else { return }
            showToast("Couldn't load recent listings.".localized, style: .error)
        }
    }

    func saveListing(item: DetectedItem, imageData: Data?, marketplace: Marketplace, listingText: String) {
        let thumbnail = imageData.map {
            ImageTools.jpegDataDownscaled(from: $0, maxLongEdge: 200, compression: 0.75)
        }
        let entry = HistoryEntry(
            id: UUID(),
            createdAt: Date(),
            itemName: item.name,
            category: item.category,
            condition: item.condition,
            suggestedPrice: item.priceEstimate,
            imageThumbnail: thumbnail,
            marketplace: marketplace,
            listingText: listingText
        )

        advanceHistoryMutationGeneration()
        history.insert(entry, at: 0)

        if let session, let accessToken = session.accessToken, accessToken.isEmpty == false {
            Task {
                do {
                    try await remoteHistoryClient.upsertHistory([entry], accessToken: accessToken)
                } catch {
                    guard isCurrentSession(session), history.contains(where: { $0.id == entry.id }) else { return }
                    advanceHistoryMutationGeneration()
                    history.removeAll { $0.id == entry.id }
                    showToast(error.localizedDescription, style: .error)
                }
            }
            return
        }

        if let modelContext {
            do {
                modelContext.insert(HistoryEntryModel(entry: entry))
                try modelContext.save()
            } catch {
                advanceHistoryMutationGeneration()
                history.removeAll { $0.id == entry.id }
                showToast("Couldn't save this listing.".localized, style: .error)
            }
        }
    }

    func deleteHistory(_ entry: HistoryEntry) {
        if let session, let accessToken = session.accessToken, accessToken.isEmpty == false {
            let previous = history
            let deleteGeneration = advanceHistoryMutationGeneration()
            history.removeAll { $0.id == entry.id }
            Task {
                do {
                    try await remoteHistoryClient.deleteHistory(id: entry.id, accessToken: accessToken)
                    guard isCurrentSession(session), isCurrentHistoryMutationGeneration(deleteGeneration) else { return }
                    HistoryDeletionFeedback.perform()
                } catch {
                    guard isCurrentSession(session), isCurrentHistoryMutationGeneration(deleteGeneration) else { return }
                    history = previous
                    showToast(error.localizedDescription, style: .error)
                }
            }
            return
        }

        guard let modelContext else {
            advanceHistoryMutationGeneration()
            history.removeAll { $0.id == entry.id }
            HistoryDeletionFeedback.perform()
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
            HistoryDeletionFeedback.perform()
        } catch {
            showToast("Couldn't delete this listing.".localized, style: .error)
        }
    }

    func clearHistory() {
        if let session, let accessToken = session.accessToken, accessToken.isEmpty == false {
            let previous = history
            let clearGeneration = advanceHistoryMutationGeneration()
            history.removeAll()
            Task {
                do {
                    try await remoteHistoryClient.clearHistory(accessToken: accessToken)
                    guard isCurrentSession(session), isCurrentHistoryMutationGeneration(clearGeneration) else { return }
                    showToast("History cleared.".localized, style: .success)
                } catch {
                    guard isCurrentSession(session), isCurrentHistoryMutationGeneration(clearGeneration) else { return }
                    history = previous
                    showToast(error.localizedDescription, style: .error)
                }
            }
            return
        }

        guard let modelContext else {
            advanceHistoryMutationGeneration()
            history.removeAll()
            return
        }
        do {
            advanceHistoryMutationGeneration()
            try modelContext.delete(model: HistoryEntryModel.self)
            try modelContext.save()
            history.removeAll()
            showToast("History cleared.".localized, style: .success)
        } catch {
            showToast("Couldn't clear history.".localized, style: .error)
        }
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
            existingListingText: entry.listingText
        )
    }

    func signOut() {
        session = nil
        clearStoredSession()
        advanceHistoryMutationGeneration()
        Task { await loadHistory() }
        showToast("Signed out.".localized, style: .success)
    }

    func deleteAccount() async -> Bool {
        guard let accessToken = session?.accessToken, accessToken.isEmpty == false else {
            showToast(APIError.notConfigured.localizedDescription, style: .error)
            return false
        }

        do {
            try await accountClient.deleteAccount(accessToken: accessToken)
            session = nil
            clearStoredSession()
            advanceHistoryMutationGeneration()
            history.removeAll()
            try? clearLocalHistory()
            showToast("Account deleted.".localized, style: .success)
            return true
        } catch {
            showToast(error.localizedDescription, style: .error)
            return false
        }
    }

    func setSession(_ session: AuthSession) async {
        let sessionGeneration = advanceHistoryMutationGeneration()
        self.session = session
        persist(session)

        guard let accessToken = session.accessToken, accessToken.isEmpty == false else {
            showToast("Signed in.".localized, style: .success)
            return
        }

        do {
            let localHistory = try await loadLocalHistory()
            guard isCurrentSession(session) else { return }
            if localHistory.isEmpty == false {
                try await remoteHistoryClient.upsertHistory(localHistory, accessToken: accessToken)
                guard isCurrentSession(session) else { return }
                try clearLocalHistory()
            }
            let remoteHistory = try await remoteHistoryClient.fetchHistory(accessToken: accessToken)
            guard isCurrentSession(session), isCurrentHistoryMutationGeneration(sessionGeneration) else { return }
            history = remoteHistory
            let text = (localHistory.isEmpty ? "Signed in." : "Signed in. Listings synced.").localized
            showToast(text, style: .success)
        } catch {
            guard isCurrentSession(session), isCurrentHistoryMutationGeneration(sessionGeneration) else { return }
            showToast(error.localizedDescription, style: .error)
        }
    }

    func showToast(_ text: String, style: ToastStyle) {
        toast = ToastMessage(text: text, style: style)
    }

    func clearToast(id: UUID) {
        guard toast?.id == id else { return }
        toast = nil
    }

    private func loadLocalHistory() async throws -> [HistoryEntry] {
        if let historyReader {
            return try await historyReader.entries()
        }
        guard let modelContext else { return [] }
        let descriptor = FetchDescriptor<HistoryEntryModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.entry)
    }

    private func clearLocalHistory() throws {
        guard let modelContext else { return }
        try modelContext.delete(model: HistoryEntryModel.self)
        try modelContext.save()
    }

    private func persist(_ session: AuthSession) {
        try? Keychain.save(session.userID, for: Keys.authUserID)
        saveOptional(session.appleUserID, for: Keys.appleUserID)
        saveOptional(session.email, for: Keys.authEmail)
        saveOptional(session.accessToken, for: Keys.supabaseAccessToken)
        saveOptional(session.refreshToken, for: Keys.supabaseRefreshToken)
    }

    private func saveOptional(_ value: String?, for key: String) {
        guard let value, value.isEmpty == false else {
            Keychain.delete(key)
            return
        }
        try? Keychain.save(value, for: key)
    }

    private func clearStoredSession() {
        Self.clearStoredSessionValues()
    }

    @discardableResult
    private func advanceFlowGeneration() -> Int {
        flowGeneration += 1
        return flowGeneration
    }

    private func isCurrentFlowGeneration(_ generation: Int) -> Bool {
        generation == flowGeneration
    }

    @discardableResult
    private func advanceHistoryMutationGeneration() -> Int {
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

    private static func clearStoredSessionValues() {
        Keychain.delete(Keys.appleUserID)
        Keychain.delete(Keys.authUserID)
        Keychain.delete(Keys.authEmail)
        Keychain.delete(Keys.supabaseAccessToken)
        Keychain.delete(Keys.supabaseRefreshToken)
    }

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
                listingText: "TITLE:\nLarge history item \(displayNumber)"
            )
        }
    }
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
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $store.isShowingSettings) {
            SettingsView()
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(item: $store.snapResultContext) { context in
            SnapResultSheet(context: context)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(item: $store.marketplacePickerContext) { context in
            MarketplacePickerSheet(context: context)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .sheet(item: $store.listingContext) { context in
            ListingSheet(context: context)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        .overlay(alignment: .top) {
            if let toast = appStore.toast {
                ToastView(toast: toast)
                    .padding(.top, Spacing.md)
                    .transition(AppMotion.toastTransition(reduceMotion: shouldReduceMotion))
                    .task(id: toast.id) {
                        let delay: UInt64 = ProcessInfo.processInfo.arguments.contains("--ui-testing") ? 5_000_000_000 : 2_300_000_000
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
            if ProcessInfo.processInfo.arguments.contains("--ui-testing-state-probe") {
                Text(appStore.uiTestSettingsStateDescription)
                    .font(.caption2)
                    .padding(4)
                    .background(Color.brand.surface)
                    .accessibilityIdentifier("SettingsStateProbe")
            }
        }
        .task {
            appStore.configure(modelContext: modelContext)
            Task { @MainActor in
                await appStore.loadHistory()
            }
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
