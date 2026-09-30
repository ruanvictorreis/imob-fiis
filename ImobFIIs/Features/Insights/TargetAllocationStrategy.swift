import Foundation

protocol AllocationStrategy: Sendable {
    var id: String { get }
    var title: String { get }
    var targetWeights: [FundSegment: Double] { get }
    var orderedSegments: [FundSegment] { get }
}

struct BalancedRetailStrategy: AllocationStrategy {
    let id = "balanced-retail"

    var title: String { L10n.Insights.balancedStrategy }

    let orderedSegments: [FundSegment] = [
        .paper,
        .logistics,
        .malls,
        .hybrid,
        .offices,
        .urban,
        .fundsOfFunds,
        .fiagro,
        .residential,
        .other,
    ]

    /// Composição por segmento do IFIX (carteira set–dez/2026), arredondada para múltiplos de 5%.
    /// Multiestratégia entra em Híbrido; Fiagro não faz parte do índice.
    let targetWeights: [FundSegment: Double] = [
        .paper: 0.35,
        .logistics: 0.20,
        .malls: 0.15,
        .hybrid: 0.15,
        .offices: 0.10,
        .urban: 0.05,
        .fundsOfFunds: 0,
        .fiagro: 0,
        .residential: 0,
        .other: 0,
    ]
}

struct CustomAllocationStrategy: AllocationStrategy {
    let id = "custom-allocation"
    let targetWeights: [FundSegment: Double]
    let orderedSegments: [FundSegment]

    var title: String {
        targetWeights == BalancedRetailStrategy().targetWeights
            ? L10n.Insights.balancedStrategy
            : L10n.Insights.customStrategy
    }

    init(
        targetWeights: [FundSegment: Double],
        orderedSegments: [FundSegment] = BalancedRetailStrategy().orderedSegments
    ) {
        self.orderedSegments = orderedSegments
        self.targetWeights = Dictionary(
            uniqueKeysWithValues: orderedSegments.map { segment in
                (segment, targetWeights[segment] ?? 0)
            }
        )
    }
}
