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
        .urban,
        .offices,
        .fiagro,
        .hybrid,
        .fundsOfFunds,
        .residential,
        .other,
    ]

    /// Baseada na composição por segmento do IFIX (carteira set–dez/2026), em múltiplos de 5%.
    /// A fatia de híbridos e multiestratégia do índice foi para Renda Urbana e Fiagro.
    let targetWeights: [FundSegment: Double] = [
        .paper: 0.35,
        .logistics: 0.20,
        .malls: 0.15,
        .urban: 0.15,
        .offices: 0.10,
        .fiagro: 0.05,
        .hybrid: 0,
        .fundsOfFunds: 0,
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
