import Foundation

extension InsightEngine {
    struct RankingInputs {
        var totalValue: Double
        var valueBySegment: [FundSegment: Double]
        var gapBySegment: [FundSegment: Double]
        var targetWeights: [FundSegment: Double]
        var lowestTickers: Set<String>
        var bestYieldBySegment: [FundSegment: Double]
        var sentiment: SentimentContext
    }

    static func insight(
        for holding: Holding,
        peers: Int,
        ranking: RankingInputs
    ) -> InsightItem? {
        guard let fund = holding.fund else { return nil }
        let segment = fund.segment
        let ticker = fund.ticker.uppercased()
        let segmentValue = ranking.valueBySegment[segment] ?? 0
        let internalWeight = segmentValue > 0 ? double(from: holding.currentValue) / segmentValue : 0
        let yield = nextPurchaseYield(holding)
        let belowAverage = fund.currentPrice > 0 && fund.currentPrice < holding.averagePrice
        let segmentGap = ranking.gapBySegment[segment] ?? 0
        let suggestedContribution = suggestedSegmentContribution(
            segmentGap: segmentGap,
            totalValue: ranking.totalValue,
            targetWeight: ranking.targetWeights[segment] ?? 0,
            segmentValue: segmentValue
        )
        let sentimentSnapshot = ranking.sentiment.fund(
            for: ticker,
            segmentKey: segment.sentimentKey
        )

        return InsightItem(
            ticker: fund.ticker,
            segment: segment,
            currentValue: holding.currentValue,
            segmentGap: segmentGap,
            internalGap: (1 / Double(max(peers, 1))) - internalWeight,
            isBelowAverage: belowAverage,
            nextPurchaseYield: yield,
            suggestedSegmentContribution: suggestedContribution,
            sentimentScore: sentimentSnapshot?.score,
            sentimentLabel: sentimentSnapshot?.label,
            sentimentConfidence: sentimentSnapshot?.confidence,
            sentimentSummary: sentimentSnapshot?.summary,
            reasons: reasons(reasonContext(from: InsightReasonInputs(
                fund: fund,
                segment: segment,
                segmentGap: segmentGap,
                segmentValue: segmentValue,
                suggestedContribution: suggestedContribution,
                sentimentLabel: sentimentSnapshot?.label,
                ranking: ranking,
                belowAverage: belowAverage,
                yield: yield
            )))
        )
    }

    private struct InsightReasonInputs {
        var fund: Fund
        var segment: FundSegment
        var segmentGap: Double
        var segmentValue: Double
        var suggestedContribution: Decimal?
        var sentimentLabel: SentimentLabel?
        var ranking: RankingInputs
        var belowAverage: Bool
        var yield: Double?
    }

    private static func reasonContext(from inputs: InsightReasonInputs) -> ReasonContext {
        ReasonContext(
            ticker: inputs.fund.ticker,
            segmentGap: inputs.segmentGap,
            currentWeight: inputs.ranking.totalValue > 0
                ? inputs.segmentValue / inputs.ranking.totalValue
                : 0,
            targetWeight: inputs.ranking.targetWeights[inputs.segment] ?? 0,
            suggestedContribution: inputs.suggestedContribution,
            sentimentLabel: inputs.sentimentLabel,
            flags: ReasonFlags(
                belowAverage: inputs.belowAverage,
                yield: inputs.yield,
                lowestTickers: inputs.ranking.lowestTickers,
                bestYield: inputs.ranking.bestYieldBySegment[inputs.segment]
            )
        )
    }

    static func suggestedSegmentContribution(
        segmentGap: Double,
        totalValue: Double,
        targetWeight: Double,
        segmentValue: Double
    ) -> Decimal? {
        guard segmentGap > allocationTolerance, totalValue > 0 else { return nil }
        let targetSegmentValue = Decimal(totalValue) * Decimal(targetWeight)
        let currentSegmentValue = Decimal(segmentValue)
        let amount = targetSegmentValue - currentSegmentValue
        guard amount > 0 else { return nil }
        return roundedCurrency(amount)
    }

