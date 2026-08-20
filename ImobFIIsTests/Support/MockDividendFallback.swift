import Foundation
@testable import ImobFIIs

struct EmptyDividendFallback: DividendFallbackServing {
    func latestDividends(for symbols: [String]) async -> [FIIDividend] {
        _ = symbols
        return []
    }
}

struct MockDividendFallback: DividendFallbackServing {
    var dividends: [FIIDividend]

    func latestDividends(for symbols: [String]) async -> [FIIDividend] {
        dividends.filter { symbols.contains($0.ticker) }
    }
}
