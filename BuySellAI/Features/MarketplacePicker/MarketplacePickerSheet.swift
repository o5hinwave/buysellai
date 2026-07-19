import SwiftUI

struct MarketplacePickerSheet: View {
    let context: MarketplacePickerContext

    @Environment(AppStore.self) private var appStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var estimates: [MarketplaceEstimate] = []
    @State private var didCompute = false

    var body: some View {
        NavigationStack {
            List {
                if let best = estimates.first(where: { $0.badge == .best }),
                   let lowest = estimates.first(where: { $0.badge == .lowest }) {
                    Section {
                        summaryActions(best: best, lowest: lowest)
                    }
                    .accessibilitySortPriority(3)
                }

                Section("Marketplace choices".localized) {
                    marketplaceContent
                }
                .accessibilitySortPriority(2)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, Spacing.xxxl, for: .scrollContent)
            .navigationTitle("Pick where to sell".localized)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.clear)
        }
        .background(Color.clear)
        .task {
            guard didCompute == false else { return }
            try? await Task.sleep(nanoseconds: 180_000_000)
            estimates = MarketplaceEstimator.estimates(for: context.item.priceEstimate)
            didCompute = true
        }
    }

    @ViewBuilder
    private var marketplaceContent: some View {
        if didCompute {
            if estimates.isEmpty {
                fallbackRows
            } else {
                estimateRows
            }
        } else {
            skeletonRows
        }
    }

    private var estimateRows: some View {
        ForEach(estimates) { estimate in
            MarketplaceRow(estimate: estimate) {
                appStore.presentListing(
                    item: context.item,
                    imageData: context.imageData,
                    marketplace: estimate.id
                )
            }
        }
    }

    @ViewBuilder
    private func summaryActions(best: MarketplaceEstimate, lowest: MarketplaceEstimate) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Spacing.sm) {
                summaryButton(label: "Best", estimate: best)
                summaryButton(label: "Lowest", estimate: lowest)
            }
        } else {
            HStack(spacing: Spacing.sm) {
                summaryButton(label: "Best", estimate: best)
                summaryButton(label: "Lowest", estimate: lowest)
            }
        }
    }

    private func summaryButton(label: String, estimate: MarketplaceEstimate) -> some View {
        SummaryButton(label: label, estimate: estimate) {
            appStore.presentListing(item: context.item, imageData: context.imageData, marketplace: estimate.id)
        }
    }

    private var skeletonRows: some View {
        VStack(spacing: Spacing.lg) {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: Spacing.md) {
                    SkeletonLine(height: 44, width: 44)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        SkeletonLine(width: 150)
                        SkeletonLine(height: 12, width: 220)
                    }
                    Spacer()
                    SkeletonLine(height: 56, width: 56)
                }
            }
        }
        .padding(.vertical, Spacing.sm)
        .accessibilityLabel("Computing marketplace payouts".localized)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilitySortPriority(2)
    }

    @ViewBuilder
    private var fallbackRows: some View {
        Text("Couldn't compute prices. Tap a marketplace anyway to draft a listing.".localized)
            .brandFont(.caption)
            .foregroundStyle(Color.brand.mutedForeground)
            .padding(.vertical, Spacing.sm)
            .accessibilitySortPriority(2)

        ForEach(Marketplace.allCases) { marketplace in
            MarketplaceFallbackRow(marketplace: marketplace) {
                appStore.presentListing(item: context.item, imageData: context.imageData, marketplace: marketplace)
            }
        }
    }
}

private struct SummaryButton: View {
    let label: String
    let estimate: MarketplaceEstimate
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button {
            MarketplaceSelectionFeedback.perform(action)
        } label: {
            HStack(alignment: .center, spacing: Spacing.sm) {
                MarketplaceIcon(marketplace: estimate.id, size: 34)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(label.localized)
                        .brandFont(.caption)
                        .foregroundStyle(label == "Best" ? Color.brand.success : Color.brand.mutedForeground)
                        .lineLimit(1)
                    Text(estimate.id.displayName)
                        .brandFont(.bodyLg)
                        .foregroundStyle(Color.brand.foreground)
                        .lineLimit(summaryLineLimit)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: Spacing.sm)

                Text(estimate.payout.currency())
                    .brandFont(.bodyLg)
                    .foregroundStyle(Color.brand.foreground)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(label == "Best" ? Color.brand.success : Color.brand.primary)
        .accessibilityLabel(MarketplaceAccessibilityText.summaryLabel(label, for: estimate))
        .accessibilityIdentifier("MarketplaceSummary.\(label.lowercased()).\(estimate.id.rawValue)")
        .accessibilitySortPriority(label == "Best" ? 2 : 1)
    }

    private var summaryLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 2 : 1
    }
}
