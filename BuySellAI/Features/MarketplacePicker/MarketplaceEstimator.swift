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

    static func estimates(for item: DetectedItem, details: ItemDetailAnswers? = nil) -> [MarketplaceEstimate] {
        let payoutEstimates = sortedPayoutEstimates(for: item.priceEstimate)
        let payouts = payoutEstimates.map(\.payout)
        let highestPayout = payouts.max() ?? Decimal(1)
        let lowestPayout = payouts.min() ?? Decimal(1)
        let payoutRange = max(highestPayout.doubleValue - lowestPayout.doubleValue, 1)
        let catalogOrder = Dictionary(uniqueKeysWithValues: Marketplace.activeRecommendationCases.enumerated().map { index, marketplace in
            (marketplace, index)
        })

        let ranked = payoutEstimates
            .map { estimate -> (MarketplaceEstimate, Double) in
                var copy = estimate
                copy.badge = .none
                let components = recommendationComponents(
                    for: item,
                    details: details,
                    estimate: estimate,
                    lowestPayout: lowestPayout,
                    payoutRange: payoutRange
                )
                copy.fitScore = fitScore(from: components.total)
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

    static func estimates(
        for item: DetectedItem,
        details: ItemDetailAnswers? = nil,
        comparisons: [Marketplace: MarketplaceComparison]
    ) -> [MarketplaceEstimate] {
        let localEstimates = estimates(for: item, details: details)
        guard comparisons.isEmpty == false else {
            return localEstimates
        }

        let merged = localEstimates.map { estimate -> MarketplaceEstimate in
            guard let comparison = comparisons[estimate.id] else {
                return estimate
            }
            return MarketplaceEstimate(
                id: estimate.id,
                payout: (comparison.takeHomeEstimate ?? estimate.payout).rounded(scale: 0),
                deltaPct: estimate.deltaPct,
                badge: .none,
                fitScore: comparison.marketplaceFitScore ?? estimate.fitScore
            )
        }
        let average = merged.map(\.payout.doubleValue).reduce(0, +) / Double(max(merged.count, 1))
        let catalogOrder = Dictionary(uniqueKeysWithValues: Marketplace.activeRecommendationCases.enumerated().map { index, marketplace in
            (marketplace, index)
        })
        let sorted = merged
            .map { estimate in
                MarketplaceEstimate(
                    id: estimate.id,
                    payout: estimate.payout,
                    deltaPct: average == 0 ? 0 : ((estimate.payout.doubleValue - average) / average) * 100,
                    badge: .none,
                    fitScore: estimate.fitScore
                )
            }
            .sorted { lhs, rhs in
                if lhs.fitScore != rhs.fitScore {
                    return lhs.fitScore > rhs.fitScore
                }
                if lhs.payout != rhs.payout {
                    return lhs.payout > rhs.payout
                }
                return (catalogOrder[lhs.id] ?? Int.max) < (catalogOrder[rhs.id] ?? Int.max)
            }

        let lowestPayoutMarketplace = sorted.min { $0.payout < $1.payout }?.id
        return sorted.enumerated().map { index, estimate in
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
        details: ItemDetailAnswers? = nil,
        estimate: MarketplaceEstimate,
        lowestPayout: Decimal,
        payoutRange: Double
    ) -> MarketplaceRecommendationComponents {
        let profile = estimate.id.optimizationProfile
        let shippingFit = max(1, profile.shippingFit(for: item) - (details?.shippingPenalty ?? 0))
        let localPickupFit = min(100, profile.localPickupFit(for: item) + (details?.localPickupBoost ?? 0))
        let itemFactQuality = min(100, item.marketplaceFactQualityScore + (details?.marketplaceFactQualityBonus ?? 0))
        return MarketplaceRecommendationComponents(
            saleLikelihood: Double(estimate.id.searchFitScore(for: item)),
            netPayout: ((estimate.payout.doubleValue - lowestPayout.doubleValue) / max(payoutRange, 1)) * 100,
            listingEffort: Double(profile.listingEffort(for: item)),
            shippingFit: Double(shippingFit),
            localPickupFit: Double(localPickupFit),
            buyerTrust: Double(profile.buyerTrust(for: item)),
            speed: Double(profile.speedScore),
            itemFactQuality: Double(itemFactQuality)
        )
    }

    private static func fitScore(from total: Double) -> Int {
        min(max(Int(total.rounded()), 1), 100)
    }

    private static func sortedPayoutEstimates(for base: Decimal) -> [MarketplaceEstimate] {
        let positiveBase = base < Decimal(1) ? Decimal(1) : base
        let catalogOrder = Dictionary(uniqueKeysWithValues: Marketplace.activeRecommendationCases.enumerated().map { index, marketplace in
            (marketplace, index)
        })
        let rawEstimates = Marketplace.activeRecommendationCases.map { marketplace -> (Marketplace, Decimal) in
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
    case bestOverall
    case fastestSale
    case mostMoney
    case easiestOption

    var label: String {
        switch self {
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

    var systemImage: String {
        switch self {
        case .bestOverall:
            "checkmark.seal.fill"
        case .fastestSale:
            "bolt.fill"
        case .mostMoney:
            "dollarsign.circle.fill"
        case .easiestOption:
            "hand.tap.fill"
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
        plannedPicks(from: estimates, item: nil, details: nil)
    }

    static func picks(
        from estimates: [MarketplaceEstimate],
        item: DetectedItem,
        details: ItemDetailAnswers? = nil
    ) -> [MarketplaceSummaryPick] {
        plannedPicks(from: estimates, item: item, details: details)
    }

    private static func plannedPicks(
        from estimates: [MarketplaceEstimate],
        item: DetectedItem?,
        details: ItemDetailAnswers?
    ) -> [MarketplaceSummaryPick] {
        guard let bestOverall = estimates.first else { return [] }

        let components = item.map { componentsByMarketplace(for: estimates, item: $0, details: details) } ?? [:]
        var picks = [MarketplaceSummaryPick(kind: .bestOverall, estimate: bestOverall)]

        appendBestDistinct(
            kind: .mostMoney,
            estimates: estimates,
            into: &picks
        ) { estimate in
            estimate.payout.doubleValue
        }

        appendBestDistinct(
            kind: .fastestSale,
            estimates: estimates,
            into: &picks
        ) { estimate in
            if let component = components[estimate.id] {
                return component.speed * 0.64 + component.saleLikelihood * 0.36
            }
            return Double(estimate.id.optimizationProfile.speedScore)
        }

        appendBestDistinct(
            kind: .easiestOption,
            estimates: estimates,
            into: &picks
        ) { estimate in
            if let component = components[estimate.id] {
                return component.listingEffort * 0.58
                    + max(component.shippingFit, component.localPickupFit) * 0.24
                    + component.buyerTrust * 0.18
            }
            let profile = estimate.id.optimizationProfile
            return Double(profile.listingEffortScore) * 0.58
                + Double(max(profile.shippingEaseScore, profile.localPickupScore)) * 0.24
                + Double(profile.buyerTrustScore) * 0.18
        }

        return picks
    }

    private static func catalogIndex(_ marketplace: Marketplace) -> Int {
        Marketplace.activeRecommendationCases.firstIndex(of: marketplace) ?? Int.max
    }

    private static func appendBestDistinct(
        kind: MarketplaceSummaryKind,
        estimates: [MarketplaceEstimate],
        into picks: inout [MarketplaceSummaryPick],
        score: (MarketplaceEstimate) -> Double
    ) {
        guard let estimate = estimates
            .filter({ candidate in
                picks.contains { $0.estimate.id == candidate.id } == false
            })
            .max(by: { lhs, rhs in
                let lhsScore = score(lhs)
                let rhsScore = score(rhs)
                if lhsScore != rhsScore {
                    return lhsScore < rhsScore
                }
                if lhs.payout != rhs.payout {
                    return lhs.payout < rhs.payout
                }
                return catalogIndex(lhs.id) > catalogIndex(rhs.id)
            })
        else { return }

        picks.append(MarketplaceSummaryPick(kind: kind, estimate: estimate))
    }

    private static func componentsByMarketplace(
        for estimates: [MarketplaceEstimate],
        item: DetectedItem,
        details: ItemDetailAnswers?
    ) -> [Marketplace: MarketplaceRecommendationComponents] {
        let payouts = estimates.map(\.payout)
        let highestPayout = payouts.max() ?? Decimal(1)
        let lowestPayout = payouts.min() ?? Decimal(1)
        let payoutRange = max(highestPayout.doubleValue - lowestPayout.doubleValue, 1)

        return Dictionary(uniqueKeysWithValues: estimates.map { estimate in
            (
                estimate.id,
                MarketplaceEstimator.recommendationComponents(
                    for: item,
                    details: details,
                    estimate: estimate,
                    lowestPayout: lowestPayout,
                    payoutRange: payoutRange
                )
            )
        })
    }
}
