import SwiftUI

struct MarketplacePickerSheet: View {
    let context: MarketplacePickerContext

    @Environment(AppStore.self) private var appStore
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
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
                            HStack(spacing: Spacing.sm) {
                                SummaryButton(label: "Best", estimate: best) {
                                    appStore.presentListing(item: context.item, imageData: context.imageData, marketplace: best.id)
                                }
                                SummaryButton(label: "Lowest", estimate: lowest) {
                                    appStore.presentListing(item: context.item, imageData: context.imageData, marketplace: lowest.id)
                                }
                            }
                        }
                    }
                    .padding(Spacing.xl)
                    .background(.regularMaterial)
                    .accessibilitySortPriority(3)
                }
            }
        }
        .background(Color.brand.background)
        .task {
            guard didCompute == false else { return }
            try? await Task.sleep(nanoseconds: 180_000_000)
            estimates = MarketplaceEstimator.estimates(for: context.item.priceEstimate)
            didCompute = true
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
                Button {
                    MarketplaceSelectionFeedback.perform {
                        appStore.presentListing(item: context.item, imageData: context.imageData, marketplace: marketplace)
                    }
                } label: {
                    HStack(spacing: Spacing.md) {
                        MarketplaceIcon(marketplace: marketplace)
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(marketplace.displayName)
                                .brandFont(.bodyLg)
                                .foregroundStyle(Color.brand.foreground)
                            Text(marketplace.blurb.localized)
                                .brandFont(.caption)
                                .foregroundStyle(Color.brand.mutedForeground)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.xl)
                    .frame(minHeight: 72)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String.localizedFormat("%@, %@", marketplace.displayName, marketplace.blurb.localized))
                .accessibilitySortPriority(1)
            }
        }
    }
}

private struct SummaryButton: View {
    let label: String
    let estimate: MarketplaceEstimate
    let action: () -> Void
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

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
                    .background((label == "Best" ? Color.brand.success : Color.brand.secondary).opacity(0.14), in: Capsule())

                HStack(spacing: Spacing.xs) {
                    MarketplaceIcon(marketplace: estimate.id, size: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(estimate.id.displayName)
                            .brandFont(.caption)
                            .foregroundStyle(Color.brand.foreground)
                            .lineLimit(1)
                        Text(estimate.payout.currency())
                            .brandFont(.bodyLg)
                            .foregroundStyle(Color.brand.foreground)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(Color.brand.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(Color.brand.accessibilityBorder(differentiateWithoutColor: differentiateWithoutColor), lineWidth: 1)
            )
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(MarketplaceAccessibilityText.summaryLabel(label, for: estimate))
        .accessibilitySortPriority(label == "Best" ? 2 : 1)
    }
}
