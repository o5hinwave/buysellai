import SwiftUI
import UIKit

struct SnapResultSheet: View {
    let context: SnapResultContext

    @Environment(AppStore.self) private var appStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var store: SnapResultStore
    @State private var isEditingName = false
    @State private var automaticCancellationRetryCount = 0
    @State private var analysisTask: Task<Void, Never>?
    @State private var analysisTaskID = UUID()
    @State private var isSheetVisible = true
    @FocusState private var focusedField: Field?

    init(context: SnapResultContext) {
        self.context = context
        _store = State(initialValue: SnapResultStore(imageData: context.imageData))
    }

    var body: some View {
        NavigationStack {
            List {
                switch store.phase {
                case .idle, .loading:
                    Section {
                        loadingView
                    }
                case .success:
                    if let item = store.item {
                        resultView(item: item)
                    }
                case .failed(let message):
                    Section {
                        errorView(message: message)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, listBottomContentInset, for: .scrollContent)
            .navigationTitle("Item details".localized)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if case .success = store.phase, let item = store.item {
                    decisionBar(item: item)
                }
            }
        }
        .background(Color.clear)
        .task {
            isSheetVisible = true
            await store.analyzeIfNeeded(accessToken: await appStore.authenticatedAccessToken())
        }
        .onDisappear {
            isSheetVisible = false
            cancelAnalysisTask()
        }
        .onChange(of: store.phase) { oldPhase, newPhase in
            retryVisibleAnalysisIfCancelled(from: oldPhase, to: newPhase)
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
            if store.showStillWorking || (store.phase == .idle && automaticCancellationRetryCount > 0) {
                VStack(spacing: Spacing.sm) {
                    Text("Still working… tap Retry to try again.".localized)
                        .brandFont(.caption)
                        .foregroundStyle(Color.brand.destructive)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("SnapResult.StillWorkingAlert")
                        .accessibilityLabel("Still working… tap Retry to try again.".localized)
                    Button {
                        Haptics.impact(.light)
                        retryAnalysis()
                    } label: {
                        Label("Retry".localized, systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .accessibilityLabel("Retry".localized)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .accessibilityElement(children: .combine)
        .accessibilitySortPriority(3)
    }

    private func retryVisibleAnalysisIfCancelled(from oldPhase: SnapResultStore.Phase, to newPhase: SnapResultStore.Phase) {
        guard isSheetVisible,
              automaticCancellationRetryCount == 0,
              oldPhase == .loading,
              newPhase == .idle else { return }
        automaticCancellationRetryCount += 1
        analyzeIfNeeded()
    }

    private func announceStillWorkingAlertIfNeeded(_ isShowing: Bool) {
        guard isShowing else { return }
        UIAccessibility.post(
            notification: .announcement,
            argument: "Still working… tap Retry to try again.".localized
        )
    }

    @ViewBuilder
    private func resultView(item: DetectedItem) -> some View {
        Section {
            resultHeader
                .frame(maxWidth: sheetContentMaxWidth, alignment: .leading)
                .accessibilitySortPriority(5)
        }

        Section {
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

            secondaryActions(item: item)
                .accessibilitySortPriority(2)
        }
    }

    private func decisionBar(item: DetectedItem) -> some View {
        VStack(spacing: Spacing.xs) {
            Button {
                proceedWithItem(item)
            } label: {
                Label("Looks right — pick where to sell".localized, systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Color.brand.primary)
            .accessibilityLabel("Looks right — pick where to sell".localized)
            .accessibilitySortPriority(3)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .frame(maxWidth: sheetContentMaxWidth)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func proceedWithItem(_ fallbackItem: DetectedItem) {
        Haptics.impact(.medium)
        store.commitEdits()
        let item = store.item ?? fallbackItem
        if let preferred = context.preferredMarketplace {
            appStore.presentListing(item: item, imageData: context.imageData, marketplace: preferred)
        } else {
            appStore.presentMarketplacePicker(item: item, imageData: context.imageData)
        }
    }

    @ViewBuilder
    private func secondaryActions(item: DetectedItem) -> some View {
        if usesRegularSecondaryActionGrid {
            LazyVGrid(columns: secondaryActionColumns, spacing: Spacing.sm) {
                retakeButton
                retryButton
                categoryMenuButton(selected: item.category)
                conditionMenuButton(selected: item.condition)
            }
        } else {
            VStack(spacing: Spacing.sm) {
                LazyVGrid(columns: compactQuickActionColumns, spacing: Spacing.sm) {
                    retakeButton
                    retryButton
                }
                categoryMenuButton(selected: item.category)
                conditionMenuButton(selected: item.condition)
            }
        }
    }

    private var retakeButton: some View {
        Button {
            Haptics.impact(.light)
            appStore.retakePhoto(keeping: context.preferredMarketplace)
        } label: {
            Label("Wrong item — retake".localized, systemImage: "camera.rotate")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .accessibilityLabel("Wrong item — retake".localized)
    }

    private var retryButton: some View {
        Button {
            Haptics.impact(.light)
            retryAnalysis()
        } label: {
            Label("Try again".localized, systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .accessibilityLabel("Try again".localized)
    }

    @ViewBuilder
    private var resultHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.md) {
                PhotoThumbnail(data: context.imageData, size: 64)
                itemSummaryControls
            }
        } else {
            HStack(alignment: .center, spacing: Spacing.md) {
                PhotoThumbnail(data: context.imageData, size: 64)
                itemSummaryControls
            }
        }
    }

    private var itemSummaryControls: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            itemNameControl
            priceEditor
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var priceEditor: some View {
        HStack(spacing: 0) {
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
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .price)
                .onSubmit { store.commitEdits() }
                .accessibilityLabel("Estimated price".localized)
        }
        .focusedInputChrome(
            isFocused: focusedField == .price,
            horizontalPadding: Spacing.sm,
            verticalPadding: Spacing.xxs
        )
    }

    private func categoryMenuButton(selected: Category) -> some View {
        Menu {
            ForEach(Category.allCases, id: \.self) { category in
                Button {
                    Haptics.impact(.light)
                    store.selectCategory(category)
                } label: {
                    menuItemLabel(
                        title: category.display,
                        systemImage: categoryMenuItemIcon(for: category),
                        isSelected: category == selected
                    )
                }
                .accessibilityLabel(category.display)
            }
        } label: {
            SnapResultMenuLabel(title: "Change category", systemImage: "tag", maxWidth: sheetContentMaxWidth)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .simultaneousGesture(TapGesture().onEnded {
            Haptics.impact(.light)
        })
        .accessibilityLabel("Change category".localized)
        .accessibilityValue(Text(selected.display.localized))
        .accessibilityHint("Opens category choices".localized)
    }

    private func conditionMenuButton(selected: Condition) -> some View {
        Menu {
            ForEach(Condition.allCases, id: \.self) { condition in
                Button {
                    Haptics.impact(.light)
                    store.selectCondition(condition)
                } label: {
                    menuItemLabel(
                        title: condition.display,
                        systemImage: conditionMenuItemIcon(for: condition),
                        isSelected: condition == selected
                    )
                }
                .accessibilityLabel(condition.display)
            }
        } label: {
            SnapResultMenuLabel(title: "Change condition", systemImage: "slider.horizontal.3", maxWidth: sheetContentMaxWidth)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .simultaneousGesture(TapGesture().onEnded {
            Haptics.impact(.light)
        })
        .accessibilityLabel("Change condition".localized)
        .accessibilityValue(Text(selected.display.localized))
        .accessibilityHint("Opens condition choices".localized)
    }

    @ViewBuilder
    private func menuItemLabel(title: String, systemImage: String, isSelected: Bool) -> some View {
        Label {
            Text(title.localized)
        } icon: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : systemImage)
        }
    }

    private func categoryMenuItemIcon(for category: Category) -> String {
        switch category {
        case .electronics: "display"
        case .furniture: "house"
        case .clothing: "tshirt"
        case .shoes: "shoeprints.fill"
        case .bags: "handbag"
        case .jewelry: "sparkles"
        case .toys: "gamecontroller"
        case .kids: "figure.2"
        case .home: "house"
        case .tools: "wrench.and.screwdriver"
        case .sports: "sportscourt"
        case .books: "books.vertical"
        case .media: "play.rectangle"
        case .music: "music.note"
        case .collectibles: "star"
        case .art: "paintpalette"
        case .other: "shippingbox"
        }
    }

    private func conditionMenuItemIcon(for condition: Condition) -> String {
        switch condition {
        case .new: "sparkles"
        case .likeNew: "checkmark.seal"
        case .good: "hand.thumbsup"
        case .fair: "exclamationmark.circle"
        case .forParts: "wrench"
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
                .focusedInputChrome(
                    isFocused: focusedField == .name,
                    horizontalPadding: Spacing.sm,
                    verticalPadding: Spacing.xxs
                )
                .submitLabel(.done)
                .onSubmit {
                    store.commitEdits()
                    isEditingName = false
                    focusedField = nil
                }
                .accessibilityLabel("Item name".localized)
        } else {
            Button {
                Haptics.impact(.light)
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
                .buttonStyle(PressButtonStyle())
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
            Button {
                Haptics.impact(.light)
                appStore.retakePhoto(keeping: context.preferredMarketplace)
            } label: {
                Label("Retake photo".localized, systemImage: "camera.rotate")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Color.brand.primary)
            .accessibilityLabel("Retake photo".localized)
            Button {
                Haptics.impact(.light)
                retryAnalysis()
            } label: {
                Label("Try again".localized, systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .accessibilityLabel("Try again".localized)
        }
        .frame(maxWidth: .infinity, minHeight: 420)
        .task(id: message) {
            appStore.showToast(message, style: .error)
        }
        .accessibilitySortPriority(3)
    }

    private enum Field {
        case name
        case price
    }

    private var sheetContentMaxWidth: CGFloat {
        usesRegularWidthLayout ? 760 : .infinity
    }

    private var listBottomContentInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 144 : 96
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular || UIDevice.current.userInterfaceIdiom == .pad
    }

    private var secondaryActionColumns: [GridItem] {
        [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var compactQuickActionColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var usesRegularSecondaryActionGrid: Bool {
        (usesRegularWidthLayout || UIScreen.main.bounds.width >= 430)
            && dynamicTypeSize.isAccessibilitySize == false
    }

    private func retryAnalysis() {
        startAnalysisTask(retry: true)
    }

    private func analyzeIfNeeded() {
        startAnalysisTask(retry: false)
    }

    private func startAnalysisTask(retry: Bool) {
        cancelAnalysisTask()
        let taskID = UUID()
        analysisTaskID = taskID
        analysisTask = Task { @MainActor in
            if retry {
                await store.analyze(accessToken: await appStore.authenticatedAccessToken())
            } else {
                await store.analyzeIfNeeded(accessToken: await appStore.authenticatedAccessToken())
            }
            guard Task.isCancelled == false, analysisTaskID == taskID else { return }
            analysisTask = nil
        }
    }

    private func cancelAnalysisTask() {
        analysisTask?.cancel()
        analysisTask = nil
    }
}

private struct SnapResultMenuLabel: View {
    let title: String
    let systemImage: String
    var maxWidth: CGFloat?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .accessibilityHidden(true)

            Text(title.localized)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(minimumScaleFactor)
                .layoutPriority(1)

            Spacer(minLength: Spacing.xs)

            Image(systemName: "chevron.down")
                .brandSymbol(.smallChevron)
                .foregroundStyle(Color.brand.mutedForeground)
                .accessibilityHidden(true)
        }
        .brandFont(.caption)
        .foregroundStyle(Color.brand.foreground)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: maxWidth ?? .infinity, minHeight: 44)
        .contentShape(Rectangle())
    }

    private var lineLimit: Int {
        2
    }

    private var minimumScaleFactor: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 0.82 : 0.8
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
                        Image(systemName: "camera.fill")
                            .foregroundStyle(Color.brand.primaryText)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityLabel("Item photo".localized)
    }
}
