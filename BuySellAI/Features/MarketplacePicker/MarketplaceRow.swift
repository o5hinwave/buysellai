import SwiftUI

enum MarketplaceRowLayout {
    static let iconSize: CGFloat = 44
    static let payoutCircleSize: CGFloat = 56
    static let accessibilityPayoutCircleSize: CGFloat = 64
    static let payoutStackWidth: CGFloat = 66
    static let deltaReservedHeight: CGFloat = 14
    static let rowMinHeight: CGFloat = 128
    static let accessibilityRowMinHeight: CGFloat = 196
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

struct MarketplaceEvidenceFact: Identifiable, Sendable, Hashable {
    let label: String
    let value: String

    var id: String {
        "\(label)-\(value)"
    }

    var line: String {
        String.localizedFormat("%@: %@", label.localized, value)
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
                    .symbolVariant(.fill)
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
    @Environment(\.appReduceMotion) private var reduceMotion
    @State private var isProofExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
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

            if let comparison, comparison.hasMarketplaceProofDetails(currencyCode: item.currencyCode) {
                proofDisclosure(comparison)
            }
        }
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

            Text(comparison?.verifiedRowSignal(currencyCode: item.currencyCode) ?? estimate.comparisonSignals(for: item).rowLine)
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

            if let comparison {
                marketEvidenceStrip(comparison, lineLimit: fitLineLimit)
                    .padding(.top, 2)
            }
        }
    }

    private func marketEvidenceStrip(_ comparison: MarketplaceComparison, lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(comparison.marketEvidenceFacts(currencyCode: item.currencyCode).prefix(evidenceFactLimit))) { fact in
                Text(fact.line)
                    .font(.caption)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .lineLimit(lineLimit)
                    .multilineTextAlignment(.leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(comparison.marketEvidenceAccessibilityText(currencyCode: item.currencyCode) ?? "")
    }

    private func proofDisclosure(_ comparison: MarketplaceComparison) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                withAnimation(AppMotion.animation(reduceMotion: reduceMotion)) {
                    isProofExpanded.toggle()
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.shield")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brand.primaryText)
                        .accessibilityHidden(true)

                    Text(isProofExpanded ? "Hide proof".localized : "Show proof".localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brand.foregroundSecondary)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brand.mutedForeground)
                        .rotationEffect(.degrees(isProofExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityLabel(isProofExpanded ? "Hide proof".localized : "Show proof".localized)
            .accessibilityHint("Shows the market checks behind this recommendation.".localized)

            if isProofExpanded {
                proofDetails(comparison)
                    .transition(.opacity)
            }
        }
        .padding(.bottom, Spacing.xs)
    }

    private func proofDetails(_ comparison: MarketplaceComparison) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(comparison.marketEvidenceFacts(currencyCode: item.currencyCode)) { fact in
                Text(fact.line)
                    .font(.caption)
                    .foregroundStyle(Color.brand.foregroundSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(comparison.marketplaceProofSources(currencyCode: item.currencyCode).prefix(3), id: \.self) { line in
                Text(line)
                    .font(.caption2)
                    .foregroundStyle(Color.brand.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.sm)
        .background(Color.brand.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(Color.brand.border.opacity(0.72), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(comparison.marketplaceProofAccessibilityText(currencyCode: item.currencyCode))
    }

    private func payoutCircle(size: CGFloat) -> some View {
        Text(estimate.payout.currency())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.brand.foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: size, height: size)
            .background(Circle().stroke(Color.brand.borderStrong.opacity(0.82), lineWidth: 1))
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

    private var evidenceFactLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 4 : 3
    }

    private var accessibilityLabel: String {
        MarketplaceAccessibilityText.estimateLabel(for: estimate, item: item, comparison: comparison)
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
    static func estimateLabel(
        for estimate: MarketplaceEstimate,
        item: DetectedItem? = nil,
        comparison: MarketplaceComparison? = nil
    ) -> String {
        let dollars = Int(estimate.payout.doubleValue.rounded())
        let delta = Int(estimate.deltaPct.rounded())
        let nameAndFit = nameAndFitLabel(for: estimate)
        let baseLabel: String
        guard delta != 0 else {
            baseLabel = String.localizedFormat("%@, estimated payout %d dollars, average payout", nameAndFit, dollars)
            return labelWithReason(baseLabel, estimate: estimate, item: item, comparison: comparison)
        }
        let direction = (delta > 0 ? "above" : "below").localized
        baseLabel = String.localizedFormat("%@, estimated payout %d dollars, %d percent %@ average", nameAndFit, dollars, abs(delta), direction)
        return labelWithReason(baseLabel, estimate: estimate, item: item, comparison: comparison)
    }

    static func summaryLabel(
        _ label: String,
        for estimate: MarketplaceEstimate,
        item: DetectedItem? = nil,
        comparison: MarketplaceComparison? = nil
    ) -> String {
        String.localizedFormat("%@, %@", label.localized, estimateLabel(for: estimate, item: item, comparison: comparison))
    }

    private static func labelWithReason(
        _ label: String,
        estimate: MarketplaceEstimate,
        item: DetectedItem?,
        comparison: MarketplaceComparison?
    ) -> String {
        guard let item else {
            return label
        }
        let marketSignal = comparison?.verifiedAccessibilitySignal(currencyCode: item.currencyCode)
            ?? estimate.comparisonSignals(for: item).accessibilitySummary
        let evidenceDetails = comparison?.marketEvidenceAccessibilityText(currencyCode: item.currencyCode)
        return String.localizedFormat(
            "%@, %@, %@",
            label,
            [marketSignal, evidenceDetails].compactMap { $0 }.joined(separator: ", "),
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

extension MarketplaceComparison {
    func marketEvidenceFacts(currencyCode: String) -> [MarketplaceEvidenceFact] {
        var facts: [MarketplaceEvidenceFact] = []
        appendEvidenceStatusFact(to: &facts)
        appendEvidenceSourceFact(to: &facts)
        appendLikelyRangeFact(currencyCode: currencyCode, to: &facts)
        appendSoldFact(currencyCode: currencyCode, to: &facts)
        appendCleanTextFact(label: "Fees", value: feeSummary, to: &facts)
        appendCleanTextFact(label: "Speed", value: expectedSpeed, to: &facts)
        appendCleanTextFact(label: "Shipping", value: shippingExpectation, to: &facts)
        appendListPriceFallback(currencyCode: currencyCode, to: &facts)
        return facts
    }

    func marketEvidenceAccessibilityText(currencyCode: String) -> String? {
        let facts = marketEvidenceFacts(currencyCode: currencyCode)
        guard facts.isEmpty == false else { return nil }
        return facts.map(\.line).joined(separator: ", ")
    }

    func hasMarketplaceProofDetails(currencyCode: String) -> Bool {
        marketEvidenceFacts(currencyCode: currencyCode).isEmpty == false ||
            marketplaceProofSources(currencyCode: currencyCode).isEmpty == false
    }

    func marketplaceProofSources(currencyCode: String) -> [String] {
        (evidenceSources ?? [])
            .compactMap { $0.sanitizedForDisplay()?.marketplaceProofLine(currencyCode: currencyCode) }
    }

    func marketplaceProofAccessibilityText(currencyCode: String) -> String {
        let facts = marketEvidenceFacts(currencyCode: currencyCode).map(\.line)
        let sources = marketplaceProofSources(currencyCode: currencyCode)
        return ([String(localized: "Proof")] + facts + sources).joined(separator: ", ")
    }

    func verifiedRowSignal(currencyCode: String) -> String? {
        guard evidenceStatus != .unavailable else { return nil }
        let price = listPrice.map { String.localizedFormat("List around %@", $0.currency(code: currencyCode)) }
        let sold = verifiedSoldPriceSignal(currencyCode: currencyCode)
        let speed = cleanEvidenceText(expectedSpeed, maxLength: 80)
        let shipping = cleanEvidenceText(shippingExpectation, maxLength: 100)
        let parts = [price, sold, speed, shipping].compactMap { $0 }
        guard parts.isEmpty == false else { return nil }
        return parts.prefix(3).joined(separator: " · ")
    }

    func verifiedAccessibilitySignal(currencyCode: String) -> String? {
        verifiedRowSignal(currencyCode: currencyCode)?.replacingOccurrences(of: " · ", with: ", ")
    }

    func verifiedSoldPriceSignal(currencyCode: String) -> String {
        hasVerifiedSoldCompEvidence ? soldPriceSignal(currencyCode: currencyCode) : "No sold prices found".localized
    }

    private func appendEvidenceStatusFact(to facts: inout [MarketplaceEvidenceFact]) {
        switch evidenceStatus {
        case .grounded:
            let value = hasVerifiedSoldCompEvidence ? "Sold comps checked" : "No verified sold comps"
            facts.append(MarketplaceEvidenceFact(label: "Evidence", value: value.localized))
        case .limited:
            facts.append(MarketplaceEvidenceFact(label: "Evidence", value: "No verified sold comps".localized))
        case .unavailable:
            break
        }
    }

    private var hasVerifiedSoldCompEvidence: Bool {
        hasSoldCompPriceFields && hasVerifiedSoldEvidenceSource
    }

    private var hasSoldCompPriceFields: Bool {
        compLowPrice != nil || compMedianPrice != nil || compHighPrice != nil
    }

    private var hasVerifiedSoldEvidenceSource: Bool {
        (evidenceSources ?? []).contains { source in
            guard let cleanSource = source.sanitizedForDisplay(),
                  cleanSource.price != nil,
                  cleanSource.dateChecked != nil,
                  cleanSource.hasSourceReference,
                  cleanSource.isSoldOrCompleted
            else {
                return false
            }
            return true
        }
    }

    private func appendEvidenceSourceFact(to facts: inout [MarketplaceEvidenceFact]) {
        let sources = (evidenceSources ?? []).compactMap { $0.sanitizedForDisplay() }
        guard sources.isEmpty == false else { return }
        let checkedDates = Set(sources.compactMap(\.dateChecked))
        let sourceCount = String.localizedFormat("%d source(s)", sources.count)
        let value = checkedDates.count == 1
            ? String.localizedFormat("%@ · Checked %@", sourceCount, checkedDates.first ?? "")
            : sourceCount
        facts.append(MarketplaceEvidenceFact(label: "Sources", value: value))
    }

    private func appendLikelyRangeFact(currencyCode: String, to facts: inout [MarketplaceEvidenceFact]) {
        guard let low = likelyRangeLow, let high = likelyRangeHigh else { return }
        facts.append(MarketplaceEvidenceFact(
            label: "Range",
            value: String.localizedFormat("%@ to %@", low.currency(code: currencyCode), high.currency(code: currencyCode))
        ))
    }

    private func appendSoldFact(currencyCode: String, to facts: inout [MarketplaceEvidenceFact]) {
        facts.append(MarketplaceEvidenceFact(label: "Sold", value: verifiedSoldPriceSignal(currencyCode: currencyCode)))
    }

    private func appendCleanTextFact(label: String, value: String?, to facts: inout [MarketplaceEvidenceFact]) {
        let cleanValue = value?
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard cleanValue.isEmpty == false else { return }
        facts.append(MarketplaceEvidenceFact(label: label, value: cleanValue))
    }

    private func appendListPriceFallback(currencyCode: String, to facts: inout [MarketplaceEvidenceFact]) {
        guard facts.isEmpty, let listPrice else { return }
        facts.append(MarketplaceEvidenceFact(label: "List", value: listPrice.currency(code: currencyCode)))
    }

    private func cleanEvidenceText(_ value: String?, maxLength: Int) -> String? {
        let cleanValue = value?
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard cleanValue.isEmpty == false else { return nil }
        return String(cleanValue.prefix(maxLength))
    }
}

private extension ListingEvidenceSource {
    func marketplaceProofLine(currencyCode: String) -> String? {
        let priceText = price.map { $0.currency(code: currencyCode) }
        let parts = [
            sourceMarketplace,
            listingStatus,
            title,
            priceText,
            conditionAndVariant,
            comparability,
            dateChecked.map { String.localizedFormat("Checked %@", $0) }
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        guard parts.isEmpty == false else { return nil }
        return parts.joined(separator: " · ")
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
