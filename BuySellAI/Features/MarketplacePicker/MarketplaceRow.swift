import SwiftUI

enum MarketplaceRowLayout {
    static let iconSize: CGFloat = 44
    static let payoutCircleSize: CGFloat = 56
    static let accessibilityPayoutCircleSize: CGFloat = 64
    static let payoutStackWidth: CGFloat = 66
    static let deltaReservedHeight: CGFloat = 14
    static let rowMinHeight: CGFloat = 104
    static let accessibilityRowMinHeight: CGFloat = 148
    static let fallbackRowMinHeight: CGFloat = 72
    static let fallbackAccessibilityRowMinHeight: CGFloat = 112
}

struct MarketplaceComparisonSignals: Sendable, Hashable {
    let listPrice: String
    let speed: String
    let fulfillment: String

    var rowLine: String {
        String.localizedFormat("%@ · %@ · %@", listPrice, speed, fulfillment)
    }

    var summaryLine: String {
        String.localizedFormat("%@ · %@", speed, fulfillment)
    }

    var accessibilitySummary: String {
        String.localizedFormat("%@, %@, %@", listPrice, speed, fulfillment)
    }
}

struct MarketplaceIcon: View {
    let marketplace: Marketplace
    var size: CGFloat = MarketplaceRowLayout.iconSize

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .fill(marketplace.brandTint.opacity(0.14))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: marketplace.iconSystemName)
                    .brandSymbol(.controlIcon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(marketplace.brandTint)
                    .frame(width: size * 0.72, height: size * 0.72)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(marketplace.brandTint.opacity(0.22), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

struct MarketplaceRow: View {
    let estimate: MarketplaceEstimate
    let item: DetectedItem
    var comparison: MarketplaceComparison?
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button {
            MarketplaceSelectionFeedback.perform {
                action()
            }
        } label: {
            rowContent
                .padding(.vertical, Spacing.sm)
                .frame(minHeight: rowMinHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("MarketplaceRow.\(estimate.id.rawValue)")
        .accessibilitySortPriority(1)
    }

    @ViewBuilder
    private var rowContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityRowContent
        } else {
            regularRowContent
        }
    }

    private var regularRowContent: some View {
        HStack(spacing: Spacing.md) {
            MarketplaceIcon(marketplace: estimate.id)

            marketplaceCopy(nameLineLimit: 1, blurbLineLimit: 2, fitLineLimit: 1)

            Spacer(minLength: Spacing.sm)

            VStack(spacing: Spacing.xxs) {
                payoutCircle(size: MarketplaceRowLayout.payoutCircleSize)
                regularDeltaLabel
            }
            .frame(width: MarketplaceRowLayout.payoutStackWidth)
        }
    }

    private var accessibilityRowContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.md) {
                MarketplaceIcon(marketplace: estimate.id)
                marketplaceCopy(nameLineLimit: 2, blurbLineLimit: 3, fitLineLimit: 2)
                Spacer(minLength: 0)
            }

            HStack(alignment: .center, spacing: Spacing.sm) {
                payoutCircle(size: MarketplaceRowLayout.accessibilityPayoutCircleSize)
                accessibilityDeltaLabel
                Spacer(minLength: 0)
            }
            .padding(.leading, MarketplaceRowLayout.iconSize + Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func marketplaceCopy(nameLineLimit: Int, blurbLineLimit: Int, fitLineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(estimate.id.displayName)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
                .lineLimit(nameLineLimit)
                .multilineTextAlignment(.leading)

            Text(estimate.id.blurb.localized)
                .font(.caption)
                .foregroundStyle(Color.brand.mutedForeground)
                .lineLimit(blurbLineLimit)
                .multilineTextAlignment(.leading)

            Text(comparison?.rowSignal(currencyCode: item.currencyCode) ?? estimate.comparisonSignals(for: item).rowLine)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.brand.foregroundSecondary)
                .lineLimit(fitLineLimit)
                .multilineTextAlignment(.leading)

            if let fitSummary = estimate.fitSummary {
                Text(fitSummary.localized)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(fitColor)
                    .lineLimit(fitLineLimit)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private func payoutCircle(size: CGFloat) -> some View {
        Text(estimate.payout.currency())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.brand.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: size, height: size)
            .background(Circle().stroke(Color.brand.primary, lineWidth: 1.5))
    }

    private var regularDeltaLabel: some View {
        deltaLabel
            .frame(height: MarketplaceRowLayout.deltaReservedHeight)
    }

    private var accessibilityDeltaLabel: some View {
        deltaLabel
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: 44)
            .background {
                NativeMaterialRoundedBackground(
                    cornerRadius: Radius.pill,
                    tintOpacity: 0.7,
                    strokeOpacity: 0.54
                )
            }
    }

    private var deltaLabel: some View {
        Text(deltaText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(estimate.deltaPct >= 0 ? Color.brand.success : Color.brand.destructive)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
    }

    private var rowMinHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? MarketplaceRowLayout.accessibilityRowMinHeight : MarketplaceRowLayout.rowMinHeight
    }

    private var deltaText: String {
        let rounded = Int(estimate.deltaPct.rounded())
        return rounded >= 0 ? "+\(rounded)%" : "\(rounded)%"
    }

    private var fitColor: Color {
        estimate.fitScore >= 82 ? Color.brand.success : Color.brand.mutedForeground
    }

    private var accessibilityLabel: String {
        MarketplaceAccessibilityText.estimateLabel(for: estimate, item: item)
    }
}

