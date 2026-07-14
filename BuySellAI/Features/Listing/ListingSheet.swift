import SwiftUI
import UIKit

struct ListingSheet: View {
    let context: ListingContext

    @Environment(AppStore.self) private var appStore
    @State private var store: ListingStore

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
            .padding(Spacing.xl)
            .padding(.bottom, 150)
        }
        .background(Color.brand.background)
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
        .task {
            await store.generateIfNeeded(accessToken: appStore.session?.accessToken)
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            MarketplaceIcon(marketplace: context.marketplace)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(String.localizedFormat("Listing for %@", context.marketplace.displayName))
                    .brandFont(.overline)
                    .tracking(0.88)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .textCase(.uppercase)
                Text(context.marketplace.displayName)
                    .brandFont(.titleLg)
                    .foregroundStyle(Color.brand.foreground)
            }

            Spacer()

            IconCircleButton(systemImage: "xmark", accessibilityLabel: "Close listing") {
                appStore.closeFlow()
            }
        }
        .accessibilitySortPriority(4)
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
            .background(Color.brand.secondary, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
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
            .background(Color.brand.secondary, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .accessibilityLabel("Generated listing text".localized)
            .accessibilitySortPriority(3)
    }

    private func error(_ message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Text(message)
                .brandFont(.bodyLg)
                .foregroundStyle(Color.brand.destructive)
                .multilineTextAlignment(.center)
            PrimaryPillButton(title: "Regenerate", systemImage: "arrow.clockwise") {
                Task { await store.generate(accessToken: appStore.session?.accessToken) }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .accessibilitySortPriority(3)
    }

    private var bottomActions: some View {
        VStack(spacing: Spacing.sm) {
            PrimaryPillButton(title: "Copy listing", systemImage: "doc.on.doc.fill") {
                copyListing()
            }
            .disabled(store.phase != .success || store.listingText.isEmpty)
            .accessibilitySortPriority(3)

            HStack(spacing: Spacing.sm) {
                GhostButton(title: "Wrong item — retake", systemImage: "camera.rotate") {
                    appStore.retakePhoto(keeping: context.marketplace)
                }
                GhostButton(title: "Regenerate", systemImage: "arrow.clockwise") {
                    Task { await store.generate(accessToken: appStore.session?.accessToken) }
                }
            }
            .accessibilitySortPriority(2)

            Text("Tip: paste, add photos, hit list. That's it.".localized)
                .brandFont(.caption)
                .foregroundStyle(Color.brand.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.xxs)
                .accessibilitySortPriority(1)
        }
        .padding(Spacing.lg)
        .background(.regularMaterial)
    }

    private func copyListing() {
        let cleanText = store.listingText.trimmingCharacters(in: .whitespacesAndNewlines)
        UIPasteboard.general.string = cleanText
        Haptics.notify(.success)
        appStore.saveListing(
            item: context.item,
            imageData: context.imageData,
            marketplace: context.marketplace,
            listingText: cleanText
        )
        appStore.closeFlow()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 260_000_000)
            appStore.showToast(String.localizedFormat("Copied — paste it into %@", context.marketplace.displayName), style: .success)
        }
    }
}
