@testable import ImobFIIs

/// Pesos fixos para os testes do `InsightEngine` não dependerem da alocação padrão do app.
enum TestAllocationStrategy {
    static let classic = CustomAllocationStrategy(
        targetWeights: [
            .paper: 0.30,
            .urban: 0.20,
            .logistics: 0.20,
            .malls: 0.15,
            .offices: 0.10,
            .fiagro: 0.05,
        ],
        orderedSegments: [
            .paper,
            .urban,
            .logistics,
            .malls,
            .offices,
            .fiagro,
            .hybrid,
            .fundsOfFunds,
            .residential,
            .other,
        ]
    )
}
