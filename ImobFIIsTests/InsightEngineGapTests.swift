import Foundation
import SwiftData
import Testing
@testable import ImobFIIs

@Suite("Insights de aporte — gaps e aporte")
struct InsightEngineGapTests {
    private let strategy = BalancedRetailStrategy()

    @Test @MainActor
    func prefersExistingHoldingsBeforeMissingSegments() {
        let paper = makeInsightHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 100,
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
        let paper = makeInsightHolding(
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
        let paper = makeInsightHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 290,
            price: 10,
            average: 10
        )
        let hybrid = makeInsightHolding(
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
        let paper = makeInsightHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 400,
            price: 10,
            average: 10
        )
        let hybrid = makeInsightHolding(
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
        let paper = makeInsightHolding(
            ticker: "CPTS11",
            segment: .paper,
            shares: 100,
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
}