struct MarketplaceFallbackRow: View {
    let marketplace: Marketplace
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button {
            MarketplaceSelectionFeedback.perform {
                action()
            }
        } label: {
            rowContent
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.sm)
                .frame(minHeight: rowMinHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Drafts a listing without a payout estimate".localized)
        .accessibilityIdentifier("MarketplaceRow.\(marketplace.rawValue)")
        .accessibilitySortPriority(1)
    }

    @ViewBuilder
    private var rowContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityRowContent
        } else {
            regularRowContent
        }
    }

    private var regularRowContent: some View {
        HStack(spacing: Spacing.md) {
            MarketplaceIcon(marketplace: marketplace)
            marketplaceCopy(nameLineLimit: 1, blurbLineLimit: 2)
            Spacer(minLength: Spacing.sm)
            chevron
        }
    }

    private var accessibilityRowContent: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            MarketplaceIcon(marketplace: marketplace)
            marketplaceCopy(nameLineLimit: 2, blurbLineLimit: 3)
                .padding(.trailing, Spacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottomTrailing) {
            chevron
        }
    }

    private func marketplaceCopy(nameLineLimit: Int, blurbLineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(marketplace.displayName)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.brand.foreground)
                .lineLimit(nameLineLimit)
                .multilineTextAlignment(.leading)

            Text(marketplace.blurb.localized)
                .font(.caption)
                .foregroundStyle(Color.brand.mutedForeground)
                .lineLimit(blurbLineLimit)
                .multilineTextAlignment(.leading)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .brandSymbol(.chevron)
            .foregroundStyle(Color.brand.mutedForeground)
            .accessibilityHidden(true)
    }

    private var rowMinHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? MarketplaceRowLayout.fallbackAccessibilityRowMinHeight : MarketplaceRowLayout.fallbackRowMinHeight
    }

    private var accessibilityLabel: String {
        String.localizedFormat("%@, %@", marketplace.displayName, marketplace.blurb.localized)
    }
}

enum MarketplaceAccessibilityText {
    static func estimateLabel(for estimate: MarketplaceEstimate, item: DetectedItem? = nil) -> String {
        let dollars = Int(estimate.payout.doubleValue.rounded())
        let delta = Int(estimate.deltaPct.rounded())
        let nameAndFit = nameAndFitLabel(for: estimate)
        let baseLabel: String
        guard delta != 0 else {
            baseLabel = String.localizedFormat("%@, estimated payout %d dollars, average payout", nameAndFit, dollars)
            return labelWithReason(baseLabel, estimate: estimate, item: item)
        }
        let direction = (delta > 0 ? "above" : "below").localized
        baseLabel = String.localizedFormat("%@, estimated payout %d dollars, %d percent %@ average", nameAndFit, dollars, abs(delta), direction)
        return labelWithReason(baseLabel, estimate: estimate, item: item)
    }

    static func summaryLabel(_ label: String, for estimate: MarketplaceEstimate, item: DetectedItem? = nil) -> String {
        String.localizedFormat("%@, %@", label.localized, estimateLabel(for: estimate, item: item))
    }

    private static func labelWithReason(_ label: String, estimate: MarketplaceEstimate, item: DetectedItem?) -> String {
        guard let item else {
            return label
        }
        return String.localizedFormat(
            "%@, %@, %@",
            label,
            estimate.comparisonSignals(for: item).accessibilitySummary,
            estimate.id.recommendationReason(for: item)
        )
    }

    private static func nameAndFitLabel(for estimate: MarketplaceEstimate) -> String {
        guard let fitSummary = estimate.fitSummary else {
            return estimate.id.displayName
        }
        return String.localizedFormat("%@, %@", estimate.id.displayName, fitSummary.localized.lowercased())
    }
}

extension MarketplaceEstimate {
    func comparisonSignals(for item: DetectedItem) -> MarketplaceComparisonSignals {
        let profile = id.optimizationProfile
        return MarketplaceComparisonSignals(
            listPrice: String.localizedFormat("List around %@", item.priceEstimate.currency(code: item.currencyCode)),
            speed: speedCue(score: profile.speedScore),
            fulfillment: fulfillmentCue(for: item, profile: profile)
        )
    }

    private func speedCue(score: Int) -> String {
        switch score {
        case 80...100:
            "Fast sale".localized
        case 58..<80:
            "Steady sale".localized
        default:
            "Slower sale".localized
        }
    }

    private func fulfillmentCue(for item: DetectedItem, profile: MarketplaceOptimizationProfile) -> String {
        let localFit = profile.localPickupFit(for: item)
        let shippingFit = profile.shippingFit(for: item)

        if item.localPickupNeedScore >= 72, localFit >= shippingFit {
            return "Local pickup".localized
        }
        if shippingFit >= 76 {
            return "Easy shipping".localized
        }
        if shippingFit <= 48 {
            return "Pack carefully".localized
        }
        return "Shipping okay".localized
    }
}
