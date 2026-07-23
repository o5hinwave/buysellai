import SwiftUI
import UIKit

struct ListingSheet: View {
    let context: ListingContext

    @Environment(AppStore.self) private var appStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var store: ListingStore
    @State private var generationTask: Task<Void, Never>?
    @State private var generationTaskID = UUID()

    init(context: ListingContext) {
        self.context = context
        _store = State(initialValue: ListingStore(
            item: context.item,
            marketplace: context.marketplace,
            existingListingText: context.existingListingText
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                }

                phaseSections
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, bottomContentInset, for: .scrollContent)
            .navigationTitle("Ready to copy".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    closeListingButton
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomActions
            }
            .background(Color.clear)
        }
        .background(Color.clear)
        .task {
            await store.generateIfNeeded(accessToken: await appStore.authenticatedAccessToken())
        }
        .onDisappear {
            cancelGenerationTask()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            MarketplaceIcon(marketplace: context.marketplace)
            headerTitle
        }
        .padding(.vertical, Spacing.xs)
        .accessibilitySortPriority(4)
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(String.localizedFormat("Listing for %@", context.marketplace.displayName))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.mutedForeground)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)
            Text(context.marketplace.displayName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var closeListingButton: some View {
        Button {
            Haptics.impact(.light)
            appStore.closeFlow()
        } label: {
            Label("Close listing".localized, systemImage: "xmark")
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel("Close listing".localized)
    }

    @ViewBuilder
    private var phaseSections: some View {
        switch store.phase {
        case .idle, .loading:
            Section {
                loading
            }
        case .success:
            Section("Generated listing text".localized) {
                listingText
            }
            Section {
                listingRecommendationSummary
            }
            Section("Price plan".localized) {
                listingPriceRow(
                    title: "List at",
                    value: pricePlan.listAt,
                    detail: "Start here"
                )
                listingPriceRow(
                    title: "Likely sells for",
                    value: pricePlan.likelySellsFor,
                    detail: "Expected sale"
                )
                listingPriceRow(
                    title: "Take-home estimate",
                    value: pricePlan.takeHomeEstimate,
                    detail: "What you may keep"
                )
            }
            Section("Quick tips".localized) {
                marketplaceTipRow(
                    title: "Main photo",
                    systemImage: "photo",
                    detail: store.draft?.firstPhoto ?? context.marketplace.optimizationProfile.photoGuidance
                )
                if let missingPhotoPrompt = store.draft?.missingPhotoPrompt {
                    marketplaceTipRow(
                        title: "Photo to add",
                        systemImage: "plus.viewfinder",
                        detail: missingPhotoPrompt
                    )
                }
                marketplaceTipRow(
                    title: "What helps here",
                    systemImage: "sparkles",
                    detail: store.draft?.fitReason ?? context.marketplace.optimizationProfile.featuredGuidance
                )
                if let itemSpecifics = joinedDraftValues(store.draft?.itemSpecifics) {
                    marketplaceTipRow(
                        title: "Details to include",
                        systemImage: "list.bullet.rectangle",
                        detail: itemSpecifics
                    )
                }
                if let postingNotes = joinedDraftValues(store.draft?.postingNotes) {
                    marketplaceTipRow(
                        title: "When posting",
                        systemImage: "checklist",
                        detail: postingNotes
                    )
                }
                if let tags = joinedDraftValues(store.draft?.tags) {
                    marketplaceTipRow(
                        title: "Tags",
                        systemImage: "tag",
                        detail: tags
                    )
                }
            }
        case .failed(let message):
            Section {
                error(message)
            }
        }
    }

    private var loading: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Label("Writing your listing…".localized, systemImage: "pencil.and.outline")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(0..<8, id: \.self) { index in
                    SkeletonLine(width: skeletonLineWidth(for: index))
                }
            }
        }
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Writing your listing…".localized)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilitySortPriority(3)
    }

    private var listingRecommendationSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label(recommendationLabel.localized, systemImage: "checkmark.seal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(String.localizedFormat("Ready for %@", context.marketplace.displayName))
                    .font(.headline)
                    .foregroundStyle(Color.brand.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text(recommendationReason)
                    .font(.body)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            recommendationTakeHome
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@, %@, %@", recommendationLabel.localized, String.localizedFormat("Ready for %@", context.marketplace.displayName), recommendationReason))
        .accessibilityValue(String.localizedFormat("%@, %@", "Take-home estimate".localized, pricePlan.takeHomeEstimate.currency(code: context.item.currencyCode)))
        .accessibilityIdentifier("Listing.RecommendationSummary")
        .accessibilitySortPriority(3)
    }

    @ViewBuilder
    private var recommendationTakeHome: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Take-home".localized)
                    .font(.caption)
                    .foregroundStyle(Color.brand.mutedForeground)
                Text(pricePlan.takeHomeEstimate.currency(code: context.item.currencyCode))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.brand.foreground)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text("Take-home".localized)
                    .font(.body)
                    .foregroundStyle(Color.brand.foreground)
                Spacer(minLength: Spacing.md)
                Text(pricePlan.takeHomeEstimate.currency(code: context.item.currencyCode))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.brand.foreground)
            }
        }
    }

    private var recommendationLabel: String {
        switch selectedRecommendationKind {
        case .bestChance:
            "Best chance to sell"
        case .mostMoneyBack:
            "Most money back"
        case .goodFit, .second, .third:
            "Good place to sell"
        }
    }

    private var recommendationReason: String {
        store.draft?.fitReason ?? context.marketplace.recommendationReason(for: context.item)
    }

    private var selectedRecommendationKind: MarketplaceSummaryKind {
        MarketplaceSummaryPlanner
            .picks(from: MarketplaceEstimator.estimates(for: context.item.priceEstimate))
            .first { $0.estimate.id == context.marketplace }?
            .kind ?? .bestChance
    }

    private var listingText: some View {
        Text(store.listingText)
            .font(.body)
            .foregroundStyle(Color.brand.foreground)
            .lineSpacing(4)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.sm)
            .accessibilityLabel("Generated listing text".localized)
            .accessibilityValue(store.listingText)
            .accessibilitySortPriority(3)
    }

    private func listingPriceRow(title: String, value: Decimal, detail: String) -> some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(value.currency(code: context.item.currencyCode))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.brand.foreground)
                Text(detail.localized)
                    .font(.caption)
                    .foregroundStyle(Color.brand.mutedForeground)
            }
        } label: {
            Text(title.localized)
                .font(.body)
                .foregroundStyle(Color.brand.foreground)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@, %@", title.localized, value.currency(code: context.item.currencyCode)))
    }

    private func marketplaceTipRow(title: String, systemImage: String, detail: String) -> some View {
        LabeledContent {
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.brand.mutedForeground)
                .multilineTextAlignment(.trailing)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 5 : 3)
                .fixedSize(horizontal: false, vertical: true)
        } label: {
            Label(title.localized, systemImage: systemImage)
                .font(.body)
                .foregroundStyle(Color.brand.foreground)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String.localizedFormat("%@, %@", title.localized, detail))
    }

    private func joinedDraftValues(_ values: [String]?) -> String? {
        let cleanValues = values?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false } ?? []
        guard cleanValues.isEmpty == false else { return nil }
        return cleanValues.joined(separator: ", ")
    }

    private func error(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(Color.brand.destructive)
                .accessibilityHidden(true)

            Text(message)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("Listing.ErrorMessage")

            Button {
                Haptics.impact(.light)
                regenerateListing()
            } label: {
                Label("Regenerate".localized, systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.brand.primary)
            .accessibilityLabel("Regenerate".localized)

            Button {
                Haptics.impact(.light)
                retakePhoto()
            } label: {
                Label("Wrong item — retake".localized, systemImage: "camera.rotate")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityLabel("Wrong item — retake".localized)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .accessibilitySortPriority(3)
        .task(id: message) {
            appStore.showToast(message, style: .error)
        }
    }

    @ViewBuilder
    private var bottomActions: some View {
        switch store.phase {
        case .success:
            successBottomActions
        case .idle, .loading, .failed:
            EmptyView()
        }
    }

    private var successBottomActions: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                copyListing()
            } label: {
                Label("Copy listing".localized, systemImage: "doc.on.doc.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Color.brand.primary)
            .disabled(copyableListingText.isEmpty)
            .accessibilityLabel("Copy listing".localized)
            .accessibilitySortPriority(3)

            secondaryActionButton(title: "Try another marketplace", systemImage: "arrow.left.arrow.right") {
                chooseAnotherMarketplace()
            }
            .accessibilitySortPriority(2)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Spacing.sm) {
                    secondaryActionButton(title: "Wrong item — retake", systemImage: "camera.rotate") {
                        retakePhoto()
                    }
                    secondaryActionButton(title: "Regenerate", systemImage: "arrow.clockwise") {
                        regenerateListing()
                    }
                }
                .accessibilitySortPriority(2)
            } else {
                HStack(spacing: Spacing.sm) {
                    secondaryActionButton(title: "Wrong item — retake", systemImage: "camera.rotate") {
                        retakePhoto()
                    }
                    secondaryActionButton(title: "Regenerate", systemImage: "arrow.clockwise") {
                        regenerateListing()
                    }
                }
                .accessibilitySortPriority(2)
            }

            Text("Tip: paste, add photos, hit list. That's it.".localized)
                .font(.caption)
                .foregroundStyle(Color.brand.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.xxs)
                .accessibilitySortPriority(1)
        }
        .frame(maxWidth: sheetContentMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .background(.bar)
    }

    private func secondaryActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            Label(title.localized, systemImage: systemImage)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityLabel(title.localized)
    }

    private func regenerateListing() {
        generationTask?.cancel()
        let taskID = UUID()
        generationTaskID = taskID
        generationTask = Task { @MainActor in
            await store.generate(accessToken: await appStore.authenticatedAccessToken())
            guard Task.isCancelled == false, generationTaskID == taskID else { return }
            generationTask = nil
        }
    }

    private func chooseAnotherMarketplace() {
        appStore.presentMarketplacePicker(item: context.item, imageData: context.imageData)
    }

    private func retakePhoto() {
        appStore.retakePhoto(keeping: context.marketplace)
    }

    private func copyListing() {
        let cleanText = copyableListingText
        guard cleanText.isEmpty == false else {
            appStore.showToast(APIError.decoding.localizedDescription, style: .error)
            return
        }
        UIPasteboard.general.string = cleanText
        if LaunchArguments.contains(LaunchArguments.uiTestingVerifyClipboard) {
            appStore.uiTestClipboardStatus = clipboardStatus(expected: cleanText)
        }
        Haptics.notify(.success)
        appStore.saveListing(
            item: context.item,
            imageData: context.imageData,
            marketplace: context.marketplace,
            listingText: cleanText,
            replacing: context.existingHistoryEntry
        )
        appStore.showToast(String.localizedFormat("Copied — paste it into %@", context.marketplace.displayName), style: .success)
        appStore.closeFlow()
    }

    private var copyableListingText: String {
        (try? ListingTextContract.validatedGenerated(store.listingText)) ?? ""
    }

    private var pricePlan: ListingPricePlan {
        ListingPricePlan(item: context.item, marketplace: context.marketplace, draft: store.draft)
    }

    private var sheetContentMaxWidth: CGFloat {
        usesRegularWidthLayout ? 820 : .infinity
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular || UIDevice.current.userInterfaceIdiom == .pad
    }

    private var bottomContentInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 300 : 216
    }

    private func skeletonLineWidth(for index: Int) -> CGFloat? {
        switch index {
        case 1, 4:
            240
        case 7:
            180
        default:
            nil
        }
    }

    private func clipboardStatus(expected cleanText: String) -> String {
        let copiedText = UIPasteboard.general.string ?? ""
        let isTrimmed = copiedText == copiedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasPreamble = copiedText.localizedCaseInsensitiveContains("Here's your listing")
            || copiedText.localizedCaseInsensitiveContains("Here’s your listing")
        return copiedText == cleanText && isTrimmed && hasPreamble == false
            ? "Clipboard exact listing text"
            : "Clipboard mismatch"
    }

    private func cancelGenerationTask() {
        generationTask?.cancel()
        generationTask = nil
    }
}

private struct ListingPricePlan {
    let listAt: Decimal
    let likelySellsFor: Decimal
    let takeHomeEstimate: Decimal

    private static let likelySaleMultiplier = Decimal(9) / Decimal(10)

    init(item: DetectedItem, marketplace: Marketplace, draft: GeneratedListingDraft?) {
        let localTakeHomeEstimate = MarketplaceEstimator.estimates(for: item.priceEstimate)
            .first { $0.id == marketplace }?
            .payout ?? item.priceEstimate * marketplace.feeMultiplier - marketplace.fixedDeduction

        listAt = max((draft?.listPrice ?? item.priceEstimate).rounded(scale: 0), Decimal(1))
        likelySellsFor = max(
            (draft?.likelySalePrice ?? item.priceEstimate * Self.likelySaleMultiplier).rounded(scale: 0),
            Decimal(1)
        )
        takeHomeEstimate = max((draft?.takeHomeEstimate ?? localTakeHomeEstimate).rounded(scale: 0), Decimal(1))
    }
}
