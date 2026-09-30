import Foundation

/// Tudo o que o `InsightEngine` lê das posições, da estratégia e das notícias. Se nada disso mudou,
/// o snapshot anterior continua válido.
struct InsightInputs: Equatable {
    struct Position: Equatable {
        var ticker: String
        var shares: Int
        var averagePrice: Decimal
        var segment: FundSegment?
        var currentPrice: Decimal?
        var dividendYield: Double?
        var lastDividend: Decimal?
    }

    var positions: [Position]
    var targetWeights: [FundSegment: Double]
    var orderedSegments: [FundSegment]
    var sentiment: SentimentContext

    @MainActor
    init(holdings: [Holding], strategy: some AllocationStrategy, sentiment: SentimentContext) {
        positions = holdings.map { holding in
            let fund = holding.fund
            return Position(
                ticker: holding.ticker,
                shares: holding.shares,
                averagePrice: holding.averagePrice,
                segment: fund?.segment,
                currentPrice: fund?.currentPrice,
                dividendYield: fund?.dividendYield,
                lastDividend: fund?.lastDividend
            )
        }
        targetWeights = strategy.targetWeights
        orderedSegments = strategy.orderedSegments
        self.sentiment = sentiment
    }
}

/// Guarda o último snapshot dos Insights para a tela não refazer o cálculo a cada renderização.
@MainActor
final class InsightSnapshotCache {
    private var cachedInputs: InsightInputs?
    private var cachedSnapshot: InsightSnapshot?
    private(set) var evaluationCount = 0

    func snapshot(
        for holdings: [Holding],
        strategy: some AllocationStrategy,
        sentiment: SentimentContext
    ) -> InsightSnapshot {
        let inputs = InsightInputs(holdings: holdings, strategy: strategy, sentiment: sentiment)
        if let cachedSnapshot, cachedInputs == inputs {
            return cachedSnapshot
        }
        let snapshot = InsightEngine.evaluate(holdings, strategy: strategy, sentiment: sentiment)
        cachedInputs = inputs
        cachedSnapshot = snapshot
        evaluationCount += 1
        return snapshot
    }
}
