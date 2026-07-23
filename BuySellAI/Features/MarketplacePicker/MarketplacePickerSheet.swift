import SwiftUI

struct MarketplacePickerSheet: View {
    let context: MarketplacePickerContext

    @Environment(AppStore.self) private var appStore
    @State private var computedEstimates: [MarketplaceEstimate]?

    var body: some View {
        NavigationStack {
            List {
                if let estimates = computedEstimates, estimates.isEmpty == false {
                    Section("Top picks".localized) {
                        summaryActions(estimates: Array(estimates.prefix(3)))
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
            guard computedEstimates == nil else { return }
            try? await Task.sleep(nanoseconds: 180_000_000)
            computedEstimates = MarketplaceEstimator.estimates(for: context.item)
        }
    }

    @ViewBuilder
    private var marketplaceContent: some View {
        if let computedEstimates {
            if computedEstimates.isEmpty {
                fallbackRows
            } else {
                estimateRows(computedEstimates)
            }
        } else {
            skeletonRows
        }
    }

    private func estimateRows(_ estimates: [MarketplaceEstimate]) -> some View {
        ForEach(estimates) { estimate in
            MarketplaceRow(estimate: estimate, item: context.item) {
                appStore.presentListing(
                    item: context.item,
                    imageData: context.imageData,
                    marketplace: estimate.id
                )
            }
        }
    }

    private func summaryActions(estimates: [MarketplaceEstimate]) -> some View {
        ForEach(Array(estimates.enumerated()), id: \.element.id) { index, estimate in
            summaryButton(label: summaryLabel(for: index), estimate: estimate)
        }
    }

    private func summaryButton(label: String, estimate: MarketplaceEstimate) -> some View {
        SummaryButton(label: label, estimate: estimate, item: context.item) {
            appStore.presentListing(item: context.item, imageData: context.imageData, marketplace: estimate.id)
        }
    }

    private func summaryLabel(for index: Int) -> String {
        switch index {
        case 0:
            "Best"
        case 1:
            "Second"
        default:
            "Third"
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
            .font(.caption)
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
    let item: DetectedItem
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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(label == "Best" ? Color.brand.success : Color.brand.mutedForeground)
                        .lineLimit(1)
                    Text(estimate.id.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.brand.foreground)
                        .lineLimit(summaryLineLimit)
                        .minimumScaleFactor(0.82)
                    Text(estimate.id.recommendationReason(for: item))
                        .font(.caption)
                        .foregroundStyle(Color.brand.mutedForeground)
                        .lineLimit(reasonLineLimit)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: Spacing.sm)

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text(estimate.payout.currency())
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.brand.foreground)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Image(systemName: "chevron.right")
                        .brandSymbol(.chevron)
                        .foregroundStyle(Color.brand.mutedForeground)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 110 : 78)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(MarketplaceAccessibilityText.summaryLabel(label, for: estimate, item: item))
        .accessibilityIdentifier("MarketplaceSummary.\(label.lowercased()).\(estimate.id.rawValue)")
        .accessibilitySortPriority(label == "Best" ? 2 : 1)
    }

    private var summaryLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 2 : 1
    }

    private var reasonLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 4 : 2
    }
}
