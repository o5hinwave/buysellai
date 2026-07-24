import SwiftUI

struct MarketplacePickerSheet: View {
    let context: MarketplacePickerContext

    @Environment(AppStore.self) private var appStore
    @State private var computedEstimates: [MarketplaceEstimate]?

    var body: some View {
        NavigationStack {
            List {
                if let estimates = computedEstimates, estimates.isEmpty == false {
                    recommendationSections(picks: MarketplaceSummaryPlanner.picks(from: estimates))
                }

                Section("All places".localized) {
                    marketplaceContent
                }
                .accessibilitySortPriority(2)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, Spacing.xxxl, for: .scrollContent)
            .navigationTitle("Best place to sell".localized)
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.clear)
        }
        .background(Color.clear)
        .task {
            guard computedEstimates == nil else { return }
            try? await Task.sleep(nanoseconds: 180_000_000)
            computedEstimates = MarketplaceEstimator.estimates(for: context.item, details: context.details)
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
                    marketplace: estimate.id,
                    details: context.details
                )
            }
        }
    }

    private func summaryActions(picks: [MarketplaceSummaryPick]) -> some View {
        ForEach(picks) { pick in
            summaryButton(pick: pick, isRecommended: false)
        }
    }

    @ViewBuilder
    private func recommendationSections(picks: [MarketplaceSummaryPick]) -> some View {
        if let recommendedPick = picks.first {
            Section("Best place to sell".localized) {
                recommendedButton(pick: recommendedPick)
            }
            .accessibilitySortPriority(3)
        }

        let otherPicks = Array(picks.dropFirst())
        if otherPicks.isEmpty == false {
            Section("Compare".localized) {
                summaryActions(picks: otherPicks)
            }
            .accessibilitySortPriority(2.5)
        }
    }

    private func summaryButton(pick: MarketplaceSummaryPick, isRecommended: Bool) -> some View {
        SummaryButton(pick: pick, item: context.item, isRecommended: isRecommended) {
            appStore.presentListing(item: context.item, imageData: context.imageData, marketplace: pick.estimate.id, details: context.details)
        }
    }

    private func recommendedButton(pick: MarketplaceSummaryPick) -> some View {
        RecommendedMarketplaceButton(pick: pick, item: context.item) {
            appStore.presentListing(item: context.item, imageData: context.imageData, marketplace: pick.estimate.id, details: context.details)
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
        .accessibilityLabel("Checking places to sell".localized)
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

        ForEach(Marketplace.activeRecommendationCases) { marketplace in
            MarketplaceFallbackRow(marketplace: marketplace) {
                appStore.presentListing(item: context.item, imageData: context.imageData, marketplace: marketplace, details: context.details)
            }
        }
    }
}

private struct RecommendedMarketplaceButton: View {
    let pick: MarketplaceSummaryPick
    let item: DetectedItem
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button {
            MarketplaceSelectionFeedback.perform(action)
        } label: {
            content
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(MarketplaceAccessibilityText.summaryLabel("Best chance", for: pick.estimate, item: item))
        .accessibilityIdentifier("MarketplaceSummary.\(pick.kind.rawValue).\(pick.estimate.id.rawValue)")
        .accessibilitySortPriority(2)
    }

    @ViewBuilder
    private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    MarketplaceIcon(marketplace: pick.estimate.id, size: 48)
                    titleCopy
                    Spacer(minLength: 0)
                    chevron
                }

                reasonCopy

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    chanceLabel
                    takeHome(alignment: .leading)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    MarketplaceIcon(marketplace: pick.estimate.id, size: 48)
                    titleCopy
                    Spacer(minLength: Spacing.sm)
                    takeHome(alignment: .trailing)
                    chevron
                }

                reasonCopy
                chanceLabel
            }
        }
    }

    private var titleCopy: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("We found the best place to sell this".localized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.success)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(pick.estimate.id.displayName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .minimumScaleFactor(0.82)
        }
    }

    private var reasonCopy: some View {
        Text(pick.estimate.id.recommendationReason(for: item))
            .font(.callout)
            .foregroundStyle(Color.brand.foregroundSecondary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
            .multilineTextAlignment(.leading)
    }

    private var chanceLabel: some View {
        Label(pick.kind.label.localized, systemImage: "checkmark.seal")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.brand.success)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .brandSymbol(.chevron)
            .foregroundStyle(Color.brand.mutedForeground)
            .accessibilityHidden(true)
    }

    private func takeHome(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Spacing.xxs) {
            Text("Take-home".localized)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.brand.mutedForeground)
                .lineLimit(1)

            Text(pick.estimate.payout.currency())
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}

private struct SummaryButton: View {
    let pick: MarketplaceSummaryPick
    let item: DetectedItem
    let isRecommended: Bool
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button {
            MarketplaceSelectionFeedback.perform(action)
        } label: {
            HStack(alignment: .center, spacing: Spacing.sm) {
                MarketplaceIcon(marketplace: pick.estimate.id, size: 34)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(pick.kind.label.localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isRecommended ? Color.brand.success : Color.brand.mutedForeground)
                        .lineLimit(1)
                    Text(pick.estimate.id.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.brand.foreground)
                        .lineLimit(summaryLineLimit)
                        .minimumScaleFactor(0.82)

                    if let fitSummary = pick.estimate.fitSummary {
                        Text(fitSummary.localized)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isRecommended ? Color.brand.success : Color.brand.mutedForeground)
                            .lineLimit(1)
                    }

                    Text(pick.estimate.id.recommendationReason(for: item))
                        .font(.caption)
                        .foregroundStyle(Color.brand.mutedForeground)
                        .lineLimit(reasonLineLimit)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: Spacing.sm)

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text("Take-home".localized)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.brand.mutedForeground)
                        .lineLimit(1)

                    Text(pick.estimate.payout.currency())
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
        .accessibilityLabel(MarketplaceAccessibilityText.summaryLabel(pick.kind.label, for: pick.estimate, item: item))
        .accessibilityIdentifier("MarketplaceSummary.\(pick.kind.rawValue).\(pick.estimate.id.rawValue)")
        .accessibilitySortPriority(isRecommended ? 2 : 1)
    }

    private var summaryLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 2 : 1
    }

    private var reasonLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 4 : 2
    }
}
