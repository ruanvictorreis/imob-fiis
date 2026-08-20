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
        guard let projected = projectedPosition(adding: additionalShares, at: price) else { return }
        shares = projected.shares
        averagePrice = projected.averagePrice
    }

    func replacePosition(shares: Int, averagePrice: Decimal) {
        guard shares > 0, averagePrice > 0 else { return }
        self.shares = shares
        self.averagePrice = averagePrice
    }

    func projectedPosition(adding additionalShares: Int, at price: Decimal) -> (shares: Int, averagePrice: Decimal)? {
        guard additionalShares > 0, price > 0 else { return nil }
        let totalShares = shares + additionalShares
        let totalCost = investedAmount + (price * Decimal(additionalShares))
        return (totalShares, totalCost / Decimal(totalShares))
    }
}