    static func roundedCurrency(_ amount: Decimal) -> Decimal {
        var value = amount
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .plain)
        return result
    }

    struct ReasonContext {
        var ticker: String
        var segmentGap: Double
        var currentWeight: Double
        var targetWeight: Double
        var suggestedContribution: Decimal?
        var sentimentLabel: SentimentLabel?
        var flags: ReasonFlags
    }

    struct ReasonFlags {
        var belowAverage: Bool
        var yield: Double?
        var lowestTickers: Set<String>
        var bestYield: Double?
    }

    static func reasons(_ context: ReasonContext) -> [InsightReason] {
        var reasons: [InsightReason] = []
        if context.segmentGap > allocationTolerance {
            reasons.append(
                .segmentUnderweight(
                    currentWeight: context.currentWeight,
                    targetWeight: context.targetWeight
                )
            )
        }
        if let suggestedContribution = context.suggestedContribution {
            reasons.append(.suggestedContribution(amount: suggestedContribution))
        }
        if context.flags.lowestTickers.contains(context.ticker) {
            reasons.append(.lowestWeightInSegment)
        }
        if context.flags.belowAverage {
            reasons.append(.belowAveragePrice)
        }
        if let yield = context.flags.yield,
           let bestYield = context.flags.bestYield,
           abs(yield - bestYield) < 0.000_000_1 {
            reasons.append(.nextPurchaseYield)
        }
        switch context.sentimentLabel {
        case .positive:
            reasons.append(.positiveSentiment)
        case .negative:
            reasons.append(.negativeSentiment)
        case .neutral:
            reasons.append(.neutralSentiment)
        case nil:
            break
        }
        return reasons
    }

    static func lowestWeightTickers(
        in groups: [FundSegment: [Holding]]
    ) -> Set<String> {
        Set(
            groups.values.compactMap { group -> String? in
                guard group.count > 1 else { return nil }
                return group.min { lhs, rhs in
                    if lhs.currentValue != rhs.currentValue {
                        return lhs.currentValue < rhs.currentValue
                    }
                    return (lhs.fund?.ticker ?? "") < (rhs.fund?.ticker ?? "")
                }?.fund?.ticker
            }
        )
    }

    static func bestYields(
        in groups: [FundSegment: [Holding]]
    ) -> [FundSegment: Double] {
        groups.reduce(into: [:]) { partial, entry in
            let yields = entry.value.compactMap(nextPurchaseYield)
            if let best = yields.max() {
                partial[entry.key] = best
            }
        }
    }

    static func nextPurchaseYield(_ holding: Holding) -> Double? {
        guard let fund = holding.fund else { return nil }
        if fund.dividendYield > 0 {
            return fund.dividendYield
        }
        guard fund.currentPrice > 0, fund.lastDividend > 0 else { return nil }
        return double(from: fund.lastDividend / fund.currentPrice)
    }

    static func isHigherRanked(_ lhs: InsightItem, _ rhs: InsightItem) -> Bool {
        if lhs.segmentGap != rhs.segmentGap {
            return lhs.segmentGap > rhs.segmentGap
        }
        if lhs.internalGap != rhs.internalGap {
            return lhs.internalGap > rhs.internalGap
        }
        if lhs.isBelowAverage != rhs.isBelowAverage {
            return lhs.isBelowAverage && !rhs.isBelowAverage
        }
        let leftYield = lhs.nextPurchaseYield ?? -1
        let rightYield = rhs.nextPurchaseYield ?? -1
        if leftYield != rightYield {
            return leftYield > rightYield
        }
        let leftSentiment = lhs.sentimentScore ?? 0
        let rightSentiment = rhs.sentimentScore ?? 0
        if leftSentiment != rightSentiment {
            return leftSentiment > rightSentiment
        }
        return lhs.ticker < rhs.ticker
    }

    static func double(from decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }
}
