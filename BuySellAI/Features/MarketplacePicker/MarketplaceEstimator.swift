import Foundation

enum MarketplaceEstimator {
    static func estimates(for base: Decimal) -> [MarketplaceEstimate] {
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
