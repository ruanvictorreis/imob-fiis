import Foundation
import SwiftData

struct LedgerPosition: Equatable {
    var shares = 0
    var averagePrice: Decimal = 0
    var openedAt: Date?
}

/// Deriva cotas e preço médio de cada `Holding` a partir das `PortfolioTransaction` do ticker.
///
/// Posições sem nenhum lançamento (anteriores ao histórico) ficam como estão até a primeira
/// operação, quando ganham um lançamento de posição inicial com os valores atuais.
enum PortfolioLedger {
    static func position(after transactions: [PortfolioTransaction]) -> LedgerPosition {
        chronological(transactions).reduce(into: LedgerPosition()) { position, transaction in
            apply(transaction.kind, shares: transaction.shares, price: transaction.price,
                  date: transaction.date, to: &position)
        }
    }

    static func apply(
        _ kind: TransactionKind,
        shares: Int,
        price: Decimal,
        date: Date,
        to position: inout LedgerPosition
    ) {
        switch kind {
        case .openingBalance, .buy:
            guard shares > 0 else { return }
            let total = position.shares + shares
            let cost = position.averagePrice * Decimal(position.shares) + price * Decimal(shares)
            if position.shares == 0 {
                position.openedAt = date
            }
            position.shares = total
            position.averagePrice = cost / Decimal(total)
        case .sell:
            position.shares -= min(max(shares, 0), position.shares)
        case .adjustment:
            if position.shares == 0 {
                position.openedAt = date
            }
            position.shares = max(shares, 0)
            position.averagePrice = price
        }

        if position.shares == 0 {
            position = LedgerPosition()
        }
    }

    static func chronological(_ transactions: [PortfolioTransaction]) -> [PortfolioTransaction] {
        transactions.sorted { lhs, rhs in
            lhs.date != rhs.date ? lhs.date < rhs.date : lhs.createdAt < rhs.createdAt
        }
    }

    // MARK: - Operações

    @MainActor
    static func recordBuy(ticker: String, shares: Int, price: Decimal, date: Date, in context: ModelContext) {
        guard shares > 0, price > 0 else { return }
        record(PortfolioTransaction(ticker: ticker, kind: .buy, shares: shares, price: price, date: date), in: context)
    }

    /// Retorna `false` sem registrar nada se a venda passar das cotas em carteira.
    @MainActor
    @discardableResult
    static func recordSell(
        ticker: String,
        shares: Int,
        price: Decimal,
        date: Date,
        in context: ModelContext
    ) -> Bool {
        let available = holdings(for: ticker, in: context).first?.shares ?? 0
        guard shares > 0, shares <= available, price > 0 else { return false }
        record(PortfolioTransaction(ticker: ticker, kind: .sell, shares: shares, price: price, date: date), in: context)
        return true
    }

    @MainActor
    static func recordAdjustment(ticker: String, shares: Int, averagePrice: Decimal, in context: ModelContext) {
        guard shares > 0, averagePrice > 0 else { return }
        record(
            PortfolioTransaction(ticker: ticker, kind: .adjustment, shares: shares, price: averagePrice),
            in: context
        )
    }

    /// Remove a posição e todo o histórico do ticker.
    @MainActor
    static func deletePosition(ticker: String, in context: ModelContext) {
        holdings(for: ticker, in: context).forEach(context.delete)
        transactions(for: ticker, in: context).forEach(context.delete)
    }

    /// Reaplica o histórico de todos os tickers (ex.: lançamentos que chegaram de outro aparelho).
    @MainActor
    static func reconcileAll(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<PortfolioTransaction>())) ?? []
        for ticker in Set(all.map(\.ticker)) where !ticker.isEmpty {
            reconcile(ticker: ticker, in: context)
        }
    }

    @MainActor
    static func reconcile(ticker: String, in context: ModelContext) {
        let history = transactions(for: ticker, in: context)
        guard !history.isEmpty else { return }

        let position = position(after: history)
        var existing = holdings(for: ticker, in: context)
        let holding = existing.isEmpty ? nil : existing.removeFirst()
        existing.forEach(context.delete)

        guard position.shares > 0 else {
            if let holding { context.delete(holding) }
            return
        }

        let target = holding ?? {
            let created = Holding(ticker: ticker, shares: 0, averagePrice: 0)
            context.insert(created)
            return created
        }()
        if target.shares != position.shares { target.shares = position.shares }
        if target.averagePrice != position.averagePrice { target.averagePrice = position.averagePrice }
        if let openedAt = position.openedAt, target.purchasedAt != openedAt { target.purchasedAt = openedAt }
    }

    @MainActor
    private static func record(_ transaction: PortfolioTransaction, in context: ModelContext) {
        guard !transaction.ticker.isEmpty else { return }
        insertOpeningBalanceIfNeeded(ticker: transaction.ticker, in: context)
        context.insert(transaction)
        reconcile(ticker: transaction.ticker, in: context)
    }

    @MainActor
    private static func insertOpeningBalanceIfNeeded(ticker: String, in context: ModelContext) {
        guard transactions(for: ticker, in: context).isEmpty,
              let holding = holdings(for: ticker, in: context).first,
              holding.shares > 0
        else { return }

        context.insert(
            PortfolioTransaction(
                ticker: ticker,
                kind: .openingBalance,
                shares: holding.shares,
                price: holding.averagePrice,
                date: holding.purchasedAt,
                createdAt: holding.purchasedAt
            )
        )
    }

    @MainActor
    static func transactions(for ticker: String, in context: ModelContext) -> [PortfolioTransaction] {
        let descriptor = FetchDescriptor<PortfolioTransaction>(predicate: #Predicate { $0.ticker == ticker })
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    private static func holdings(for ticker: String, in context: ModelContext) -> [Holding] {
        let descriptor = FetchDescriptor<Holding>(
            predicate: #Predicate { $0.ticker == ticker },
            sortBy: [SortDescriptor(\.purchasedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
