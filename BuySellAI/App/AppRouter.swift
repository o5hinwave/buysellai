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

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var modelContext: ModelContext?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if ProcessInfo.processInfo.arguments.contains("--reset-tutorial") {
            defaults.removeObject(forKey: Keys.hasSeenHowItWorks)
        }
        let storedTheme = defaults.string(forKey: Keys.theme).flatMap(ThemePreference.init(rawValue:))
        self.theme = storedTheme ?? .system
        self.reduceMotion = defaults.bool(forKey: Keys.reduceMotion)

        if let appleID = Keychain.load(Keys.appleUserID) {
            self.session = AuthSession(userID: appleID, email: nil, accessToken: nil)
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var shouldShowTutorialOnLaunch: Bool {
        defaults.bool(forKey: Keys.hasSeenHowItWorks) == false
    }

    func configure(modelContext: ModelContext) {
        guard self.modelContext == nil else { return }
        self.modelContext = modelContext
        loadHistory()
    }

    func markTutorialSeen() {
        defaults.set(true, forKey: Keys.hasSeenHowItWorks)
        isShowingTutorial = false
    }

    func startSnapFlow() {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            snapResultContext = SnapResultContext(imageData: ImageTools.sampleJPEG())
        } else {
            isShowingCamera = true
        }
    }

    func handleCapturedPhoto(_ data: Data) {
        isShowingCamera = false
        snapResultContext = SnapResultContext(imageData: data)
    }

    func presentMarketplacePicker(item: DetectedItem, imageData: Data) {
        snapResultContext = nil
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            marketplacePickerContext = MarketplacePickerContext(item: item, imageData: imageData)
        }
    }

    func presentListing(item: DetectedItem, imageData: Data?, marketplace: Marketplace, existingListingText: String? = nil) {
        marketplacePickerContext = nil
        snapResultContext = nil
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            listingContext = ListingContext(
                item: item,
                imageData: imageData,
                marketplace: marketplace,
                existingListingText: existingListingText
            )
        }
    }

    func retakePhoto(keeping marketplace: Marketplace? = nil) {
        listingContext = nil
        marketplacePickerContext = nil
        snapResultContext = nil
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                snapResultContext = SnapResultContext(imageData: ImageTools.sampleJPEG(), preferredMarketplace: marketplace)
            } else {
                isShowingCamera = true
            }
        }
    }

    func closeFlow() {
        snapResultContext = nil
        marketplacePickerContext = nil
        listingContext = nil
        isShowingCamera = false
    }

    func loadHistory() {
        guard let modelContext else { return }
        do {
            let descriptor = FetchDescriptor<HistoryEntryModel>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            history = try modelContext.fetch(descriptor).map(\.entry)
        } catch {
            showToast("Couldn't load recent listings.", style: .error)
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

        if let modelContext {
            modelContext.insert(HistoryEntryModel(entry: entry))
            do {
                try modelContext.save()
            } catch {
                showToast("Couldn't save this listing.", style: .error)
            }
        }
        history.insert(entry, at: 0)
    }

    func deleteHistory(_ entry: HistoryEntry) {
        guard let modelContext else {
            history.removeAll { $0.id == entry.id }
            return
        }
        do {
            let id = entry.id
            let descriptor = FetchDescriptor<HistoryEntryModel>(
                predicate: #Predicate { $0.id == id }
            )
            let matches = try modelContext.fetch(descriptor)
            matches.forEach(modelContext.delete)
            try modelContext.save()
            history.removeAll { $0.id == entry.id }
            Haptics.notify(.warning)
        } catch {
            showToast("Couldn't delete this listing.", style: .error)
        }
    }

    func clearHistory() {
        guard let modelContext else {
            history.removeAll()
            return
        }
        do {
            try modelContext.delete(model: HistoryEntryModel.self)
            try modelContext.save()
            history.removeAll()
            showToast("History cleared.", style: .success)
        } catch {
            showToast("Couldn't clear history.", style: .error)
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
        Keychain.delete(Keys.appleUserID)
        showToast("Signed out.", style: .success)
    }

    func setAppleSession(userID: String, email: String?) {
        session = AuthSession(userID: userID, email: email, accessToken: nil)
        try? Keychain.save(userID, for: Keys.appleUserID)
        showToast("Signed in.", style: .success)
    }

    func showToast(_ text: String, style: ToastStyle) {
        toast = ToastMessage(text: text, style: style)
    }

    func clearToast(id: UUID) {
        guard toast?.id == id else { return }
        toast = nil
    }
}

private enum Keys {
    static let theme = "themePreference"
    static let reduceMotion = "reduceMotion"
    static let hasSeenHowItWorks = "hasSeenHowItWorks"
    static let appleUserID = "appleUserID"
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
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .preferredColorScheme(appStore.preferredColorScheme)
        .environment(\.appReduceMotion, appStore.reduceMotion || osReduceMotion)
        .fontWeight(legibilityWeight == .bold ? .bold : nil)
        .dynamicTypeLimit()
        .fullScreenCover(isPresented: $store.isShowingCamera) {
            CameraView(
                onCapture: { data in appStore.handleCapturedPhoto(data) },
                onCancel: { appStore.isShowingCamera = false }
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
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: toast.id) {
                        let delay: UInt64 = ProcessInfo.processInfo.arguments.contains("--ui-testing") ? 5_000_000_000 : 2_300_000_000
                        try? await Task.sleep(nanoseconds: delay)
                        appStore.clearToast(id: toast.id)
                    }
            }
        }
        .task {
            appStore.configure(modelContext: modelContext)
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(AppMotion.animation(reduceMotion: appStore.reduceMotion || osReduceMotion)) {
                showSplash = false
            }
            if appStore.shouldShowTutorialOnLaunch {
                try? await Task.sleep(nanoseconds: 240_000_000)
                appStore.isShowingTutorial = true
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.brand.background.ignoresSafeArea()
            BrandWordmark(size: .display)
        }
    }
}
