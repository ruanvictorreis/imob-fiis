import Foundation
import SwiftData

@Model
final class Holding {
    var shares: Int
    var averagePrice: Decimal
    var purchasedAt: Date
    var notes: String
    var fund: Fund?

    var investedAmount: Decimal {
        averagePrice * Decimal(shares)
    }

    var currentValue: Decimal {
        (fund?.currentPrice ?? 0) * Decimal(shares)
    }

    var profitAndLoss: Decimal {
        currentValue - investedAmount
    }

    var estimatedMonthlyIncome: Decimal {
        (fund?.lastDividend ?? 0) * Decimal(shares)
    }

    init(
        shares: Int,
        averagePrice: Decimal,
        purchasedAt: Date = .now,
        notes: String = "",
        fund: Fund? = nil
    ) {
        self.shares = shares
        self.averagePrice = averagePrice
        self.purchasedAt = purchasedAt
        self.notes = notes
        self.fund = fund
    }

    func addShares(_ additionalShares: Int, at price: Decimal) {
        guard additionalShares > 0 else { return }
        let totalShares = shares + additionalShares
        let totalCost = investedAmount + (price * Decimal(additionalShares))
        shares = totalShares
        averagePrice = totalCost / Decimal(totalShares)
    }
}
