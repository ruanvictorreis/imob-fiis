import Foundation
@testable import ImobFIIs

enum TestFunds {
    static func make(
        ticker: String = "MXRF11",
        price: Decimal = 10,
        lastDividend: Decimal = 0,
        updatedAt: Date? = nil
    ) -> Fund {
        Fund(
            ticker: ticker,
            name: ticker,
            segment: .paper,
            manager: "",
            currentPrice: price,
            dividendYield: 0,
            lastDividend: lastDividend,
            lastDividendUpdatedAt: updatedAt
        )
    }
}
