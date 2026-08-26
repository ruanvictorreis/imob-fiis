import Foundation

protocol DividendFallbackServing: Sendable {
    func latestDividends(for symbols: [String]) async -> [FIIDividend]
}

struct PortfolioMarketData: Sendable, Equatable {
    var ticker: String
    var price: Decimal?
    var lastDividend: Decimal?
}

protocol PortfolioMarketDataServing: Sendable {
    func latestMarketData(for symbols: [String]) async -> [PortfolioMarketData]
}

struct YahooMarketDataService: DividendFallbackServing, PortfolioMarketDataServing {
    var session: any HTTPPerforming
    var baseURL: URL

    private let maxConcurrentRequests = 4

    init(
        session: any HTTPPerforming = URLSession.shared,
        baseURL: URL = URL(string: "https://query1.finance.yahoo.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func latestDividends(for symbols: [String]) async -> [FIIDividend] {
        var collected: [FIIDividend] = []
        for symbol in symbols where !symbol.isEmpty {
            if let dividend = await latestDividend(for: symbol) {
                collected.append(dividend)
            }
        }
        return collected
    }

    func latestMarketData(for symbols: [String]) async -> [PortfolioMarketData] {
        let symbols = uniqueSymbols(symbols)
        guard !symbols.isEmpty else { return [] }

        return await withTaskGroup(of: PortfolioMarketData?.self, returning: [PortfolioMarketData].self) { group in
            var iterator = symbols.makeIterator()
            for _ in 0 ..< min(maxConcurrentRequests, symbols.count) {
                guard let symbol = iterator.next() else { break }
                group.addTask { await latestMarketData(for: symbol) }
            }

            var snapshots: [PortfolioMarketData] = []
            while let result = await group.next() {
                if let result {
                    snapshots.append(result)
                }
                if let symbol = iterator.next() {
                    group.addTask { await latestMarketData(for: symbol) }
                }
            }
            return snapshots
        }
    }

    private func latestDividend(for symbol: String) async -> FIIDividend? {
        guard let request = makeRequest(for: symbol, range: "6mo", events: "div") else { return nil }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            return FIIDividend(ticker: symbol.uppercased(), chart: decoded)
        } catch {
            return nil
        }
    }

    private func latestMarketData(for symbol: String) async -> PortfolioMarketData? {
        guard let request = makeRequest(for: symbol, range: "6mo", events: "div") else { return nil }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            guard let result = decoded.chart.result?.first else { return nil }
            let dividend = FIIDividend(ticker: symbol.uppercased(), chart: decoded)?.rate
            return PortfolioMarketData(
                ticker: symbol.uppercased(),
                price: result.latestPrice,
                lastDividend: dividend
            )
        } catch {
            return nil
        }
    }

    private func uniqueSymbols(_ symbols: [String]) -> [String] {
        var seen = Set<String>()
        return symbols.filter { symbol in
            !symbol.isEmpty && seen.insert(symbol.uppercased()).inserted
        }
    }

    private func makeRequest(for symbol: String, range: String, events: String? = nil) -> URLRequest? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = "/v8/finance/chart/\(Self.yahooSymbol(for: symbol))"
        var items = [
            URLQueryItem(name: "range", value: range),
            URLQueryItem(name: "interval", value: "1d"),
        ]
        if let events {
            items.append(URLQueryItem(name: "events", value: events))
        }
        components.queryItems = items
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        return request
    }

    static func yahooSymbol(for ticker: String) -> String {
        let trimmed = ticker
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: ".SA", with: "")
        return "\(trimmed).SA"
    }
}

struct BrapiQuoteMarketDataService: PortfolioMarketDataServing {
    let catalog: any FIICatalogServing

    func latestMarketData(for symbols: [String]) async -> [PortfolioMarketData] {
        var snapshots: [PortfolioMarketData] = []
        for symbol in symbols where !symbol.isEmpty {
            guard let quote = try? await catalog.quote(for: symbol), let price = quote.price, price > 0 else {
                continue
            }
            snapshots.append(PortfolioMarketData(ticker: symbol.uppercased(), price: price, lastDividend: nil))
        }
        return snapshots
    }
}

struct FallbackPortfolioMarketDataService: PortfolioMarketDataServing {
    let primary: any PortfolioMarketDataServing
    let fallback: any PortfolioMarketDataServing

    func latestMarketData(for symbols: [String]) async -> [PortfolioMarketData] {
        let primarySnapshots = await primary.latestMarketData(for: symbols)
        var snapshotsByTicker = Dictionary(
            uniqueKeysWithValues: primarySnapshots.map { ($0.ticker.uppercased(), $0) }
        )
        let missingPrice = symbols.filter { symbol in
            guard let snapshot = snapshotsByTicker[symbol.uppercased()] else { return true }
            return (snapshot.price ?? 0) <= 0
        }

        guard !missingPrice.isEmpty else { return primarySnapshots }
        let fallbackSnapshots = await fallback.latestMarketData(for: missingPrice)
        for fallbackSnapshot in fallbackSnapshots {
            let ticker = fallbackSnapshot.ticker.uppercased()
            if var snapshot = snapshotsByTicker[ticker] {
                snapshot.price = fallbackSnapshot.price ?? snapshot.price
                snapshotsByTicker[ticker] = snapshot
            } else {
                snapshotsByTicker[ticker] = fallbackSnapshot
            }
        }
        return symbols.compactMap { snapshotsByTicker[$0.uppercased()] }
    }
}

private struct YahooChartResponse: Decodable {
    var chart: YahooChart
}

private struct YahooChart: Decodable {
    var result: [YahooChartResult]?
}

private struct YahooChartResult: Decodable {
    var meta: YahooChartMeta?
    var indicators: YahooChartIndicators?
    var events: YahooChartEvents?

    var latestPrice: Decimal? {
        let rawPrice = meta?.regularMarketPrice
            ?? indicators?.quote?.first?.close?.reversed().compactMap { $0 }.first
        return rawPrice.flatMap { Decimal(string: String($0)) }
    }
}

private struct YahooChartMeta: Decodable {
    var regularMarketPrice: Double?
}

private struct YahooChartIndicators: Decodable {
    var quote: [YahooChartQuote]?
}

private struct YahooChartQuote: Decodable {
    var close: [Double?]?
}

private struct YahooChartEvents: Decodable {
    var dividends: [String: YahooDividendEvent]?
}

private struct YahooDividendEvent: Decodable {
    var amount: Double
    var date: Int
}

extension FIIDividend {
    fileprivate init?(ticker: String, chart: YahooChartResponse) {
        guard let latest = chart.chart.result?.first?.events?.dividends?.values.max(by: { $0.date < $1.date }),
              let rate = Decimal(string: String(format: "%.8f", latest.amount)),
              rate > 0
        else {
            return nil
        }

        self.init(
            ticker: ticker,
            label: "RENDIMENTO",
            paymentDate: Date(timeIntervalSince1970: TimeInterval(latest.date)),
            lastDatePrior: nil,
            rate: rate
        )
    }
}
