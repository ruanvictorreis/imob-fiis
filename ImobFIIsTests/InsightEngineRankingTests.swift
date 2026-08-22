import Foundation
import SwiftData
import Testing
@testable import ImobFIIs

@Suite("Insights de aporte — ranking")
struct InsightEngineRankingTests {
    private let strategy = BalancedRetailStrategy()

    @Test @MainActor
    func prefersPaperOverLogisticsWhenValuesAreEqual() {
        let paper = makeInsightHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 50,
            price: 10,
            average: 10
        )
        let logistics = makeInsightHolding(
            ticker: "XPLG11",
            segment: .logistics,
            shares: 50,
            price: 10,
            average: 10
        )
        let hybrid = makeInsightHolding(
            ticker: "HGBS11",
            segment: .hybrid,
            shares: 900,
            price: 10,
            average: 10
        )

        let snapshot = InsightEngine.evaluate([paper, logistics, hybrid], strategy: strategy)

        #expect(snapshot.insights.map(\.ticker) == ["CPTS11", "XPLG11"])
        #expect(snapshot.insights[0].segmentGap > snapshot.insights[1].segmentGap)
    }

    @Test @MainActor
    func prefersSmallerPositionInsideTheSameSegment() {
        let smaller = makeInsightHolding(
            ticker: "KNCR11",
            segment: .paper,
            shares: 50,
            price: 10,
            average: 10
        )
        let larger = makeInsightHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 100,
            price: 10,
            average: 10
        )
        let hybrid = makeInsightHolding(
            ticker: "HGBS11",
            segment: .hybrid,
            shares: 850,
            price: 10,
            average: 10
        )

        let snapshot = InsightEngine.evaluate([larger, smaller, hybrid], strategy: strategy)

        #expect(snapshot.insights.map(\.ticker) == ["KNCR11", "CPTS11"])
        #expect(snapshot.insights[0].reasons.contains(.lowestWeightInSegment))
        #expect(!snapshot.insights[1].reasons.contains(.lowestWeightInSegment))
    }

    @Test @MainActor
    func excludesHybridFromRanking() {
        let hybrid = makeInsightHolding(
            ticker: "HGBS11",
            segment: .hybrid,
            shares: 990,
            price: 10,
            average: 10
        )
        let paper = makeInsightHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 10,
            price: 10,
            average: 10
        )

        let snapshot = InsightEngine.evaluate([hybrid, paper], strategy: strategy)

        #expect(snapshot.insights.map(\.ticker) == ["CPTS11"])
        #expect(snapshot.allocations.map(\.segment).contains(.paper))
        #expect(!snapshot.insights.contains { $0.ticker == "HGBS11" })
    }

    @Test @MainActor
    func usesDiscountToBreakInternalWeightTie() {
        let discounted = makeInsightHolding(
            ticker: "KNCR11",
            segment: .paper,
            shares: 50,
            price: 10,
            average: 12
        )
        let premium = makeInsightHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 100,
            price: 10,
            average: 8
        )
        let hybrid = makeInsightHolding(
            ticker: "HGBS11",
            segment: .hybrid,
            shares: 850,
            price: 10,
            average: 10
        )

        let snapshot = InsightEngine.evaluate([premium, discounted, hybrid], strategy: strategy)

        #expect(snapshot.insights.map(\.ticker) == ["KNCR11", "CPTS11"])
        #expect(snapshot.insights[0].isBelowAverage)
        #expect(snapshot.insights[0].reasons.contains(.belowAveragePrice))
    }

    @Test @MainActor
    func usesDividendYield12mWhenDiscountIsTied() {
        let higherYield = makeInsightHolding(
            ticker: "KNCR11",
            segment: .paper,
            shares: 50,
            price: 10,
            average: 10,
            dividendYield: 0.12
        )
        let lowerYield = makeInsightHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 100,
            price: 10,
            average: 10,
            dividendYield: 0.08
        )
        let hybrid = makeInsightHolding(
            ticker: "HGBS11",
            segment: .hybrid,
            shares: 850,
            price: 10,
            average: 10
        )

        let snapshot = InsightEngine.evaluate([lowerYield, higherYield, hybrid], strategy: strategy)

        #expect(snapshot.insights.map(\.ticker) == ["KNCR11", "CPTS11"])
        #expect(snapshot.insights[0].nextPurchaseYield == 0.12)
        #expect(snapshot.insights[0].reasons.contains(.nextPurchaseYield))
    }

    @Test @MainActor
    func emptyInsightsWhenOnlyOffStrategyHoldingsExist() {
        let hybrid = makeInsightHolding(
            ticker: "HGBS11",
            segment: .hybrid,
            shares: 100,
            price: 10,
            average: 10
        )

        let snapshot = InsightEngine.evaluate([hybrid], strategy: strategy)

        #expect(snapshot.insights.isEmpty)
        #expect(snapshot.allocations.count == strategy.orderedSegments.count)
        #expect(snapshot.missingSegments.map(\.segment).contains(.paper))
        #expect(!snapshot.missingSegments.map(\.segment).contains(.hybrid))
    }
}
