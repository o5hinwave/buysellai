import Foundation

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
                let payoutScore = ((estimate.payout.doubleValue - lowestPayout.doubleValue) / payoutRange) * 100
                let searchScore = Double(estimate.id.searchFitScore(for: item))
                let recommendationScore = searchScore * 0.68 + payoutScore * 0.32
                return (copy, recommendationScore)
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
