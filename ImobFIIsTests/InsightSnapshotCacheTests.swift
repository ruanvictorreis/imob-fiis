import Foundation
import SwiftData
import Testing
@testable import ImobFIIs

@Suite("Cache dos Insights")
@MainActor
struct InsightSnapshotCacheTests {
    @Test
    func reusesSnapshotWhileInputsAreUnchanged() throws {
        let (container, holding) = try makePortfolio()
        _ = container
        let cache = InsightSnapshotCache()
        let strategy = BalancedRetailStrategy()

        let first = cache.snapshot(for: [holding], strategy: strategy, sentiment: .empty)
        let second = cache.snapshot(for: [holding], strategy: strategy, sentiment: .empty)

        #expect(first == second)
        #expect(cache.evaluationCount == 1)
        #expect(first == InsightEngine.evaluate([holding], strategy: strategy))
    }

    @Test
    func recalculatesWhenPositionOrPriceChanges() throws {
        let (container, holding) = try makePortfolio()
        _ = container
        let cache = InsightSnapshotCache()
        let strategy = BalancedRetailStrategy()
        _ = cache.snapshot(for: [holding], strategy: strategy, sentiment: .empty)

        holding.shares = 20
        _ = cache.snapshot(for: [holding], strategy: strategy, sentiment: .empty)
        holding.fund?.currentPrice = 80
        let updated = cache.snapshot(for: [holding], strategy: strategy, sentiment: .empty)

        #expect(cache.evaluationCount == 3)
        #expect(updated == InsightEngine.evaluate([holding], strategy: strategy))
    }

    @Test
    func recalculatesWhenTargetsChange() throws {
        let (container, holding) = try makePortfolio()
        _ = container
        let cache = InsightSnapshotCache()
        _ = cache.snapshot(for: [holding], strategy: BalancedRetailStrategy(), sentiment: .empty)

        let custom = CustomAllocationStrategy(targetWeights: [.paper: 1])
        let snapshot = cache.snapshot(for: [holding], strategy: custom, sentiment: .empty)

        #expect(cache.evaluationCount == 2)
        #expect(snapshot == InsightEngine.evaluate([holding], strategy: custom))
    }

    private func makePortfolio() throws -> (ModelContainer, Holding) {
        let container = Persistence.makeContainer(inMemory: true)
        let fund = Fund(
            ticker: "KNCR11",
            name: "Kinea Rendimentos",
            segment: .paper,
            manager: "Kinea",
            currentPrice: 100,
            dividendYield: 0.12,
            lastDividend: 1
        )
        container.mainContext.insert(fund)
        let holding = Holding(shares: 10, averagePrice: 95, fund: fund)
        container.mainContext.insert(holding)
        try container.mainContext.save()
        return (container, holding)
    }
}
