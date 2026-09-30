import Foundation

/// Catálogo da brapi com duas reservas: o Yahoo quando a brapi não entrega cotação ou indicadores
/// (plano gratuito), e o último dado salvo em cache quando nenhuma fonte responde.
struct ResilientFIICatalogService: FIICatalogServing {
    var primary: any FIICatalogServing
    var fallback: any FundMarketSnapshotServing
    var cache: MarketDataCache
    var now: @Sendable () -> Date

    private let maxConcurrentFallbackRequests = 4

    init(
        primary: any FIICatalogServing = BrapiFIICatalogService(),
        fallback: any FundMarketSnapshotServing = YahooMarketDataService(),
        cache: MarketDataCache = .shared,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.primary = primary
        self.fallback = fallback
        self.cache = cache
        self.now = now
    }

    func tickers(_ query: FIITickerQuery) async throws -> FIITickerPage {
        do {
            let page = try await primary.tickers(query)
            if !page.funds.isEmpty {
                await cache.store(page, forKey: query.cacheKey, at: now())
            }
            return page
        } catch {
            if let cached = await cache.tickerPage(forKey: query.cacheKey) {
                return cached.value
            }
            throw error
        }
    }

    func quote(for symbol: String) async throws -> FundQuote? {
        if let quote = try? await primary.quote(for: symbol), (quote.price ?? 0) > 0 {
            await cache.store(quote, at: now())
            return quote
        }
        if let snapshot = await fallback.marketSnapshot(for: symbol) {
            await store(snapshot)
            return snapshot.quote
        }
        guard let cached = await cache.quote(for: symbol) else { return nil }
        var quote = cached.value
        quote.cachedAt = cached.savedAt
        return quote
    }

    func indicators(for symbols: [String]) async throws -> [FIIIndicators] {
        let unique = uniqueSymbols(symbols)
        guard !unique.isEmpty else { return [] }

        let fresh = (try? await primary.indicators(for: unique)) ?? []
        await cache.store(fresh, at: now())

        let found = Set(fresh.map { $0.ticker.uppercased() })
        let missing = unique.filter { !found.contains($0) }
        let snapshots = await fallbackSnapshots(for: missing)

        var results = fresh
        for symbol in missing {
            if let snapshot = snapshots[symbol] {
                results.append(await store(snapshot))
            } else if let cached = await cache.indicators(for: symbol) {
                results.append(cached.value)
            }
        }
        return results
    }

    func dividends(for symbols: [String]) async throws -> [FIIDividend] {
        try await primary.dividends(for: symbols)
    }

    /// Indicadores que só a brapi tem (P/VP, vacância) continuam os do cache; preço e DY vêm do Yahoo.
    static func merge(_ fresh: FIIIndicators, over cached: FIIIndicators?) -> FIIIndicators {
        guard var merged = cached else { return fresh }
        merged.price = fresh.price ?? merged.price
        merged.dividendYield12m = fresh.dividendYield12m ?? merged.dividendYield12m
        merged.dividendYield1m = fresh.dividendYield1m ?? merged.dividendYield1m
        merged.name = merged.name ?? fresh.name
        if let price = merged.price, let nav = merged.navPerShare, nav > 0 {
            merged.priceToNav = NSDecimalNumber(decimal: price / nav).doubleValue
        }
        return merged
    }

    @discardableResult
    private func store(_ snapshot: FundMarketSnapshot) async -> FIIIndicators {
        let merged = Self.merge(snapshot.indicators, over: await cache.indicators(for: snapshot.quote.ticker)?.value)
        await cache.store(snapshot.quote, at: now())
        await cache.store([merged], at: now())
        return merged
    }

    private func fallbackSnapshots(for symbols: [String]) async -> [String: FundMarketSnapshot] {
        guard !symbols.isEmpty else { return [:] }
        let fallback = fallback
        return await withTaskGroup(of: (String, FundMarketSnapshot?).self) { group in
            var iterator = symbols.makeIterator()
            for _ in 0 ..< min(maxConcurrentFallbackRequests, symbols.count) {
                guard let symbol = iterator.next() else { break }
                group.addTask { (symbol, await fallback.marketSnapshot(for: symbol)) }
            }

            var snapshots: [String: FundMarketSnapshot] = [:]
            while let (symbol, snapshot) = await group.next() {
                snapshots[symbol] = snapshot
                if let next = iterator.next() {
                    group.addTask { (next, await fallback.marketSnapshot(for: next)) }
                }
            }
            return snapshots
        }
    }

    private func uniqueSymbols(_ symbols: [String]) -> [String] {
        var seen = Set<String>()
        return symbols
            .map { $0.uppercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

extension FIITickerQuery {
    var cacheKey: String {
        urlQueryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
    }
}
