import Foundation
import SwiftData
import Testing
@testable import ImobFIIs

@Suite("Histórico de operações")
struct PortfolioLedgerTests {
    private let day: TimeInterval = 86_400
    private let start = Date(timeIntervalSince1970: 1_780_000_000)

    @Test
    func buysAccumulateWeightedAverage() {
        let position = PortfolioLedger.position(after: [
            transaction(.buy, shares: 10, price: 100, day: 0),
            transaction(.buy, shares: 10, price: 120, day: 1),
        ])

        #expect(position.shares == 20)
        #expect(position.averagePrice == 110)
        #expect(position.openedAt == start)
    }

    @Test
    func sellKeepsAveragePriceAndClosingResetsPosition() {
        let partial = PortfolioLedger.position(after: [
            transaction(.buy, shares: 10, price: 100, day: 0),
            transaction(.sell, shares: 4, price: 130, day: 1),
        ])
        #expect(partial.shares == 6)
        #expect(partial.averagePrice == 100)

        let reopened = PortfolioLedger.position(after: [
            transaction(.buy, shares: 10, price: 100, day: 0),
            transaction(.sell, shares: 10, price: 130, day: 1),
            transaction(.buy, shares: 5, price: 90, day: 2),
        ])
        #expect(reopened.shares == 5)
        #expect(reopened.averagePrice == 90)
        #expect(reopened.openedAt == start.addingTimeInterval(2 * day))
    }

    @Test
    func appliesTransactionsInDateOrderRegardlessOfInsertion() {
        let position = PortfolioLedger.position(after: [
            transaction(.sell, shares: 5, price: 130, day: 2),
            transaction(.buy, shares: 10, price: 100, day: 0),
            transaction(.buy, shares: 10, price: 80, day: 1),
        ])

        #expect(position.shares == 15)
        #expect(position.averagePrice == 90)
    }

    @Test
    func adjustmentOverridesEarlierHistory() {
        let position = PortfolioLedger.position(after: [
            transaction(.buy, shares: 10, price: 100, day: 0),
            transaction(.adjustment, shares: 200, price: Decimal(string: "87.3")!, day: 1),
            transaction(.buy, shares: 100, price: Decimal(string: "90.0")!, day: 2),
        ])

        #expect(position.shares == 300)
        #expect(position.averagePrice == Decimal(string: "88.2"))
    }

    @Test @MainActor
    func firstBuyRecordsOpeningBalanceForExistingPosition() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(Holding(ticker: "KNCR11", shares: 10, averagePrice: 100, purchasedAt: start))

        PortfolioLedger.recordBuy(ticker: "KNCR11", shares: 10, price: 120, date: start.addingTimeInterval(day),
                                  in: context)

        let holdings = try context.fetch(FetchDescriptor<Holding>())
        #expect(holdings.count == 1)
        #expect(holdings.first?.shares == 20)
        #expect(holdings.first?.averagePrice == 110)
        #expect(holdings.first?.purchasedAt == start)

        let kinds = PortfolioLedger.chronological(PortfolioLedger.transactions(for: "KNCR11", in: context))
            .map(\.kind)
        #expect(kinds == [.openingBalance, .buy])
    }

    @Test @MainActor
    func buyCreatesHoldingForNewTicker() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext

        PortfolioLedger.recordBuy(ticker: "HGLG11", shares: 5, price: 160, date: start, in: context)

        let holding = try #require(context.fetch(FetchDescriptor<Holding>()).first)
        #expect(holding.ticker == "HGLG11")
        #expect(holding.shares == 5)
        #expect(holding.averagePrice == 160)
    }

    @Test @MainActor
    func sellingEverythingRemovesHoldingButKeepsHistory() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        PortfolioLedger.recordBuy(ticker: "HGLG11", shares: 5, price: 160, date: start, in: context)

        #expect(!PortfolioLedger.recordSell(ticker: "HGLG11", shares: 6, price: 170, date: .now, in: context))
        #expect(PortfolioLedger.recordSell(ticker: "HGLG11", shares: 5, price: 170, date: .now, in: context))

        #expect(try context.fetchCount(FetchDescriptor<Holding>()) == 0)
        #expect(PortfolioLedger.transactions(for: "HGLG11", in: context).count == 2)
    }

    @Test @MainActor
    func adjustmentReplacesPositionAndIgnoresInvalidValues() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let average = Decimal(string: "98.5")!
        context.insert(Holding(ticker: "KNCR11", shares: 120, averagePrice: average, purchasedAt: start))

        PortfolioLedger.recordAdjustment(ticker: "KNCR11", shares: 0, averagePrice: 90, in: context)
        PortfolioLedger.recordAdjustment(ticker: "KNCR11", shares: 5, averagePrice: 0, in: context)
        #expect(PortfolioLedger.transactions(for: "KNCR11", in: context).isEmpty)

        PortfolioLedger.recordAdjustment(ticker: "KNCR11", shares: 200, averagePrice: Decimal(string: "87.3")!,
                                         in: context)

        let holding = try #require(context.fetch(FetchDescriptor<Holding>()).first)
        #expect(holding.shares == 200)
        #expect(holding.averagePrice == Decimal(string: "87.3"))
    }

    @Test @MainActor
    func reconcileMergesDuplicateHoldingsFromSync() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        PortfolioLedger.recordBuy(ticker: "KNCR11", shares: 10, price: 100, date: start, in: context)
        context.insert(Holding(ticker: "KNCR11", shares: 10, averagePrice: 100, purchasedAt: start))

        PortfolioLedger.reconcileAll(in: context)

        let holdings = try context.fetch(FetchDescriptor<Holding>())
        #expect(holdings.count == 1)
        #expect(holdings.first?.shares == 10)
    }

    @Test @MainActor
    func deletingPositionRemovesHistory() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        PortfolioLedger.recordBuy(ticker: "KNCR11", shares: 10, price: 100, date: start, in: context)

        PortfolioLedger.deletePosition(ticker: "KNCR11", in: context)

        #expect(try context.fetchCount(FetchDescriptor<Holding>()) == 0)
        #expect(PortfolioLedger.transactions(for: "KNCR11", in: context).isEmpty)
    }

    private func transaction(
        _ kind: TransactionKind,
        shares: Int,
        price: Decimal,
        day offset: Double
    ) -> PortfolioTransaction {
        let date = start.addingTimeInterval(offset * day)
        return PortfolioTransaction(
            ticker: "KNCR11",
            kind: kind,
            shares: shares,
            price: price,
            date: date,
            createdAt: date
        )
    }
}
