import SwiftUI
import UIKit

struct SnapResultSheet: View {
    let context: SnapResultContext

    @Environment(AppStore.self) private var appStore
    @State private var store: SnapResultStore
    @FocusState private var focusedField: Field?

    init(context: SnapResultContext) {
        self.context = context
        _store = State(initialValue: SnapResultStore(imageData: context.imageData))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                switch store.phase {
                case .idle, .loading:
                    loadingView
                case .success:
                    if let item = store.item {
                        resultView(item: item)
                    }
                case .failed(let message):
                    errorView(message: message)
                }
            }
            .padding(Spacing.xl)
        }
        .background(Color.brand.background)
        .task {
            await store.analyzeIfNeeded(accessToken: appStore.session?.accessToken)
        }
        .onChange(of: store.phase) { _, phase in
            if case .failed(let message) = phase {
                appStore.showToast(message, style: .error)
            }
        }
        .onChange(of: store.showStillWorking) { _, isShowing in
            announceStillWorkingAlertIfNeeded(isShowing)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField != nil {
                    Spacer()
                    Button("Done".localized) {
                        store.commitEdits()
                        focusedField = nil
                    }
                    .accessibilityLabel("Done".localized)
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            PhotoThumbnail(data: context.imageData, size: 112)
            ProgressView()
                .tint(Color.brand.primary)
            Text("Analyzing your photo…".localized)
                .brandFont(.title)
                .foregroundStyle(Color.brand.foreground)
            if store.showStillWorking {
                VStack(spacing: Spacing.sm) {
                    Text("Still working… tap Retry to try again.".localized)
                        .brandFont(.caption)
                        .foregroundStyle(Color.brand.destructive)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("SnapResult.StillWorkingAlert")
                        .accessibilityLabel("Still working… tap Retry to try again.".localized)
                    SecondaryPillButton(title: "Retry", fillsWidth: false) {
                        Task { await store.analyze(accessToken: appStore.session?.accessToken) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .accessibilityElement(children: .combine)
        .accessibilitySortPriority(3)
    }

    private func announceStillWorkingAlertIfNeeded(_ isShowing: Bool) {
        guard isShowing else { return }
        UIAccessibility.post(
            notification: .announcement,
            argument: "Still working… tap Retry to try again.".localized
        )
    }

    private func resultView(item: DetectedItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            HStack(alignment: .center, spacing: Spacing.md) {
                PhotoThumbnail(data: context.imageData, size: 64)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    TextField("Item name".localized, text: Binding(
                        get: { store.nameText },
                        set: { store.nameText = $0 }
                    ))
                        .brandFont(.titleLg)
                        .foregroundStyle(Color.brand.foreground)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.done)
                        .onSubmit { store.commitEdits() }
                        .accessibilityLabel("Item name".localized)

                    HStack(spacing: Spacing.xs) {
                        Text("~$")
                            .brandFont(.title)
                            .foregroundStyle(Color.brand.primary)
                        TextField("Price".localized, text: Binding(
                            get: { store.priceText },
                            set: { store.priceText = $0 }
                        ))
                            .brandFont(.title)
                            .foregroundStyle(Color.brand.primary)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .price)
                            .onSubmit { store.commitEdits() }
                            .accessibilityLabel("Estimated price".localized)
                    }
                }
            }
            .accessibilitySortPriority(5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ChipButton(
                        title: item.category.display,
                        accessibilityLabel: ChipAccessibilityText.valueLabel("Category", value: item.category.display),
                        accessibilityHint: "Changes the category"
                    ) {
                        store.cycleCategory()
                    }
                    ChipButton(
                        title: item.condition.display,
                        accessibilityLabel: ChipAccessibilityText.valueLabel("Condition", value: item.condition.display),
                        accessibilityHint: "Changes the condition"
                    ) {
                        store.cycleCondition()
                    }
                }
            }
            .accessibilitySortPriority(4)

            PrimaryPillButton(title: "Looks right — pick where to sell") {
                store.commitEdits()
                guard let item = store.item else { return }
                if let preferred = context.preferredMarketplace {
                    appStore.presentListing(item: item, imageData: context.imageData, marketplace: preferred)
                } else {
                    appStore.presentMarketplacePicker(item: item, imageData: context.imageData)
                }
            }
            .accessibilitySortPriority(3)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sm) {
                GhostButton(title: "Wrong item — retake", systemImage: "camera.rotate") {
                    appStore.retakePhoto(keeping: context.preferredMarketplace)
                }
                GhostButton(title: "Try again", systemImage: "arrow.clockwise") {
                    Task { await store.analyze(accessToken: appStore.session?.accessToken) }
                }
                GhostButton(title: "Change category", systemImage: "tag") {
                    store.cycleCategory()
                }
                GhostButton(title: "Change condition", systemImage: "slider.horizontal.3") {
                    store.cycleCondition()
                }
            }
            .accessibilitySortPriority(2)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            PhotoThumbnail(data: context.imageData, size: 156)
            Text(message)
                .brandFont(.bodyLg)
                .foregroundStyle(Color.brand.destructive)
                .multilineTextAlignment(.center)
            PrimaryPillButton(title: "Retake photo", systemImage: "camera.rotate") {
                appStore.retakePhoto(keeping: context.preferredMarketplace)
            }
            SecondaryPillButton(title: "Try again", systemImage: "arrow.clockwise") {
                Task { await store.analyze(accessToken: appStore.session?.accessToken) }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 420)
        .accessibilitySortPriority(3)
    }

    private enum Field {
        case name
        case price
    }
}

struct PhotoThumbnail: View {
    let data: Data?
    var size: CGFloat

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.brand.primaryMuted
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(Color.brand.primary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityLabel("Item photo".localized)
    }
}
