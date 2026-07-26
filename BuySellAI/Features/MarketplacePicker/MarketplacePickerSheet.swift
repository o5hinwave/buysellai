import SwiftUI

struct MarketplacePickerSheet: View {
    let context: MarketplacePickerContext

    @Environment(AppStore.self) private var appStore
    @State private var computedEstimates: [MarketplaceEstimate]?
    @State private var marketplaceComparisons: [Marketplace: MarketplaceComparison] = [:]
    @State private var marketCheckMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if computedEstimates == nil {
                    Section {
                        marketResearchLoadingCard
                    }
                    .accessibilitySortPriority(3)
                }

                if let estimates = computedEstimates, estimates.isEmpty == false {
                    recommendationSections(picks: MarketplaceSummaryPlanner.picks(
                        from: estimates,
                        item: context.item,
                        details: context.details,
                        comparisons: marketplaceComparisons
                    ))
                }

                if let marketCheckMessage {
                    Section {
                        marketCheckNotice(marketCheckMessage)
                    }
                    .accessibilitySortPriority(2.8)
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
            await loadMarketplaceCheck()
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
            MarketplaceRow(
                estimate: estimate,
                item: context.item,
                comparison: displayComparison(for: estimate.id)
            ) {
                chooseMarketplace(estimate.id)
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
        SummaryButton(
            pick: pick,
            item: context.item,
            comparison: displayComparison(for: pick.estimate.id),
            isRecommended: isRecommended
        ) {
            chooseMarketplace(pick.estimate.id)
        }
    }

    private func recommendedButton(pick: MarketplaceSummaryPick) -> some View {
        RecommendedMarketplaceButton(
            pick: pick,
            item: context.item,
            comparison: displayComparison(for: pick.estimate.id)
        ) {
            chooseMarketplace(pick.estimate.id)
        }
    }

    private func marketCheckNotice(_ message: String) -> some View {
        Label(message.localized, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(Color.brand.mutedForeground)
            .padding(.vertical, Spacing.xxs)
        .accessibilityLabel(message.localized)
    }

    private var marketResearchLoadingCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Checking where this should sell".localized)
                        .font(.headline)
                        .foregroundStyle(Color.brand.foreground)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("BuySell is comparing real market signals before picking a place.".localized)
                        .font(.callout)
                        .foregroundStyle(Color.brand.foregroundSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                ProgressView()
                    .controlSize(.regular)
                    .tint(Color.brand.primary)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                marketResearchStepRow(
                    title: "Sold prices",
                    detail: "Looks for recent comparable sales.",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                marketResearchStepRow(
                    title: "Fees",
                    detail: "Checks what you may keep after selling costs.",
                    systemImage: "percent"
                )
                marketResearchStepRow(
                    title: "Best fit",
                    detail: "Compares speed, shipping, pickup, and buyer demand.",
                    systemImage: "checkmark.seal.fill"
                )
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Marketplace.ResearchLoadingCard")
    }

    private func marketResearchStepRow(title: String, detail: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title.localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                Text(detail.localized)
                    .font(.caption)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
                .brandSymbol(.controlIcon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.brand.primaryText)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
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
                chooseMarketplace(marketplace)
            }
        }
    }

    private func chooseMarketplace(_ marketplace: Marketplace) {
        ProductAnalytics.record(
            .marketplaceSelected,
            properties: [
                "marketplace": marketplace.rawValue,
                "category": context.item.category.rawValue,
                "has_grounded_comparison": displayComparison(for: marketplace) == nil ? "false" : "true"
            ]
        )
        appStore.presentItemQuestions(
            item: context.item,
            imageData: context.imageData,
            supplementalPhotos: context.supplementalPhotos,
            preferredMarketplace: marketplace,
            marketplaceComparison: displayComparison(for: marketplace),
            analysis: context.analysis,
            answers: context.details
        )
    }

    private func displayComparison(for marketplace: Marketplace) -> MarketplaceComparison? {
        guard let comparison = marketplaceComparisons[marketplace],
              comparison.evidenceStatus != .unavailable
        else {
            return nil
        }
        return comparison
    }

    private func loadMarketplaceCheck() async {
        let localEstimates = MarketplaceEstimator.estimates(for: context.item, details: context.details)
        let candidates = Array(localEstimates.prefix(10).map(\.id))

        do {
            let response = try await APIClient.shared.compareMarketplaces(
                item: context.item,
                details: context.details,
                candidateMarketplaces: candidates,
                identificationProfile: context.analysis?.identificationProfile,
                accessToken: await appStore.authenticatedAccessToken()
            )
            appStore.updateEntitlementSnapshot(response.entitlement)
            let comparisons = response.comparisonByMarketplace
            marketplaceComparisons = comparisons
            computedEstimates = MarketplaceEstimator.estimates(
                for: context.item,
                details: context.details,
                comparisons: comparisons
            )
            if comparisons.values.allSatisfy({ $0.evidenceStatus == .unavailable }) {
                marketCheckMessage = "Current market check unavailable. Showing quick estimates."
            }
        } catch {
            ProductAnalytics.recordFailure(
                .groundedResearchFailed,
                endpoint: "compare-marketplaces",
                error: error,
                extra: [
                    "category": context.item.category.rawValue,
                    "candidate_count": "\(candidates.count)"
                ]
            )
            marketCheckMessage = "Current market check unavailable. Showing quick estimates."
            computedEstimates = localEstimates
        }
    }
}

private struct RecommendedMarketplaceButton: View {
    let pick: MarketplaceSummaryPick
    let item: DetectedItem
    let comparison: MarketplaceComparison?
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
        .accessibilityLabel(MarketplaceAccessibilityText.summaryLabel(pick.kind.label, for: pick.estimate, item: item, comparison: comparison))
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
                comparisonCue
                decisionEvidenceStrip

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    recommendationKindLabel
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
                comparisonCue
                decisionEvidenceStrip
                recommendationKindLabel
            }
        }
    }

    private var titleCopy: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(primaryDecisionTitle.localized)
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

    private var primaryDecisionTitle: String {
        switch pick.kind {
        case .bestOverall:
            "Best overall"
        case .fastestSale:
            "Fastest sale"
        case .mostMoney:
            "Most money"
        case .easiestOption:
            "Easiest option"
        }
    }

    private var reasonCopy: some View {
        Text((comparison?.reason ?? pick.estimate.id.recommendationReason(for: item)).localized)
            .font(.callout)
            .foregroundStyle(Color.brand.foregroundSecondary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
            .multilineTextAlignment(.leading)
    }

    private var comparisonCue: some View {
        Text(comparison?.verifiedRowSignal(currencyCode: item.currencyCode) ?? pick.estimate.comparisonSignals(for: item).summaryLine)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.brand.foregroundSecondary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
            .multilineTextAlignment(.leading)
    }

    private var decisionEvidenceStrip: some View {
        MarketplaceDecisionEvidenceStrip(
            estimate: pick.estimate,
            comparison: comparison,
            currencyCode: item.currencyCode
        )
    }

    private var recommendationKindLabel: some View {
        Label((comparison?.recommendationLabel ?? pick.kind.label).localized, systemImage: pick.kind.systemImage)
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

private struct MarketplaceDecisionEvidenceStrip: View {
    let estimate: MarketplaceEstimate
    let comparison: MarketplaceComparison?
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Why this pick".localized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.mutedForeground)

            LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.xs) {
                ForEach(decisionFacts) { fact in
                    marketplaceDecisionFact(fact)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(decisionAccessibilityLabel)
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(minimum: 132), spacing: Spacing.xs, alignment: .leading),
            GridItem(.flexible(minimum: 132), spacing: Spacing.xs, alignment: .leading)
        ]
    }

    private var decisionFacts: [MarketplaceEvidenceFact] {
        guard let comparison else {
            return [
                MarketplaceEvidenceFact(label: "Sold", value: "Needs market check".localized),
                MarketplaceEvidenceFact(label: "You keep", value: estimate.payout.currency(code: currencyCode)),
                MarketplaceEvidenceFact(label: "Speed", value: "Quick estimate".localized),
                MarketplaceEvidenceFact(label: "Evidence", value: "Quick estimate".localized)
            ]
        }

        return [
            MarketplaceEvidenceFact(label: "Sold", value: comparison.verifiedSoldPriceSignal(currencyCode: currencyCode)),
            MarketplaceEvidenceFact(
                label: "You keep",
                value: (comparison.takeHomeEstimate ?? estimate.payout).currency(code: currencyCode)
            ),
            MarketplaceEvidenceFact(
                label: "Speed",
                value: cleanDecisionValue(comparison.expectedSpeed) ?? "Not enough speed data".localized
            ),
            evidenceStrengthFact(for: comparison)
        ]
    }

    private var decisionAccessibilityLabel: String {
        ([String(localized: "Why this pick")] + decisionFacts.map(\.line)).joined(separator: ", ")
    }

    private func marketplaceDecisionFact(_ fact: MarketplaceEvidenceFact) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Image(systemName: systemImage(for: fact.label))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand.primaryText)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(fact.label.localized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.brand.mutedForeground)
                    .lineLimit(1)

                Text(fact.value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brand.foreground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
            }
        }
    }

    private func evidenceStrengthFact(for comparison: MarketplaceComparison) -> MarketplaceEvidenceFact {
        let sourceCount = comparison.evidenceSources?.compactMap { $0.sanitizedForDisplay() }.count ?? 0
        switch comparison.evidenceStatus {
        case .grounded:
            let value = sourceCount > 0
                ? String.localizedFormat("%d source(s)", sourceCount)
                : "Grounded check".localized
            return MarketplaceEvidenceFact(label: "Evidence", value: value)
        case .limited:
            return MarketplaceEvidenceFact(label: "Evidence", value: "Limited proof".localized)
        case .unavailable:
            return MarketplaceEvidenceFact(label: "Evidence", value: "Quick estimate".localized)
        }
    }

    private func cleanDecisionValue(_ value: String?) -> String? {
        let cleanValue = value?
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard cleanValue.isEmpty == false else { return nil }
        return String(cleanValue.prefix(80))
    }

    private func systemImage(for label: String) -> String {
        switch label {
        case "Sold":
            "chart.line.uptrend.xyaxis"
        case "You keep":
            "dollarsign.circle.fill"
        case "Speed":
            "bolt.fill"
        default:
            "checkmark.shield.fill"
        }
    }
}

private struct SummaryButton: View {
    let pick: MarketplaceSummaryPick
    let item: DetectedItem
    let comparison: MarketplaceComparison?
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

                    Text(comparison?.verifiedRowSignal(currencyCode: item.currencyCode) ?? pick.estimate.comparisonSignals(for: item).summaryLine)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.brand.foregroundSecondary)
                        .lineLimit(reasonLineLimit)

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
        .accessibilityLabel(MarketplaceAccessibilityText.summaryLabel(pick.kind.label, for: pick.estimate, item: item, comparison: comparison))
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
