import SwiftUI

struct MarketplaceIcon: View {
    let marketplace: Marketplace
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            .fill(marketplace.brandTint.opacity(0.14))
            .frame(width: size, height: size)
            .overlay {
                Text(marketplace.shortMark)
                    .brandFont(.caption)
                    .foregroundStyle(marketplace.brandTint)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
            }
            .accessibilityHidden(true)
    }
}

struct MarketplaceRow: View {
    let estimate: MarketplaceEstimate
    let action: () -> Void

    var body: some View {
        Button {
            MarketplaceSelectionFeedback.perform {
                action()
            }
        } label: {
            HStack(spacing: Spacing.md) {
                MarketplaceIcon(marketplace: estimate.id)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(estimate.id.displayName)
                        .brandFont(.bodyLg)
                        .foregroundStyle(Color.brand.foreground)
                        .lineLimit(1)

                    Text(estimate.id.blurb.localized)
                        .brandFont(.caption)
                        .foregroundStyle(Color.brand.mutedForeground)
                        .lineLimit(2)
                }

                Spacer(minLength: Spacing.sm)

                VStack(spacing: 2) {
                    Text(estimate.payout.currency())
                        .brandFont(.caption)
                        .foregroundStyle(Color.brand.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(width: 56, height: 56)
                        .background(Circle().stroke(Color.brand.primary, lineWidth: 1.5))

                    Text(deltaText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(estimate.deltaPct >= 0 ? Color.brand.success : Color.brand.destructive)
                        .lineLimit(1)
                }
            }
            .frame(minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("MarketplaceRow.\(estimate.id.rawValue)")
        .accessibilitySortPriority(1)
    }

    private var deltaText: String {
        let rounded = Int(estimate.deltaPct.rounded())
        return rounded >= 0 ? "+\(rounded)%" : "\(rounded)%"
    }

    private var accessibilityLabel: String {
        MarketplaceAccessibilityText.estimateLabel(for: estimate)
    }
}

enum MarketplaceAccessibilityText {
    static func estimateLabel(for estimate: MarketplaceEstimate) -> String {
        let dollars = Int(estimate.payout.doubleValue.rounded())
        let delta = Int(estimate.deltaPct.rounded())
        guard delta != 0 else {
            return String.localizedFormat("%@, estimated payout %d dollars, average payout", estimate.id.displayName, dollars)
        }
        let direction = (delta > 0 ? "above" : "below").localized
        return String.localizedFormat("%@, estimated payout %d dollars, %d percent %@ average", estimate.id.displayName, dollars, abs(delta), direction)
    }

    static func summaryLabel(_ label: String, for estimate: MarketplaceEstimate) -> String {
        String.localizedFormat("%@, %@", label.localized, estimateLabel(for: estimate))
    }
}
