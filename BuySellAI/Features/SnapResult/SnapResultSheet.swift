import SwiftUI
import UIKit

struct SnapResultSheet: View {
    let context: SnapResultContext

    @Environment(AppStore.self) private var appStore
    @State private var store: SnapResultStore
    @State private var isEditingName = false
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
                        isEditingName = false
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
                    itemNameControl

                    HStack(spacing: Spacing.xs) {
                        Text("~$")
                            .brandFont(.title)
                            .foregroundStyle(Color.brand.primaryText)
                        TextField("Price".localized, text: Binding(
                            get: { store.priceText },
                            set: { store.priceText = $0 }
                        ))
                            .brandFont(.title)
                            .foregroundStyle(Color.brand.primaryText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .price)
                            .onSubmit { store.commitEdits() }
                            .accessibilityLabel("Estimated price".localized)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
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

    @ViewBuilder
    private var itemNameControl: some View {
        if isEditingName {
            TextField("Item name".localized, text: Binding(
                get: { store.nameText },
                set: { store.nameText = $0 }
            ), axis: .vertical)
                .brandFont(.titleLg)
                .foregroundStyle(Color.brand.foreground)
                .lineLimit(1...2)
                .minimumScaleFactor(0.82)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focused($focusedField, equals: .name)
                .submitLabel(.done)
                .onSubmit {
                    store.commitEdits()
                    isEditingName = false
                    focusedField = nil
                }
                .accessibilityLabel("Item name".localized)
        } else {
            Button {
                isEditingName = true
                focusedField = .name
            } label: {
                Text(readableItemName)
                    .brandFont(.titleLg)
                    .foregroundStyle(Color.brand.foreground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityLabel("Item name".localized)
                .accessibilityValue(store.nameText)
                .accessibilityHint("Double-tap to edit the item name".localized)
        }
    }

    private var readableItemName: String {
        let fallback = "Item name".localized
        let name = store.nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else { return fallback }
        guard name.count > 20, name.contains("\n") == false else { return name }

        let words = name.split(separator: " ").map(String.init)
        guard words.count > 1 else { return name }

        let bestSplit = (1..<words.count).min { lhs, rhs in
            let lhsScore = splitBalanceScore(words, at: lhs)
            let rhsScore = splitBalanceScore(words, at: rhs)
            return lhsScore == rhsScore
                ? lineLength(words, endIndex: lhs) < lineLength(words, endIndex: rhs)
                : lhsScore < rhsScore
        } ?? words.count - 1

        return words[..<bestSplit].joined(separator: " ")
            + "\n"
            + words[bestSplit...].joined(separator: " ")
    }

    private func splitBalanceScore(_ words: [String], at index: Int) -> Int {
        abs(lineLength(words, endIndex: index) - lineLength(words, startIndex: index))
    }

    private func lineLength(_ words: [String], startIndex: Int = 0, endIndex: Int? = nil) -> Int {
        let endIndex = endIndex ?? words.count
        guard startIndex < endIndex else { return 0 }
        return words[startIndex..<endIndex].joined(separator: " ").count
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
                            .foregroundStyle(Color.brand.primaryText)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityLabel("Item photo".localized)
    }
}
