import Foundation
import SwiftData

enum LastDividendSync {
    @MainActor
    static func refreshStaleFunds(
        _ funds: [Fund],
        using catalog: any FIICatalogServing,
        now: Date = .now
    ) async {
        var seen = Set<String>()
        let stale = funds.filter { fund in
            seen.insert(fund.ticker).inserted && LastDividend.isCacheStale(fund, now: now)
        }
        guard !stale.isEmpty else { return }

        let tickers = stale.map(\.ticker)
        let dividends = (try? await catalog.dividends(for: tickers)) ?? []
        let rates = LastDividend.latestRates(from: dividends)

        let missingTickers = stale
            .filter { rates[$0.ticker] == nil && $0.lastDividend == 0 }
            .map(\.ticker)
        let indicators = missingTickers.isEmpty
            ? []
            : ((try? await catalog.indicators(for: missingTickers)) ?? [])
        let indicatorsByTicker = Dictionary(uniqueKeysWithValues: indicators.map { ($0.ticker, $0) })

        for fund in stale {
            if let rate = rates[fund.ticker], rate > 0 {
                apply(rate, to: fund, at: now)
                continue
            }

            if fund.lastDividend == 0 {
                let snapshot = indicatorsByTicker[fund.ticker]
                if let estimate = LastDividend.estimate(
                    price: snapshot?.price ?? fund.currentPrice,
                    yield1m: snapshot?.dividendYield1m
                ) {
                    apply(estimate, to: fund, at: now)
                }
                continue
            }

            fund.lastDividendUpdatedAt = now
        }
    }

    @MainActor
    private static func apply(_ rate: Decimal, to fund: Fund, at date: Date) {
        fund.lastDividend = rate
        fund.lastDividendUpdatedAt = date
    }
}
