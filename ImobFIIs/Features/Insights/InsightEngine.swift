import Foundation

struct InsightSnapshot: Equatable {
    var allocations: [SegmentAllocation]
    var insights: [InsightItem]
    var missingSegments: [MissingSegmentInsight]
}

struct SegmentAllocation: Identifiable, Equatable {
    var id: FundSegment { segment }

    var segment: FundSegment
    var currentWeight: Double
    var targetWeight: Double

    var gap: Double { targetWeight - currentWeight }

    func isUnderweight(tolerance: Double) -> Bool {
        gap > tolerance
    }
}

struct MissingSegmentInsight: Identifiable, Equatable {
    var id: FundSegment { segment }

    var segment: FundSegment
    var currentWeight: Double
    var targetWeight: Double
    var suggestedContribution: Decimal?

    var gap: Double { targetWeight - currentWeight }
}

struct InsightItem: Identifiable, Equatable {
    var id: String { ticker }

    var ticker: String
    var segment: FundSegment
    var currentValue: Decimal
    var segmentGap: Double
    var internalGap: Double
    var isBelowAverage: Bool
    var nextPurchaseYield: Double?
    var suggestedSegmentContribution: Decimal?
    var sentimentScore: Double?
    var sentimentLabel: SentimentLabel?
    var sentimentConfidence: SentimentConfidence?
    var sentimentSummary: String?
    var reasons: [InsightReason]
}

enum InsightReason: Equatable {
    case segmentUnderweight(currentWeight: Double, targetWeight: Double)
    case lowestWeightInSegment
    case belowAveragePrice
    case nextPurchaseYield
    case suggestedContribution(amount: Decimal)
    case positiveSentiment
    case negativeSentiment
    case neutralSentiment
}

enum InsightEngine {
    /// Faixa de tolerância em pontos percentuais (ex.: 0.02 = 2 p.p.).
    static let allocationTolerance = 0.02

    static func evaluate(
        _ holdings: [Holding],
        strategy: some AllocationStrategy,
        sentiment: SentimentContext = .empty
    ) -> InsightSnapshot {
        let totalValue = max(double(from: holdings.currentValue), 0)
        let valueBySegment = segmentValues(in: holdings)
        let allocations = makeAllocations(
            strategy: strategy,
            totalValue: totalValue,
            valueBySegment: valueBySegment
        )
        let insights = makeInsights(
            InsightBuildInputs(
                holdings: holdings,
                strategy: strategy,
                totalValue: totalValue,
                valueBySegment: valueBySegment,
                allocations: allocations,
                sentiment: sentiment
            )
        )
        let missingSegments = makeMissingSegments(
            holdings: holdings,
            totalValue: totalValue,
            valueBySegment: valueBySegment,
            allocations: allocations
        )

        return InsightSnapshot(
            allocations: allocations,
            insights: insights,
            missingSegments: missingSegments
        )
    }

    private static func segmentValues(in holdings: [Holding]) -> [FundSegment: Double] {
        holdings.reduce(into: [:]) { partial, holding in
            guard let segment = holding.fund?.segment else { return }
            partial[segment, default: 0] += double(from: holding.currentValue)
        }
    }

    private static func makeAllocations(
        strategy: some AllocationStrategy,
        totalValue: Double,
        valueBySegment: [FundSegment: Double]
    ) -> [SegmentAllocation] {
        strategy.orderedSegments.map { segment in
            let current = totalValue > 0 ? (valueBySegment[segment] ?? 0) / totalValue : 0
            return SegmentAllocation(
                segment: segment,
                currentWeight: current,
                targetWeight: strategy.targetWeights[segment] ?? 0
            )
        }
    }

    private struct InsightBuildInputs {
        var holdings: [Holding]
        var strategy: any AllocationStrategy
        var totalValue: Double
        var valueBySegment: [FundSegment: Double]
        var allocations: [SegmentAllocation]
        var sentiment: SentimentContext
    }

    private static func makeInsights(_ inputs: InsightBuildInputs) -> [InsightItem] {
        let holdings = inputs.holdings
        let strategy = inputs.strategy
        let totalValue = inputs.totalValue
        let valueBySegment = inputs.valueBySegment
        let allocations = inputs.allocations
        let sentiment = inputs.sentiment
        let targetSegments = Set(strategy.orderedSegments)
        let gapBySegment = Dictionary(
            uniqueKeysWithValues: allocations.map { ($0.segment, $0.gap) }
        )
        let eligible = holdings.filter { holding in
            guard let segment = holding.fund?.segment else { return false }
            guard targetSegments.contains(segment) else { return false }
            return (strategy.targetWeights[segment] ?? 0) > 0
        }
        let eligibleBySegment = Dictionary(grouping: eligible) { holding in
            holding.fund?.segment ?? .other
        }
        let lowestTickers = lowestWeightTickers(in: eligibleBySegment)
        let bestYieldBySegment = bestYields(in: eligibleBySegment)

        let ranking = RankingInputs(
            totalValue: totalValue,
            valueBySegment: valueBySegment,
            gapBySegment: gapBySegment,
            targetWeights: strategy.targetWeights,
            lowestTickers: lowestTickers,
            bestYieldBySegment: bestYieldBySegment,
            sentiment: sentiment
        )

        let ranked = eligible.compactMap { holding in
            let peers = eligibleBySegment[holding.fund?.segment ?? .other]?.count ?? 1
            return insight(for: holding, peers: peers, ranking: ranking)
        }
        .sorted(by: isHigherRanked)

        return applyTopPickGuard(ranked)
    }

    static func applyTopPickGuard(_ insights: [InsightItem]) -> [InsightItem] {
        guard let firstIndex = insights.firstIndex(where: { !isBlockedTopPick($0) }) else {
            return insights
        }
        guard firstIndex > 0 else { return insights }
        var reordered = insights
        let preferred = reordered.remove(at: firstIndex)
        reordered.insert(preferred, at: 0)
        return reordered
    }

    static func isBlockedTopPick(_ item: InsightItem) -> Bool {
        guard let score = item.sentimentScore,
              let confidence = item.sentimentConfidence else { return false }
        return score < -0.4 && confidence != .low
    }

    private static func makeMissingSegments(
        holdings: [Holding],
        totalValue: Double,
        valueBySegment: [FundSegment: Double],
        allocations: [SegmentAllocation]
    ) -> [MissingSegmentInsight] {
        let heldSegments = Set(holdings.compactMap(\.fund?.segment))

        return allocations.compactMap { allocation -> MissingSegmentInsight? in
            guard allocation.targetWeight > 0 else { return nil }
            guard allocation.isUnderweight(tolerance: allocationTolerance) else { return nil }
            guard !heldSegments.contains(allocation.segment) else { return nil }

            let segmentValue = valueBySegment[allocation.segment] ?? 0
            return MissingSegmentInsight(
                segment: allocation.segment,
                currentWeight: allocation.currentWeight,
                targetWeight: allocation.targetWeight,
                suggestedContribution: suggestedSegmentContribution(
                    segmentGap: allocation.gap,
                    totalValue: totalValue,
                    targetWeight: allocation.targetWeight,
                    segmentValue: segmentValue
                )
            )
        }
        .sorted { lhs, rhs in
            if lhs.gap != rhs.gap {
                return lhs.gap > rhs.gap
            }
            return lhs.segment.rawValue < rhs.segment.rawValue
        }
    }
}
