import Foundation

/// Últimos dados de mercado que chegaram de alguma fonte, gravados em `Caches/`.
/// Servem de reserva quando brapi e Yahoo falham (sem rede, limite do plano).
actor MarketDataCache {
    struct Entry<Value: Codable & Sendable>: Codable, Sendable {
        var value: Value
        var savedAt: Date
    }

    private struct Contents: Codable {
        var quotes: [String: Entry<FundQuote>] = [:]
        var indicators: [String: Entry<FIIIndicators>] = [:]
        var tickerPages: [String: Entry<FIITickerPage>] = [:]
    }

    static let shared = MarketDataCache(fileURL: URL.cachesDirectory.appending(path: "market-data-cache.json"))

    private let fileURL: URL?
    private var loadedContents: Contents?

    /// `fileURL` nulo mantém o cache só em memória.
    init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    func quote(for ticker: String) -> Entry<FundQuote>? {
        contents.quotes[ticker.uppercased()]
    }

    func indicators(for ticker: String) -> Entry<FIIIndicators>? {
        contents.indicators[ticker.uppercased()]
    }

    func tickerPage(forKey key: String) -> Entry<FIITickerPage>? {
        contents.tickerPages[key]
    }

    func store(_ quote: FundQuote, at date: Date) {
        var quote = quote
        quote.cachedAt = nil
        update { $0.quotes[quote.ticker.uppercased()] = Entry(value: quote, savedAt: date) }
    }

    func store(_ indicators: [FIIIndicators], at date: Date) {
        guard !indicators.isEmpty else { return }
        update { contents in
            for item in indicators {
                contents.indicators[item.ticker.uppercased()] = Entry(value: item, savedAt: date)
            }
        }
    }

    func store(_ page: FIITickerPage, forKey key: String, at date: Date) {
        update { $0.tickerPages[key] = Entry(value: page, savedAt: date) }
    }

    private var contents: Contents {
        if let loadedContents { return loadedContents }
        let loaded = fileURL
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(Contents.self, from: $0) }
            ?? Contents()
        loadedContents = loaded
        return loaded
    }

    private func update(_ change: (inout Contents) -> Void) {
        var updated = contents
        change(&updated)
        loadedContents = updated
        guard let fileURL, let data = try? JSONEncoder().encode(updated) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
