import Foundation
import Testing
@testable import ImobFIIs

@Suite("Simulador de aporte")
struct ContributionSimulatorTests {
    private let strategy = CustomAllocationStrategy(targetWeights: [
        .paper: 0.5,
        .logistics: 0.3,
        .malls: 0.2,
    ])

    @Test @MainActor
    func splitsSmallContributionProportionallyToGaps() {
        // Carteira de R$ 1.000: Papel 700, Logística 300, Shoppings 0.
        let holdings = [
            makeInsightHolding(ticker: "KNCR11", segment: .paper, shares: 7, price: 100, average: 100),
            makeInsightHolding(ticker: "HGLG11", segment: .logistics, shares: 3, price: 100, average: 100),
        ]

        let result = ContributionSimulator.simulate(amount: 100, holdings: holdings, strategy: strategy)

        // Total projetado R$ 1.100: faltam Logística 30 e Shoppings 220 (Papel já passa da meta).
        #expect(result.map(\.segment) == [.paper, .logistics, .malls])
        #expect(result.map(\.amount) == [0, 12, 88])
        #expect(total(result) == 100)
    }

    @Test @MainActor
    func fillsGapsAndSpreadsRemainderByTarget() {
        let holdings = [
            makeInsightHolding(ticker: "KNCR11", segment: .paper, shares: 7, price: 100, average: 100),
            makeInsightHolding(ticker: "HGLG11", segment: .logistics, shares: 3, price: 100, average: 100),
        ]

        let result = ContributionSimulator.simulate(amount: 1_000, holdings: holdings, strategy: strategy)

        // Total projetado R$ 2.000 cobre todas as metas exatamente.
        #expect(total(result) == 1_000)
        for contribution in result {
            #expect(abs(contribution.projectedWeight - contribution.targetWeight) < 0.000_1)
        }
    }

    @Test @MainActor
    func followsTargetsForEmptyPortfolio() {
        let result = ContributionSimulator.simulate(amount: 500, holdings: [], strategy: strategy)

        #expect(result.map(\.segment) == [.paper, .logistics, .malls])
        #expect(result.map(\.amount) == [250, 150, 100])
        #expect(result.allSatisfy { $0.currentWeight == 0 })
    }

    @Test @MainActor
    func keepsCentsExactWhenSplitIsUneven() {
        let result = ContributionSimulator.simulate(
            amount: Decimal(string: "100.01")!,
            holdings: [],
            strategy: CustomAllocationStrategy(targetWeights: [.paper: 1.0 / 3, .logistics: 1.0 / 3, .malls: 1.0 / 3])
        )

        #expect(total(result) == Decimal(string: "100.01")!)
    }

    @Test @MainActor
    func listsEveryTargetSegmentWithCurrentWeightsWhenAmountIsZero() {
        let holdings = [
            makeInsightHolding(ticker: "KNCR11", segment: .paper, shares: 7, price: 100, average: 100),
            makeInsightHolding(ticker: "HGLG11", segment: .logistics, shares: 3, price: 100, average: 100),
        ]

        let result = ContributionSimulator.simulate(amount: 0, holdings: holdings, strategy: strategy)

        #expect(result.map(\.segment) == [.paper, .logistics, .malls])
        #expect(result.allSatisfy { $0.amount == 0 })
        #expect(result.map(\.projectedWeight) == result.map(\.currentWeight))
        let empty = ContributionSimulator.simulate(amount: 0, holdings: [], strategy: strategy)
        #expect(empty.map(\.projectedWeight) == [0, 0, 0])
    }

    @Test @MainActor
    func returnsNothingWithoutTargets() {
        #expect(
            ContributionSimulator.simulate(
                amount: 100,
                holdings: [],
                strategy: CustomAllocationStrategy(targetWeights: [:])
            ).isEmpty
        )
    }

    @Test @MainActor
    func frozenSegmentValuesIgnoreLaterPurchases() {
        let paper = makeInsightHolding(ticker: "KNCR11", segment: .paper, shares: 7, price: 100, average: 100)
        let holdings = [
            paper,
            makeInsightHolding(ticker: "HGLG11", segment: .logistics, shares: 3, price: 100, average: 100),
        ]
        let frozen = ContributionSimulator.segmentValues(in: holdings)
        let before = ContributionSimulator.simulate(amount: 100, holdings: holdings, strategy: strategy)

        paper.addShares(10, at: 100)

        let after = ContributionSimulator.simulate(amount: 100, valueBySegment: frozen, strategy: strategy)
        #expect(after == before)
        #expect(ContributionSimulator.simulate(amount: 100, holdings: holdings, strategy: strategy) != before)
    }

    @Test @MainActor
    func snapshotListsOnlyHoldingsOfTheSegmentInPriorityOrder() {
        let holdings = [
            makeInsightHolding(ticker: "KNCR11", segment: .paper, shares: 5, price: 100, average: 100),
            makeInsightHolding(ticker: "CPTS11", segment: .paper, shares: 1, price: 100, average: 100),
            makeInsightHolding(ticker: "HGLG11", segment: .logistics, shares: 3, price: 100, average: 100),
        ]
        let snapshot = InsightEngine.evaluate(holdings, strategy: strategy)

        let paper = snapshot.insights(in: .paper)

        #expect(Set(paper.map(\.ticker)) == ["KNCR11", "CPTS11"])
        #expect(paper.map(\.ticker) == snapshot.insights.map(\.ticker).filter { $0 != "HGLG11" })
        #expect(snapshot.insights(in: .malls).isEmpty)
    }

    @Test @MainActor
    func suggestedSharesRoundDownToWholeShares() {
        #expect(AddHoldingSheet.shares(buying: 1_000, at: Decimal(string: "98.50")!) == 10)
        #expect(AddHoldingSheet.shares(buying: 50, at: 100) == 0)
        #expect(AddHoldingSheet.shares(buying: nil, at: 100) == 0)
        #expect(AddHoldingSheet.shares(buying: 100, at: nil) == 0)
    }

    private func total(_ contributions: [SegmentContribution]) -> Decimal {
        contributions.reduce(0) { $0 + $1.amount }
    }
}
