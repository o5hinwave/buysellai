import Foundation

struct MarketplaceRecommendationComponents: Sendable, Hashable {
    let saleLikelihood: Double
    let netPayout: Double
    let listingEffort: Double
    let shippingFit: Double
    let localPickupFit: Double
    let buyerTrust: Double
    let speed: Double
    let itemFactQuality: Double

    var total: Double {
        saleLikelihood * 0.52
            + netPayout * 0.18
            + listingEffort * 0.07
            + shippingFit * 0.08
            + localPickupFit * 0.05
            + buyerTrust * 0.04
            + speed * 0.04
            + itemFactQuality * 0.02
    }
}

enum MarketplaceEstimator {
    static func estimates(for base: Decimal) -> [MarketplaceEstimate] {
        sortedPayoutEstimates(for: base)
    }

    static func estimates(for item: DetectedItem) -> [MarketplaceEstimate] {
        let payoutEstimates = sortedPayoutEstimates(for: item.priceEstimate)
        let payouts = payoutEstimates.map(\.payout)
        let highestPayout = payouts.max() ?? Decimal(1)
        let lowestPayout = payouts.min() ?? Decimal(1)
        let payoutRange = max(highestPayout.doubleValue - lowestPayout.doubleValue, 1)
        let catalogOrder = Dictionary(uniqueKeysWithValues: Marketplace.allCases.enumerated().map { index, marketplace in
            (marketplace, index)
        })

        let ranked = payoutEstimates
            .map { estimate -> (MarketplaceEstimate, Double) in
                var copy = estimate
                copy.badge = .none
                let components = recommendationComponents(
                    for: item,
                    estimate: estimate,
                    lowestPayout: lowestPayout,
                    payoutRange: payoutRange
                )
                return (copy, components.total)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 > rhs.1
                }
                if lhs.0.payout != rhs.0.payout {
                    return lhs.0.payout > rhs.0.payout
                }
                return (catalogOrder[lhs.0.id] ?? Int.max) < (catalogOrder[rhs.0.id] ?? Int.max)
            }
            .map(\.0)

        guard ranked.isEmpty == false else {
            return ranked
        }

        let lowestPayoutMarketplace = payoutEstimates.last?.id
        return ranked.enumerated().map { index, estimate in
            var copy = estimate
            if index == 0 {
                copy.badge = .best
            } else if estimate.id == lowestPayoutMarketplace {
                copy.badge = .lowest
            }
            return copy
        }
    }

    static func recommendationComponents(
        for item: DetectedItem,
        estimate: MarketplaceEstimate,
        lowestPayout: Decimal,
        payoutRange: Double
    ) -> MarketplaceRecommendationComponents {
        let profile = estimate.id.optimizationProfile
        return MarketplaceRecommendationComponents(
            saleLikelihood: Double(estimate.id.searchFitScore(for: item)),
            netPayout: ((estimate.payout.doubleValue - lowestPayout.doubleValue) / max(payoutRange, 1)) * 100,
            listingEffort: Double(profile.listingEffort(for: item)),
            shippingFit: Double(profile.shippingFit(for: item)),
            localPickupFit: Double(profile.localPickupFit(for: item)),
            buyerTrust: Double(profile.buyerTrust(for: item)),
            speed: Double(profile.speedScore),
            itemFactQuality: Double(item.marketplaceFactQualityScore)
        )
    }

    private static func sortedPayoutEstimates(for base: Decimal) -> [MarketplaceEstimate] {
        let positiveBase = base < Decimal(1) ? Decimal(1) : base
        let catalogOrder = Dictionary(uniqueKeysWithValues: Marketplace.allCases.enumerated().map { index, marketplace in
            (marketplace, index)
        })
        let rawEstimates = Marketplace.allCases.map { marketplace -> (Marketplace, Decimal) in
            let payout = (positiveBase * marketplace.feeMultiplier - marketplace.fixedDeduction).rounded(scale: 0)
            return (marketplace, payout < Decimal(1) ? Decimal(1) : payout)
        }

        let average = rawEstimates
            .map(\.1.doubleValue)
            .reduce(0, +) / Double(rawEstimates.count)

        let sorted = rawEstimates
            .map { marketplace, payout in
                let delta = average == 0 ? 0 : ((payout.doubleValue - average) / average) * 100
                return MarketplaceEstimate(id: marketplace, payout: payout, deltaPct: delta, badge: .none)
            }
            .sorted { lhs, rhs in
                if lhs.payout != rhs.payout {
                    return lhs.payout > rhs.payout
                }
                return (catalogOrder[lhs.id] ?? Int.max) < (catalogOrder[rhs.id] ?? Int.max)
            }

        return sorted.enumerated().map { index, estimate in
            var copy = estimate
            if index == 0 {
                copy.badge = .best
            } else if index == sorted.count - 1 {
                copy.badge = .lowest
            }
            return copy
        }
    }
}

enum MarketplaceSummaryKind: String, Sendable, Hashable {
    case bestChance
    case mostMoneyBack
    case goodFit
    case second
    case third

    var label: String {
        switch self {
        case .bestChance:
            "Best chance"
        case .mostMoneyBack:
            "Most money back"
        case .goodFit:
            "Good fit"
        case .second:
            "Second"
        case .third:
            "Third"
        }
    }
}

struct MarketplaceSummaryPick: Identifiable, Sendable, Hashable {
    let kind: MarketplaceSummaryKind
    let estimate: MarketplaceEstimate

    var id: String {
        "\(kind.rawValue).\(estimate.id.rawValue)"
    }
}

enum MarketplaceSummaryPlanner {
    static func picks(from estimates: [MarketplaceEstimate]) -> [MarketplaceSummaryPick] {
        guard let bestChance = estimates.first else {
            return []
        }

        let mostMoneyBack = estimates.max { lhs, rhs in
            if lhs.payout != rhs.payout {
                return lhs.payout < rhs.payout
            }
            return catalogIndex(lhs.id) > catalogIndex(rhs.id)
        }

        var picks = [MarketplaceSummaryPick(kind: .bestChance, estimate: bestChance)]
        if let mostMoneyBack, mostMoneyBack.id != bestChance.id {
            picks.append(MarketplaceSummaryPick(kind: .mostMoneyBack, estimate: mostMoneyBack))
        }

        for estimate in estimates where picks.contains(where: { $0.estimate.id == estimate.id }) == false {
            let kind: MarketplaceSummaryKind
            if picks.contains(where: { $0.kind == .mostMoneyBack }) {
                kind = .goodFit
            } else {
                kind = picks.count == 1 ? .second : .third
            }
            picks.append(MarketplaceSummaryPick(kind: kind, estimate: estimate))

            if picks.count == 3 {
                break
            }
        }

        return picks
    }

    private static func catalogIndex(_ marketplace: Marketplace) -> Int {
        Marketplace.allCases.firstIndex(of: marketplace) ?? Int.max
    }
}
