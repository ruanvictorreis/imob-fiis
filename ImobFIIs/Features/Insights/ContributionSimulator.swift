import Foundation

struct SegmentContribution: Identifiable, Equatable {
    var id: FundSegment { segment }

    var segment: FundSegment
    var amount: Decimal
    var currentWeight: Double
    var projectedWeight: Double
    var targetWeight: Double
}

enum ContributionSimulator {
    /// Distribui o aporte entre os segmentos com meta, primeiro reduzindo as diferenças para a meta
    /// (calculadas sobre o patrimônio já somado ao aporte) e depois, se sobrar, na proporção das metas.
    static func simulate(
        amount: Decimal,
        holdings: [Holding],
        strategy: some AllocationStrategy
    ) -> [SegmentContribution] {
        let amountCents = cents(from: amount)
        let segments = strategy.orderedSegments.filter { (strategy.targetWeights[$0] ?? 0) > 0 }
        guard amountCents > 0, !segments.isEmpty else { return [] }

        let valueBySegment = holdings.reduce(into: [FundSegment: Double]()) { partial, holding in
            guard let segment = holding.fund?.segment else { return }
            partial[segment, default: 0] += InsightEngine.double(from: holding.currentValue)
        }
        let totalValue = valueBySegment.values.reduce(0, +)
        let contribution = Double(amountCents) / 100
        let projectedTotal = totalValue + contribution

        let shares = rawShares(
            segments: segments,
            targets: strategy.targetWeights,
            valueBySegment: valueBySegment,
            contribution: contribution,
            projectedTotal: projectedTotal
        )
        let centsBySegment = roundedCents(shares, totalCents: amountCents, order: segments)

        return segments.compactMap { segment -> SegmentContribution? in
            guard let segmentCents = centsBySegment[segment], segmentCents > 0 else { return nil }
            let value = valueBySegment[segment] ?? 0
            let segmentAmount = Decimal(segmentCents) / 100
            return SegmentContribution(
                segment: segment,
                amount: segmentAmount,
                currentWeight: totalValue > 0 ? value / totalValue : 0,
                projectedWeight: (value + Double(segmentCents) / 100) / projectedTotal,
                targetWeight: strategy.targetWeights[segment] ?? 0
            )
        }
        .sorted { lhs, rhs in
            if lhs.amount != rhs.amount {
                return lhs.amount > rhs.amount
            }
            return (segments.firstIndex(of: lhs.segment) ?? 0) < (segments.firstIndex(of: rhs.segment) ?? 0)
        }
    }

    private static func rawShares(
        segments: [FundSegment],
        targets: [FundSegment: Double],
        valueBySegment: [FundSegment: Double],
        contribution: Double,
        projectedTotal: Double
    ) -> [FundSegment: Double] {
        let deficits = Dictionary(uniqueKeysWithValues: segments.map { segment in
            let target = (targets[segment] ?? 0) * projectedTotal
            return (segment, max(target - (valueBySegment[segment] ?? 0), 0))
        })
        let totalDeficit = deficits.values.reduce(0, +)

        if totalDeficit >= contribution, totalDeficit > 0 {
            return deficits.mapValues { contribution * $0 / totalDeficit }
        }

        let remainder = contribution - totalDeficit
        let totalTarget = segments.reduce(0) { $0 + (targets[$1] ?? 0) }
        return Dictionary(uniqueKeysWithValues: segments.map { segment in
            let extra = remainder * (targets[segment] ?? 0) / totalTarget
            return (segment, (deficits[segment] ?? 0) + extra)
        })
    }

    /// Arredonda para centavos garantindo que a soma bata exatamente com o aporte.
    private static func roundedCents(
        _ shares: [FundSegment: Double],
        totalCents: Int,
        order: [FundSegment]
    ) -> [FundSegment: Int] {
        var result: [FundSegment: Int] = [:]
        var remainders: [(segment: FundSegment, fraction: Double)] = []
        for segment in order {
            let exact = (shares[segment] ?? 0) * 100
            let floored = Int(exact.rounded(.down))
            result[segment] = floored
            remainders.append((segment, exact - Double(floored)))
        }

        var leftover = totalCents - result.values.reduce(0, +)
        for entry in remainders.sorted(by: { $0.fraction > $1.fraction }) where leftover > 0 {
            result[entry.segment, default: 0] += 1
            leftover -= 1
        }
        return result
    }

    private static func cents(from amount: Decimal) -> Int {
        var value = amount * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }
}
