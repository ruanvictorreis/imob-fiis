import SwiftData
import Testing
@testable import ImobFIIs

@Suite("Catálogo e carteira")
struct ImobFIIsTests {
    @Test @MainActor
    func seedingCatalogIsIdempotent() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext

        SampleData.seedIfNeeded(in: context)
        SampleData.seedIfNeeded(in: context)

        let funds = try context.fetch(FetchDescriptor<Fund>())
        #expect(funds.count == SampleData.catalogCount)
        #expect(Set(funds.map(\.ticker)).count == funds.count)
    }

    @Test @MainActor
    func addingSharesMergesExistingHolding() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        SampleData.seedIfNeeded(in: context)

        let fund = try #require(context.fetch(FetchDescriptor<Fund>()).first)
        let holding = Holding(shares: 10, averagePrice: 100, fund: fund)
        context.insert(holding)

        holding.addShares(10, at: 120)

        #expect(holding.shares == 20)
        #expect(holding.averagePrice == 110)
        #expect(fund.holdings.count == 1)
    }
}
