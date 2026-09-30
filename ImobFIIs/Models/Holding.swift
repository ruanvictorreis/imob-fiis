import Foundation
import SwiftData

@Model
final class Holding {
    var ticker: String = ""
    var shares: Int = 0
    var averagePrice: Decimal = 0
    var purchasedAt: Date = Date.now
    var notes: String = ""

    @Transient private var resolvedFund: Fund?

    /// Fundo do cache local com o mesmo ticker. A carteira fica em outro store (CloudKit),
    /// então não existe relacionamento entre os dois modelos.
    var fund: Fund? {
        if let resolvedFund, resolvedFund.ticker == ticker {
            return resolvedFund
        }
        guard let modelContext else { return nil }
        FundCacheRevision.shared.observe()

        let ticker = ticker
        var descriptor = FetchDescriptor<Fund>(predicate: #Predicate { $0.ticker == ticker })
        descriptor.fetchLimit = 1
        let fund = try? modelContext.fetch(descriptor).first
        resolvedFund = fund
        return fund
    }

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
        ticker: String = "",
        shares: Int,
        averagePrice: Decimal,
        purchasedAt: Date = .now,
        notes: String = "",
        fund: Fund? = nil
    ) {
        self.ticker = fund?.ticker ?? ticker
        self.shares = shares
        self.averagePrice = averagePrice
        self.purchasedAt = purchasedAt
        self.notes = notes
        self.resolvedFund = fund
    }

    func projectedPosition(adding additionalShares: Int, at price: Decimal) -> (shares: Int, averagePrice: Decimal)? {
        guard additionalShares > 0, price > 0 else { return nil }
        let totalShares = shares + additionalShares
        let totalCost = investedAmount + (price * Decimal(additionalShares))
        return (totalShares, totalCost / Decimal(totalShares))
    }

    func projectedPosition(selling soldShares: Int) -> (shares: Int, averagePrice: Decimal)? {
        guard soldShares > 0, soldShares <= shares else { return nil }
        let remaining = shares - soldShares
        return (remaining, remaining > 0 ? averagePrice : 0)
    }
}
