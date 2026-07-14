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
                    .font(.brandCaption)
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
        Button(action: {
            Haptics.impact(.light)
            action()
        }) {
            HStack(spacing: Spacing.md) {
                MarketplaceIcon(marketplace: estimate.id)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(estimate.id.displayName)
                        .font(.brandBodyLg)
                        .foregroundStyle(Color.brand.foreground)
                        .lineLimit(1)

                    Text(estimate.id.blurb)
                        .font(.brandCaption)
                        .foregroundStyle(Color.brand.mutedForeground)
                        .lineLimit(2)
                }

                Spacer(minLength: Spacing.sm)

                VStack(spacing: 2) {
                    Text(estimate.payout.currency())
                        .font(.brandCaption)
                        .foregroundStyle(Color.brand.primary)
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
        .accessibilitySortPriority(1)
    }

    private var deltaText: String {
        let rounded = Int(estimate.deltaPct.rounded())
        return rounded >= 0 ? "+\(rounded)%" : "\(rounded)%"
    }

    private var accessibilityLabel: String {
        let dollars = Int(estimate.payout.doubleValue.rounded())
        let delta = Int(estimate.deltaPct.rounded())
        let direction = delta >= 0 ? "above" : "below"
        return "\(estimate.id.displayName), estimated payout \(dollars) dollars, \(abs(delta)) percent \(direction) average"
    }
}
