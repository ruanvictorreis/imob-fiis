import Foundation
import SwiftData
import Testing
@testable import ImobFIIs

@Suite("Cache local de fundos")
struct FundCacheTests {
    @Test @MainActor
    func holdingResolvesFundCachedAfterSync() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let holding = Holding(ticker: "KNCR11", shares: 10, averagePrice: 100)
        context.insert(holding)

        #expect(holding.fund == nil)

        FundStore.upsert(
            FundSummary(ticker: "KNCR11", name: "Kinea Rendimentos", segment: .paper, currentPrice: 102),
            indicators: nil,
            in: context
        )

        #expect(holding.fund?.ticker == "KNCR11")
        #expect(holding.currentValue == 1020)
    }

    @Test @MainActor
    func cachesMissingFundsForSyncedHoldings() async throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(Holding(ticker: "HGLG11", shares: 5, averagePrice: 150))
        let catalog = MockFIICatalogService(
            page: FIITickerPage(funds: [], totalItems: 0),
            indicatorsByTicker: [
                "HGLG11": FIIIndicators(ticker: "HGLG11", name: "Pátria Log", price: 160, segmentoAtuacao: "Logística"),
            ]
        )

        await FundStore.cacheMissingFunds(for: ["HGLG11"], using: catalog, in: context)

        let funds = try context.fetch(FetchDescriptor<Fund>())
        #expect(funds.map(\.ticker) == ["HGLG11"])
        #expect(funds.first?.segment == .logistics)
        #expect(funds.first?.currentPrice == 160)
    }

    @Test @MainActor
    func cachesMissingFundsFromCatalogWhenIndicatorsAreUnavailable() async throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        let holding = Holding(ticker: "XPML11", shares: 10, averagePrice: 100)
        context.insert(holding)

        await FundStore.cacheMissingFunds(for: ["XPML11"], using: MockFIICatalogService.sample, in: context)

        let funds = try context.fetch(FetchDescriptor<Fund>())
        #expect(funds.map(\.ticker) == ["XPML11"])
        #expect(funds.first?.segment == .malls)
        #expect(holding.currentValue == Decimal(string: "1042"))
    }
}
