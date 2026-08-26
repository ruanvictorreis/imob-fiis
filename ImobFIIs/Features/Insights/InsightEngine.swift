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
}
