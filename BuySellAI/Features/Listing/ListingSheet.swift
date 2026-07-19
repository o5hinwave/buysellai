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
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header

                switch store.phase {
                case .idle, .loading:
                    loading
                case .success:
                    listingText
                case .failed(let message):
                    error(message)
                }
            }
            .frame(maxWidth: sheetContentMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(Spacing.xl)
            .padding(.bottom, bottomContentInset)
        }
        .background(Color.clear)
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
        .task {
            await store.generateIfNeeded(accessToken: await appStore.authenticatedAccessToken())
        }
        .onDisappear {
            cancelGenerationTask()
        }
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityHeader
        } else {
            regularHeader
        }
    }

    private var regularHeader: some View {
        HStack(spacing: Spacing.md) {
            MarketplaceIcon(marketplace: context.marketplace)
            headerTitle
            Spacer(minLength: Spacing.md)
            closeListingButton
        }
        .accessibilitySortPriority(4)
    }

    private var accessibilityHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .center, spacing: Spacing.md) {
                MarketplaceIcon(marketplace: context.marketplace)
                Spacer(minLength: Spacing.md)
                closeListingButton
            }

            headerTitle
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilitySortPriority(4)
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(String.localizedFormat("Listing for %@", context.marketplace.displayName))
                .brandFont(.overline)
                .tracking(0.88)
                .foregroundStyle(Color.brand.mutedForeground)
                .textCase(.uppercase)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)
            Text(context.marketplace.displayName)
                .brandFont(.titleLg)
                .foregroundStyle(Color.brand.foreground)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var closeListingButton: some View {
        IconCircleButton(
            systemImage: "xmark",
            accessibilityLabel: "Close listing",
            material: true,
            materialForeground: Color.brand.foreground,
            materialStroke: Color.brand.border,
            usesAccessibleMaterialStroke: true
        ) {
            appStore.closeFlow()
        }
    }

    private var loading: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Writing your listing…".localized)
                .brandFont(.title)
                .foregroundStyle(Color.brand.foreground)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(0..<8, id: \.self) { index in
                    SkeletonLine(width: index == 7 ? 180 : nil)
                }
            }
            .padding(Spacing.lg)
            .nativeMaterialPanel(cornerRadius: Radius.lg, tintOpacity: 0.78, strokeOpacity: 0.62)
        }
        .accessibilityElement(children: .combine)
        .accessibilitySortPriority(3)
    }

    private var listingText: some View {
        Text(store.listingText)
            .brandFont(.body)
            .foregroundStyle(Color.brand.foreground)
            .lineSpacing(4)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .nativeMaterialPanel(cornerRadius: Radius.lg, tintOpacity: 0.78, strokeOpacity: 0.62)
            .accessibilityLabel("Generated listing text".localized)
            .accessibilityValue(store.listingText)
            .accessibilitySortPriority(3)
    }

    private func error(_ message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Text(message)
                .brandFont(.bodyLg)
                .foregroundStyle(Color.brand.destructive)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("Listing.ErrorMessage")
            PrimaryPillButton(title: "Regenerate", systemImage: "arrow.clockwise", maxFillWidth: sheetContentMaxWidth) {
                regenerateListing()
            }
            SecondaryPillButton(title: "Wrong item — retake", systemImage: "camera.rotate", maxFillWidth: sheetContentMaxWidth) {
                retakePhoto()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
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
            PrimaryPillButton(
                title: "Copy listing",
                systemImage: "doc.on.doc.fill",
                maxFillWidth: sheetContentMaxWidth,
                hapticStyle: nil
            ) {
                copyListing()
            }
            .disabled(copyableListingText.isEmpty)
            .accessibilitySortPriority(3)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Spacing.sm) {
                    GhostButton(title: "Wrong item — retake", systemImage: "camera.rotate", maxFillWidth: sheetContentMaxWidth) {
                        retakePhoto()
                    }
                    GhostButton(title: "Regenerate", systemImage: "arrow.clockwise", maxFillWidth: sheetContentMaxWidth) {
                        regenerateListing()
                    }
                }
                .accessibilitySortPriority(2)
            } else {
                HStack(spacing: Spacing.sm) {
                    GhostButton(title: "Wrong item — retake", systemImage: "camera.rotate", maxFillWidth: sheetContentMaxWidth) {
                        retakePhoto()
                    }
                    GhostButton(title: "Regenerate", systemImage: "arrow.clockwise", maxFillWidth: sheetContentMaxWidth) {
                        regenerateListing()
                    }
                }
                .accessibilitySortPriority(2)
            }

            Text("Tip: paste, add photos, hit list. That's it.".localized)
                .brandFont(.caption)
                .foregroundStyle(Color.brand.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.xxs)
                .accessibilitySortPriority(1)
        }
        .frame(maxWidth: sheetContentMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .nativeMaterialBar(tintOpacity: 0.78)
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

    private var sheetContentMaxWidth: CGFloat {
        usesRegularWidthLayout ? 820 : .infinity
    }

    private var usesRegularWidthLayout: Bool {
        horizontalSizeClass == .regular || UIDevice.current.userInterfaceIdiom == .pad
    }

    private var bottomContentInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 220 : 150
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
