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

        let sentiment = makeSentimentContext([
            SentimentEntry(ticker: "KNCR11", segmentKey: "paper", score: 0.6, label: .positive, confidence: .medium),
            SentimentEntry(ticker: "CPTS11", segmentKey: "paper", score: -0.5, label: .negative, confidence: .high),
        ])

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

        let sentiment = makeSentimentContext([
            SentimentEntry(ticker: "CPTS11", segmentKey: "paper", score: -0.55, label: .negative, confidence: .high),
            SentimentEntry(ticker: "KNCR11", segmentKey: "paper", score: 0.0, label: .neutral, confidence: .medium),
        ])

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

    @Test @MainActor
    func keepsUrbanSentimentWhenTickerAlsoExistsInLogisticsReport() throws {
        let trxf = makeInsightHolding(
            ticker: "TRXF11",
            segment: .urban,
            shares: 100,
            price: 10,
            average: 10
        )
        let logistics = makeInsightHolding(
            ticker: "HGLG11",
            segment: .logistics,
            shares: 100,
            price: 10,
            average: 10
        )

        var sentiment = SentimentContext.empty
        sentiment.merge(try decodedReport(SentimentFixtures.logisticsTRXFReportJSON))
        sentiment.merge(try decodedReport(SentimentFixtures.urbanTRXFReportJSON))

        let snapshot = InsightEngine.evaluate([trxf, logistics], strategy: strategy, sentiment: sentiment)
        let trxfInsight = snapshot.insights.first { $0.ticker == "TRXF11" }

        #expect(trxfInsight?.sentimentLabel == .negative)
        #expect(trxfInsight?.sentimentScore == -0.25)
    }

    private struct SentimentEntry {
        var ticker: String
        var segmentKey: String
        var score: Double
        var label: SentimentLabel
        var confidence: SentimentConfidence
    }

    private func makeSentimentContext(_ entries: [SentimentEntry]) -> SentimentContext {
        var context = SentimentContext.empty
        for entry in entries {
            var segmentFunds = context.fundsBySegment[entry.segmentKey] ?? [:]
            segmentFunds[entry.ticker.uppercased()] = SentimentFundSnapshot(
                score: entry.score,
                confidence: entry.confidence,
                label: entry.label,
                summary: ""
            )
            context.fundsBySegment[entry.segmentKey] = segmentFunds
        }
        return context
    }

    private func decodedReport(_ json: String) throws -> SentimentSegmentReport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SentimentSegmentReport.self, from: json.data(using: .utf8)!)
    }
}
