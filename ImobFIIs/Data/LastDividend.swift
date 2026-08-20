import Foundation

enum LastDividend {
    static let cacheTTL: TimeInterval = 60 * 60 * 24

    static func estimate(price: Decimal?, yield1m: Double?) -> Decimal? {
        guard let price, price > 0, let yield1m, yield1m > 0 else { return nil }
        return price * Decimal(yield1m)
    }

    static func latestRate(from dividends: [FIIDividend]) -> Decimal? {
        let income = dividends.filter(\.isIncome)
        let pool = income.isEmpty ? dividends : income
        return pool
            .sorted { lhs, rhs in
                (lhs.sortDate ?? .distantPast) > (rhs.sortDate ?? .distantPast)
            }
            .first { $0.rate > 0 }?
            .rate
    }

    static func latestRates(from dividends: [FIIDividend]) -> [String: Decimal] {
        Dictionary(grouping: dividends, by: \.ticker)
            .compactMapValues { latestRate(from: $0) }
    }

    static func resolved(
        dividends: [FIIDividend],
        price: Decimal?,
        yield1m: Double?
    ) -> Decimal? {
        latestRate(from: dividends) ?? estimate(price: price, yield1m: yield1m)
    }

    static func isCacheStale(_ fund: Fund, now: Date = .now) -> Bool {
        guard let updatedAt = fund.lastDividendUpdatedAt else { return true }
        return now.timeIntervalSince(updatedAt) >= cacheTTL
    }
}
