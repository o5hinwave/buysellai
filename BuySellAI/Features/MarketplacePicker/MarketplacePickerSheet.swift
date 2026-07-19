import SwiftUI

struct MarketplacePickerSheet: View {
    let context: MarketplacePickerContext

    @Environment(AppStore.self) private var appStore
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var estimates: [MarketplaceEstimate] = []
    @State private var didCompute = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    if didCompute {
                        if estimates.isEmpty {
                            fallbackRows
                        } else {
                            ForEach(estimates) { estimate in
                                MarketplaceRow(estimate: estimate) {
                                    appStore.presentListing(
                                        item: context.item,
                                        imageData: context.imageData,
                                        marketplace: estimate.id
                                    )
                                }
                                .padding(.horizontal, Spacing.xl)
                                Divider()
                                    .padding(.leading, 88)
                                    .foregroundStyle(Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor))
                            }
                        }
                    } else {
                        skeletonRows
                    }
                } header: {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Pick where to sell".localized)
                            .brandFont(.titleLg)
                            .foregroundStyle(Color.brand.foreground)

                        if let best = estimates.first(where: { $0.badge == .best }),
                           let lowest = estimates.first(where: { $0.badge == .lowest }) {
                            summaryActions(best: best, lowest: lowest)
                        }
                    }
                    .padding(Spacing.xl)
                    .nativeMaterialBar(tintOpacity: 0.78, showsTopDivider: false, showsBottomDivider: true)
                    .accessibilitySortPriority(3)
                }
            }
        }
        .contentMargins(.bottom, Spacing.xxxl, for: .scrollContent)
        .padding(.bottom, Spacing.xxl)
        .background(Color.clear)
        .task {
            guard didCompute == false else { return }
            try? await Task.sleep(nanoseconds: 180_000_000)
            estimates = MarketplaceEstimator.estimates(for: context.item.priceEstimate)
            didCompute = true
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
                .padding(.horizontal, Spacing.xl)
            }
        }
        .padding(.top, Spacing.md)
        .accessibilityLabel("Computing marketplace payouts".localized)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilitySortPriority(2)
    }

    private var fallbackRows: some View {
        VStack(spacing: 0) {
            Text("Couldn't compute prices. Tap a marketplace anyway to draft a listing.".localized)
                .brandFont(.caption)
                .foregroundStyle(Color.brand.mutedForeground)
                .padding(Spacing.xl)
                .accessibilitySortPriority(2)

            ForEach(Marketplace.allCases) { marketplace in
                MarketplaceFallbackRow(marketplace: marketplace) {
                    appStore.presentListing(item: context.item, imageData: context.imageData, marketplace: marketplace)
                }
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
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(label.localized)
                    .brandFont(.overline)
                    .tracking(0.88)
                    .foregroundStyle(label == "Best" ? Color.brand.success : Color.brand.mutedForeground)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 5)
                    .background {
                        NativeMaterialRoundedBackground(
                            cornerRadius: Radius.pill,
                            tint: label == "Best" ? Color.brand.success : Color.brand.surface,
                            tintOpacity: label == "Best" ? 0.14 : 0.7,
                            strokeOpacity: 0.48
                        )
                    }

                HStack(spacing: Spacing.xs) {
                    MarketplaceIcon(marketplace: estimate.id, size: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(estimate.id.displayName)
                            .brandFont(.caption)
                            .foregroundStyle(Color.brand.foreground)
                            .lineLimit(summaryLineLimit)
                            .minimumScaleFactor(0.82)
                        Text(estimate.payout.currency())
                            .brandFont(.bodyLg)
                            .foregroundStyle(Color.brand.foreground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .nativeMaterialPanel(cornerRadius: Radius.lg, tintOpacity: 0.72)
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(MarketplaceAccessibilityText.summaryLabel(label, for: estimate))
        .accessibilityIdentifier("MarketplaceSummary.\(label.lowercased()).\(estimate.id.rawValue)")
        .accessibilitySortPriority(label == "Best" ? 2 : 1)
    }

    private var summaryLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 2 : 1
    }
}
