import Foundation
import SwiftData
import Testing
@testable import ImobFIIs

@Suite("Insights de aporte")
struct InsightEngineTests {
    private let strategy = BalancedRetailStrategy()

    @Test @MainActor
    func prefersPaperOverLogisticsWhenValuesAreEqual() {
        let paper = makeHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 50,
            price: 10,
            average: 10
        )
        let logistics = makeHolding(
            ticker: "XPLG11",
            segment: .logistics,
            shares: 50,
            price: 10,
            average: 10
        )
        let hybrid = makeHolding(
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
        let smaller = makeHolding(
            ticker: "KNCR11",
            segment: .paper,
            shares: 50,
            price: 10,
            average: 10
        )
        let larger = makeHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 100,
            price: 10,
            average: 10
        )
        let hybrid = makeHolding(
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
        let hybrid = makeHolding(
            ticker: "HGBS11",
            segment: .hybrid,
            shares: 990,
            price: 10,
            average: 10
        )
        let paper = makeHolding(
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
        let discounted = makeHolding(
            ticker: "KNCR11",
            segment: .paper,
            shares: 50,
            price: 10,
            average: 12
        )
        let premium = makeHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 100,
            price: 10,
            average: 8
        )
        let hybrid = makeHolding(
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
        let higherYield = makeHolding(
            ticker: "KNCR11",
            segment: .paper,
            shares: 50,
            price: 10,
            average: 10,
            dividendYield: 0.12
        )
        let lowerYield = makeHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 100,
            price: 10,
            average: 10,
            dividendYield: 0.08
        )
        let hybrid = makeHolding(
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
        let hybrid = makeHolding(
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

    @Test @MainActor
    func prefersExistingHoldingsBeforeMissingSegments() {
        let paper = makeHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 100,
            price: 10,
            average: 10
        )
        let hybrid = makeHolding(
            ticker: "HGBS11",
            segment: .hybrid,
            shares: 900,
            price: 10,
            average: 10
        )

        let snapshot = InsightEngine.evaluate([paper, hybrid], strategy: strategy)

        #expect(snapshot.insights.map(\.ticker) == ["CPTS11"])
        let missing = snapshot.missingSegments.map(\.segment)
        #expect(missing.contains(.logistics))
        #expect(missing.contains(.urban))
        #expect(!missing.contains(.paper))
        #expect(missing.first == .logistics || missing.first == .urban)
    }

    @Test @MainActor
    func listsMissingUnderweightSegmentsWithoutHoldings() {
        let paper = makeHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 1_000,
            price: 10,
            average: 10
        )

        let snapshot = InsightEngine.evaluate([paper], strategy: strategy)

        #expect(snapshot.insights.map(\.ticker) == ["CPTS11"])
        #expect(snapshot.missingSegments.map(\.segment) == [.logistics, .urban, .malls, .offices, .fiagro])
        #expect(snapshot.missingSegments[0].suggestedContribution == Decimal(2_000))
    }

    @Test @MainActor
    func stillRanksWhenGapIsWithinToleranceBand() {
        let paper = makeHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 290,
            price: 10,
            average: 10
        )
        let hybrid = makeHolding(
            ticker: "HGBS11",
            segment: .hybrid,
            shares: 710,
            price: 10,
            average: 10
        )

        let snapshot = InsightEngine.evaluate([paper, hybrid], strategy: strategy)

        #expect(snapshot.insights.map(\.ticker) == ["CPTS11"])
        #expect(snapshot.insights[0].suggestedSegmentContribution == nil)
        #expect(
            !snapshot.insights[0].reasons.contains {
                if case .segmentUnderweight = $0 { return true }
                return false
            }
        )
    }

    @Test @MainActor
    func stillRanksOverweightSegmentsAsBestAvailableOption() {
        let paper = makeHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 400,
            price: 10,
            average: 10
        )
        let hybrid = makeHolding(
            ticker: "HGBS11",
            segment: .hybrid,
            shares: 600,
            price: 10,
            average: 10
        )

        let snapshot = InsightEngine.evaluate([paper, hybrid], strategy: strategy)

        #expect(snapshot.insights.map(\.ticker) == ["CPTS11"])
        #expect(snapshot.insights[0].segmentGap < 0)
        #expect(snapshot.insights[0].suggestedSegmentContribution == nil)
    }

    @Test @MainActor
    func suggestsContributionAmountToCloseSegmentGap() {
        let paper = makeHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 100,
            price: 10,
            average: 10
        )
        let hybrid = makeHolding(
            ticker: "HGBS11",
            segment: .hybrid,
            shares: 900,
            price: 10,
            average: 10
        )

        let snapshot = InsightEngine.evaluate([paper, hybrid], strategy: strategy)

        #expect(snapshot.insights.count == 1)
        #expect(snapshot.insights[0].suggestedSegmentContribution == Decimal(2_000))
        #expect(
            snapshot.insights[0].reasons.contains {
                if case .suggestedContribution(let amount) = $0 {
                    return amount == Decimal(2_000)
                }
                return false
            }
        )
    }

    @MainActor
    private func makeHolding(
        ticker: String,
        segment: FundSegment,
        shares: Int,
        price: Decimal,
        average: Decimal,
        lastDividend: Decimal = 0,
        dividendYield: Double = 0
    ) -> Holding {
        let fund = Fund(
            ticker: ticker,
            name: ticker,
            segment: segment,
            manager: "",
            currentPrice: price,
            dividendYield: dividendYield,
            lastDividend: lastDividend
        )
        return Holding(shares: shares, averagePrice: average, fund: fund)
    }
}
