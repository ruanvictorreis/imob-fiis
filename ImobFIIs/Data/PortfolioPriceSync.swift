import Foundation
import SwiftData

@MainActor
enum PortfolioPriceSync {
    static let minimumInterval: TimeInterval = 15 * 60
    static let storageKey = "portfolio.priceRefreshAt"
    private static let chunkSize = 20

    private static var didRefreshThisSession = false

    static func refreshIfNeeded(
        _ funds: [Fund],
        using catalog: any FIICatalogServing,
        defaults: UserDefaults = .standard,
        now: Date = .now
    ) async {
        guard !didRefreshThisSession else { return }

        var seen = Set<String>()
        let unique = funds.filter { fund in
            seen.insert(fund.ticker).inserted
        }
        guard !unique.isEmpty else { return }

        if let lastRefresh = defaults.object(forKey: storageKey) as? Date,
           now.timeIntervalSince(lastRefresh) < minimumInterval {
            didRefreshThisSession = true
            return
        }

        didRefreshThisSession = true

        let tickers = unique.map(\.ticker)
        var indicatorsByTicker: [String: FIIIndicators] = [:]
        for chunk in chunked(tickers, into: chunkSize) {
            let indicators = (try? await catalog.indicators(for: chunk)) ?? []
            for indicator in indicators {
                indicatorsByTicker[indicator.ticker] = indicator
            }
        }

        guard !indicatorsByTicker.isEmpty else { return }

        for fund in unique {
            guard let snapshot = indicatorsByTicker[fund.ticker] else { continue }
            apply(snapshot, to: fund)
        }

        defaults.set(now, forKey: storageKey)
    }

    @discardableResult
    static func apply(_ snapshot: FIIIndicators, to fund: Fund) -> Bool {
        var didChange = false
        if let price = snapshot.price, price > 0, fund.currentPrice != price {
            fund.currentPrice = price
            didChange = true
        }
        if let yield = snapshot.dividendYield12m, fund.dividendYield != yield {
            fund.dividendYield = yield
            didChange = true
        }
        return didChange
    }

    static func resetSessionStateForTesting() {
        didRefreshThisSession = false
    }

    private static func chunked(_ values: [String], into size: Int) -> [[String]] {
        stride(from: 0, to: values.count, by: size).map {
            Array(values[$0 ..< min($0 + size, values.count)])
        }
    }
}
