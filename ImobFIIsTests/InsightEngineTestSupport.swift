import Foundation
@testable import ImobFIIs

@MainActor
func makeInsightHolding(
    ticker: String,
    segment: FundSegment,
    shares: Int,
    price: Decimal,
    average: Decimal,
    lastDividend: Decimal = 0,
    dividendYield: Double = 0
) -> Holding {
    let fund = Fund(
        ticker: ticker,
        name: ticker,
        segment: segment,
        manager: "",
        currentPrice: price,
        dividendYield: dividendYield,
        lastDividend: lastDividend
    )
    return Holding(shares: shares, averagePrice: average, fund: fund)
}
