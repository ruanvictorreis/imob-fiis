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
    var reasons: [InsightReason]
}

enum InsightReason: Equatable {
    case segmentUnderweight(currentWeight: Double, targetWeight: Double)
    case lowestWeightInSegment
    case belowAveragePrice
    case nextPurchaseYield
    case suggestedContribution(amount: Decimal)
}

enum InsightEngine {
    /// Faixa de tolerância em pontos percentuais (ex.: 0.02 = 2 p.p.).
    static let allocationTolerance = 0.02

    static func evaluate(
        _ holdings: [Holding],
        strategy: some AllocationStrategy
    ) -> InsightSnapshot {
        let totalValue = max(double(from: holdings.currentValue), 0)
        let valueBySegment = segmentValues(in: holdings)
        let allocations = makeAllocations(
            strategy: strategy,
            totalValue: totalValue,
            valueBySegment: valueBySegment
        )
        let insights = makeInsights(
            holdings: holdings,
            strategy: strategy,
            totalValue: totalValue,
            valueBySegment: valueBySegment,
            allocations: allocations
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

    private static func makeInsights(
        holdings: [Holding],
        strategy: some AllocationStrategy,
        totalValue: Double,
        valueBySegment: [FundSegment: Double],
        allocations: [SegmentAllocation]
    ) -> [InsightItem] {
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
            bestYieldBySegment: bestYieldBySegment
        )

        return eligible.compactMap { holding in
            let peers = eligibleBySegment[holding.fund?.segment ?? .other]?.count ?? 1
            return insight(for: holding, peers: peers, ranking: ranking)
        }
        .sorted(by: isHigherRanked)
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

    private struct RankingInputs {
        var totalValue: Double
        var valueBySegment: [FundSegment: Double]
        var gapBySegment: [FundSegment: Double]
        var targetWeights: [FundSegment: Double]
        var lowestTickers: Set<String>
        var bestYieldBySegment: [FundSegment: Double]
    }

    private static func insight(
        for holding: Holding,
        peers: Int,
        ranking: RankingInputs
    ) -> InsightItem? {
        guard let fund = holding.fund else { return nil }
        let segment = fund.segment
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

        return InsightItem(
            ticker: fund.ticker,
            segment: segment,
            currentValue: holding.currentValue,
            segmentGap: segmentGap,
            internalGap: (1 / Double(max(peers, 1))) - internalWeight,
            isBelowAverage: belowAverage,
            nextPurchaseYield: yield,
            suggestedSegmentContribution: suggestedContribution,
            reasons: reasons(
                ReasonContext(
                    ticker: fund.ticker,
                    segmentGap: segmentGap,
                    currentWeight: ranking.totalValue > 0 ? segmentValue / ranking.totalValue : 0,
                    targetWeight: ranking.targetWeights[segment] ?? 0,
                    suggestedContribution: suggestedContribution,
                    flags: ReasonFlags(
                        belowAverage: belowAverage,
                        yield: yield,
                        lowestTickers: ranking.lowestTickers,
                        bestYield: ranking.bestYieldBySegment[segment]
                    )
                )
            )
        )
    }

    private static func suggestedSegmentContribution(
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

    private static func roundedCurrency(_ amount: Decimal) -> Decimal {
        var value = amount
        var result = Decimal()
        NSDecimalRound(&result, &value, 2, .plain)
        return result
    }

    private struct ReasonContext {
        var ticker: String
        var segmentGap: Double
        var currentWeight: Double
        var targetWeight: Double
        var suggestedContribution: Decimal?
        var flags: ReasonFlags
    }

    private struct ReasonFlags {
        var belowAverage: Bool
        var yield: Double?
        var lowestTickers: Set<String>
        var bestYield: Double?
    }

    private static func reasons(_ context: ReasonContext) -> [InsightReason] {
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
        return reasons
    }

    private static func lowestWeightTickers(
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

    private static func bestYields(
        in groups: [FundSegment: [Holding]]
    ) -> [FundSegment: Double] {
        groups.reduce(into: [:]) { partial, entry in
            let yields = entry.value.compactMap(nextPurchaseYield)
            if let best = yields.max() {
                partial[entry.key] = best
            }
        }
    }

    private static func nextPurchaseYield(_ holding: Holding) -> Double? {
        guard let fund = holding.fund else { return nil }
        if fund.dividendYield > 0 {
            return fund.dividendYield
        }
        guard fund.currentPrice > 0, fund.lastDividend > 0 else { return nil }
        return double(from: fund.lastDividend / fund.currentPrice)
    }

    private static func isHigherRanked(_ lhs: InsightItem, _ rhs: InsightItem) -> Bool {
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
        return lhs.ticker < rhs.ticker
    }

    private static func double(from decimal: Decimal) -> Double {
        NSDecimalNumber(decimal: decimal).doubleValue
    }
}
