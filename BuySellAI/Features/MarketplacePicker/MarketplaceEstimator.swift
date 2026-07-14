import Foundation

enum MarketplaceEstimator {
    static func estimates(for base: Decimal) -> [MarketplaceEstimate] {
        let positiveBase = max(base.doubleValue, 1)
        let rawEstimates = Marketplace.allCases.map { marketplace -> (Marketplace, Decimal) in
            let payout = (Decimal(positiveBase) * marketplace.feeMultiplier - marketplace.fixedDeduction).rounded(scale: 0)
            return (marketplace, max(payout.doubleValue, 1).decimal)
        }

        let average = rawEstimates
            .map(\.1.doubleValue)
            .reduce(0, +) / Double(rawEstimates.count)

        let sorted = rawEstimates
            .map { marketplace, payout in
                let delta = average == 0 ? 0 : ((payout.doubleValue - average) / average) * 100
                return MarketplaceEstimate(id: marketplace, payout: payout, deltaPct: delta, badge: .none)
            }
            .sorted { $0.payout.doubleValue > $1.payout.doubleValue }

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

private extension Double {
    var decimal: Decimal { Decimal(self) }
}

