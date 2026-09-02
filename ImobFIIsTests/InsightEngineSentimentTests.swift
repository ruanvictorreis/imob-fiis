import Foundation
import Testing
@testable import ImobFIIs

@Suite("Insights de aporte — sentimento")
struct InsightEngineSentimentTests {
    private let strategy = BalancedRetailStrategy()

    @Test @MainActor
    func prefersHigherSentimentWhenAllocationSignalsAreEqual() {
        let positive = makeInsightHolding(
            ticker: "KNCR11",
            segment: .paper,
            shares: 50,
            price: 10,
            average: 10
        )
        let negative = makeInsightHolding(
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

        var sentiment = SentimentContext.empty
        sentiment.scoresByTicker["KNCR11"] = 0.6
        sentiment.labelsByTicker["KNCR11"] = .positive
        sentiment.confidenceByTicker["KNCR11"] = .medium
        sentiment.scoresByTicker["CPTS11"] = -0.5
        sentiment.labelsByTicker["CPTS11"] = .negative
        sentiment.confidenceByTicker["CPTS11"] = .high

        let snapshot = InsightEngine.evaluate(
            [negative, positive, hybrid],
            strategy: strategy,
            sentiment: sentiment
        )

        #expect(snapshot.insights.map(\.ticker) == ["KNCR11", "CPTS11"])
    }

    @Test @MainActor
    func blocksStrongNegativeSentimentFromTopPick() {
        let negative = makeInsightHolding(
            ticker: "CPTS11", segment: .paper, shares: 50, price: 10, average: 10
        )
        let neutral = makeInsightHolding(
            ticker: "KNCR11", segment: .paper, shares: 100, price: 10, average: 10
        )
        let hybrid = makeInsightHolding(
            ticker: "HGBS11", segment: .hybrid, shares: 850, price: 10, average: 10
        )

        var sentiment = SentimentContext.empty
        sentiment.scoresByTicker["CPTS11"] = -0.55
        sentiment.labelsByTicker["CPTS11"] = .negative
        sentiment.confidenceByTicker["CPTS11"] = .high
        sentiment.scoresByTicker["KNCR11"] = 0.0
        sentiment.labelsByTicker["KNCR11"] = .neutral
        sentiment.confidenceByTicker["KNCR11"] = .medium

        let snapshot = InsightEngine.evaluate([negative, neutral, hybrid], strategy: strategy, sentiment: sentiment)

        #expect(snapshot.insights.first?.ticker == "KNCR11")
    }

    @Test
    func blockedTopPickDetectsStrongNegativeConfidence() {
        #expect(InsightEngine.isBlockedTopPick(
            InsightItem(
                ticker: "CPTS11",
                segment: .paper,
                currentValue: 500,
                segmentGap: 0.2,
                internalGap: 0.1,
                isBelowAverage: false,
                nextPurchaseYield: nil,
                suggestedSegmentContribution: nil,
                sentimentScore: -0.55,
                sentimentLabel: .negative,
                sentimentConfidence: .high,
                sentimentSummary: "Risco",
                reasons: []
            )
        ))
    }

    @Test
    func applyTopPickGuardPromotesFirstNonBlockedInsight() {
        let blocked = InsightItem(
            ticker: "AAA11",
            segment: .paper,
            currentValue: 100,
            segmentGap: 0.2,
            internalGap: 0.1,
            isBelowAverage: false,
            nextPurchaseYield: nil,
            suggestedSegmentContribution: nil,
            sentimentScore: -0.8,
            sentimentLabel: .negative,
            sentimentConfidence: .high,
            sentimentSummary: nil,
            reasons: []
        )
        let allowed = InsightItem(
            ticker: "BBB11",
            segment: .paper,
            currentValue: 100,
            segmentGap: 0.2,
            internalGap: 0.1,
            isBelowAverage: false,
            nextPurchaseYield: nil,
            suggestedSegmentContribution: nil,
            sentimentScore: 0.1,
            sentimentLabel: .neutral,
            sentimentConfidence: .medium,
            sentimentSummary: nil,
            reasons: []
        )

        let reordered = InsightEngine.applyTopPickGuard([blocked, allowed])

        #expect(reordered.first?.ticker == "BBB11")
    }
}
