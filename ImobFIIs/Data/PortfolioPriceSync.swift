import Foundation
import SwiftData

enum PortfolioPriceSyncOutcome: Equatable, Sendable {
    case skipped
    case updated
    case failed
}

extension Notification.Name {
    static let portfolioMarketDataDidSync = Notification.Name("portfolioMarketDataDidSync")
}

@MainActor
enum PortfolioPriceSync {
    static let minimumInterval: TimeInterval = 15 * 60
    static let dividendMinimumInterval: TimeInterval = 60 * 60 * 24
    static let priceStorageKey = "portfolio.priceRefreshAtByTicker"
    static let dividendStorageKey = "portfolio.dividendRefreshAtByTicker"
    static let outcomeUserInfoKey = "outcome"

    private static var isRefreshing = false

    @discardableResult
    static func refreshIfNeeded(
        _ funds: [Fund],
        using marketDataSource: any PortfolioMarketDataServing = YahooMarketDataService(),
        defaults: UserDefaults = .standard,
        now: Date = .now,
        force: Bool = false,
        postsNotification: Bool = true
    ) async -> PortfolioPriceSyncOutcome {
        guard !isRefreshing else { return .skipped }

        let plan = refreshPlan(for: funds, defaults: defaults, now: now, force: force)
        guard !plan.fundsToRefresh.isEmpty else { return .skipped }

        isRefreshing = true
        defer { isRefreshing = false }

        let snapshots = await marketDataSource.latestMarketData(for: plan.fundsToRefresh.map(\.ticker))
        guard !snapshots.isEmpty else {
            return finish(.failed, postsNotification: postsNotification)
        }

        let pricesUpdated = apply(
            snapshots: snapshots,
            plan: plan,
            defaults: defaults,
            now: now,
            force: force
        )
        let outcome: PortfolioPriceSyncOutcome =
            !plan.fundsNeedingPrice.isEmpty && pricesUpdated == 0 ? .failed : .updated
        return finish(outcome, postsNotification: postsNotification)
    }

    static func lastPriceRefreshDate(for funds: [Fund], defaults: UserDefaults = .standard) -> Date? {
        let dates = refreshDates(forKey: priceStorageKey, defaults: defaults)
        return funds.compactMap { dates[$0.ticker] }.max()
    }

    private struct RefreshPlan {
        var fundsToRefresh: [Fund]
        var fundsNeedingPrice: [Fund]
        var priceRefreshDates: [String: Date]
        var dividendRefreshDates: [String: Date]
    }

    private static func refreshPlan(
        for funds: [Fund],
        defaults: UserDefaults,
        now: Date,
        force: Bool
    ) -> RefreshPlan {
        var seen = Set<String>()
        let unique = funds.filter { seen.insert($0.ticker).inserted }
        let priceRefreshDates = refreshDates(forKey: priceStorageKey, defaults: defaults)
        let dividendRefreshDates = refreshDates(forKey: dividendStorageKey, defaults: defaults)
        let fundsNeedingPrice = unique.filter {
            shouldRefreshPrice($0.ticker, dates: priceRefreshDates, now: now, force: force)
        }
        let fundsNeedingDividend = unique.filter {
            shouldRefreshDividend($0.ticker, dates: dividendRefreshDates, now: now, force: force)
        }
        var fundsToRefreshByTicker: [String: Fund] = [:]
        for fund in fundsNeedingPrice + fundsNeedingDividend {
            fundsToRefreshByTicker[fund.ticker] = fund
        }
        return RefreshPlan(
            fundsToRefresh: Array(fundsToRefreshByTicker.values),
            fundsNeedingPrice: fundsNeedingPrice,
            priceRefreshDates: priceRefreshDates,
            dividendRefreshDates: dividendRefreshDates
        )
    }

    private static func apply(
        snapshots: [PortfolioMarketData],
        plan: RefreshPlan,
        defaults: UserDefaults,
        now: Date,
        force: Bool
    ) -> Int {
        let snapshotsByTicker = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.ticker, $0) })
        var updatedPriceDates = plan.priceRefreshDates
        var updatedDividendDates = plan.dividendRefreshDates
        var pricesUpdated = 0

        for fund in plan.fundsToRefresh {
            guard let snapshot = snapshotsByTicker[fund.ticker] else { continue }
            if shouldRefreshPrice(fund.ticker, dates: plan.priceRefreshDates, now: now, force: force),
               let price = snapshot.price,
               price > 0 {
                fund.currentPrice = price
                updatedPriceDates[fund.ticker] = now
                pricesUpdated += 1
            }
            if shouldRefreshDividend(fund.ticker, dates: plan.dividendRefreshDates, now: now, force: force) {
                if let dividend = snapshot.lastDividend, dividend > 0 {
                    fund.lastDividend = dividend
                    fund.lastDividendUpdatedAt = now
                }
                updatedDividendDates[fund.ticker] = now
            }
        }

        defaults.set(updatedPriceDates.mapValues(\.timeIntervalSinceReferenceDate), forKey: priceStorageKey)
        defaults.set(updatedDividendDates.mapValues(\.timeIntervalSinceReferenceDate), forKey: dividendStorageKey)
        return pricesUpdated
    }

    private static func finish(
        _ outcome: PortfolioPriceSyncOutcome,
        postsNotification: Bool
    ) -> PortfolioPriceSyncOutcome {
        if postsNotification {
            NotificationCenter.default.post(
                name: .portfolioMarketDataDidSync,
                object: nil,
                userInfo: [outcomeUserInfoKey: outcome]
            )
        }
        return outcome
    }

    private static func shouldRefreshPrice(
        _ ticker: String,
        dates: [String: Date],
        now: Date,
        force: Bool
    ) -> Bool {
        force || isStale(ticker, in: dates, minimumInterval: minimumInterval, now: now)
    }

    private static func shouldRefreshDividend(
        _ ticker: String,
        dates: [String: Date],
        now: Date,
        force: Bool
    ) -> Bool {
        force || isStale(ticker, in: dates, minimumInterval: dividendMinimumInterval, now: now)
    }

    private static func isStale(
        _ ticker: String,
        in dates: [String: Date],
        minimumInterval: TimeInterval,
        now: Date
    ) -> Bool {
        guard let lastRefresh = dates[ticker] else { return true }
        return now.timeIntervalSince(lastRefresh) >= minimumInterval
    }

    private static func refreshDates(forKey key: String, defaults: UserDefaults) -> [String: Date] {
        let raw = defaults.dictionary(forKey: key) as? [String: Double] ?? [:]
        return raw.mapValues(Date.init(timeIntervalSinceReferenceDate:))
    }

    static func resetSessionStateForTesting() {
        isRefreshing = false
    }
}
