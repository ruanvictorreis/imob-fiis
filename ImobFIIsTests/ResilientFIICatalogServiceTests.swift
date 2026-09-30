import Foundation
import Testing
@testable import ImobFIIs

@Suite("Cotações com fallback e cache")
struct ResilientFIICatalogServiceTests {
    private let savedAt = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func yahooSnapshotDerivesQuoteAndTrailingYield() async throws {
        let yahoo = YahooMarketDataService(session: MockHTTPClient(data: Data(Self.yahooYear.utf8), statusCode: 200))

        let snapshot = try #require(await yahoo.marketSnapshot(for: "cpts11"))

        #expect(snapshot.quote.ticker == "CPTS11")
        #expect(snapshot.quote.price == 80)
        #expect(snapshot.quote.previousClose == 78)
        #expect(snapshot.quote.fiftyTwoWeekHigh == Decimal(string: "85.5"))
        #expect(snapshot.quote.fiftyTwoWeekLow == Decimal(string: "70.1"))
        #expect(snapshot.quote.dayHigh == nil)
        #expect(snapshot.quote.longName == "Capitania Securities")
        let yield12m = try #require(snapshot.indicators.dividendYield12m)
        #expect(abs(yield12m - 0.03) < 0.000_001)
        let yield1m = try #require(snapshot.indicators.dividendYield1m)
        #expect(abs(yield1m - 0.0125) < 0.000_001)
    }

    @Test
    func usesYahooWhenBrapiHasNoIndicatorsAndKeepsCachedNav() async throws {
        let cache = MarketDataCache(fileURL: nil)
        await cache.store(
            [FIIIndicators(ticker: "CPTS11", name: "Capitania", navPerShare: 100, priceToNav: 0.7, vacancyRate: 0)],
            at: savedAt
        )
        let service = ResilientFIICatalogService(
            primary: MockFIICatalogService(page: FIITickerPage(funds: [], totalItems: 0)),
            fallback: StubSnapshotService(snapshots: ["CPTS11": Self.snapshot(price: 80)]),
            cache: cache
        )

        let indicators = try await service.indicators(for: ["CPTS11"])

        #expect(indicators.count == 1)
        #expect(indicators.first?.price == 80)
        #expect(indicators.first?.dividendYield12m == 0.12)
        #expect(indicators.first?.name == "Capitania")
        #expect(indicators.first?.priceToNav == 0.8)
        #expect(indicators.first?.vacancyRate == 0)
    }

    @Test
    func fallsBackToCachedQuoteWhenEverySourceFails() async throws {
        let cache = MarketDataCache(fileURL: nil)
        await cache.store(FundQuote(ticker: "CPTS11", price: 79), at: savedAt)
        let service = ResilientFIICatalogService(
            primary: MockFIICatalogService(page: FIITickerPage(funds: [], totalItems: 0)),
            fallback: StubSnapshotService(snapshots: [:]),
            cache: cache
        )

        let quote = try #require(try await service.quote(for: "CPTS11"))

        #expect(quote.price == 79)
        #expect(quote.cachedAt == savedAt)
    }

    @Test
    func cachedQuoteIsNotUsedAsFreshPortfolioPrice() async {
        let cache = MarketDataCache(fileURL: nil)
        await cache.store(FundQuote(ticker: "CPTS11", price: 79), at: savedAt)
        let catalog = ResilientFIICatalogService(
            primary: MockFIICatalogService(page: FIITickerPage(funds: [], totalItems: 0)),
            fallback: StubSnapshotService(snapshots: [:]),
            cache: cache
        )

        let snapshots = await BrapiQuoteMarketDataService(catalog: catalog).latestMarketData(for: ["CPTS11"])

        #expect(snapshots.isEmpty)
    }

    @Test
    func servesCachedCatalogWhenBrapiFails() async throws {
        let cache = MarketDataCache(fileURL: nil)
        let page = MockFIICatalogService.sample.page
        let noFallback = StubSnapshotService(snapshots: [:])
        let online = ResilientFIICatalogService(
            primary: MockFIICatalogService.sample,
            fallback: noFallback,
            cache: cache
        )
        _ = try await online.tickers(.allFIIs)

        let offline = ResilientFIICatalogService(primary: FailingCatalog(), fallback: noFallback, cache: cache)

        #expect(try await offline.tickers(.allFIIs) == page)
        await #expect(throws: URLError.self) {
            try await offline.tickers(.allFiagros)
        }
    }

    @Test
    func cachePersistsToDisk() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "market-cache-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        await MarketDataCache(fileURL: url).store(FundQuote(ticker: "cpts11", price: 79), at: savedAt)

        let reloaded = await MarketDataCache(fileURL: url).quote(for: "CPTS11")

        #expect(reloaded?.value.price == 79)
        #expect(reloaded?.savedAt == savedAt)
    }

    private static func snapshot(price: Decimal) -> FundMarketSnapshot {
        FundMarketSnapshot(
            quote: FundQuote(ticker: "CPTS11", price: price),
            indicators: FIIIndicators(
                ticker: "CPTS11",
                name: "Capitania Securities",
                price: price,
                dividendYield12m: 0.12
            )
        )
    }

    /// Preço 80, fechamento anterior 78; proventos de 1,00 + 1,40 nos últimos 12 meses e um antigo fora da janela.
    private static let yahooYear = """
    {
      "chart": {
        "result": [
          {
            "meta": {
              "symbol": "CPTS11.SA",
              "regularMarketPrice": 80,
              "longName": "Capitania Securities",
              "regularMarketDayHigh": 0.0,
              "fiftyTwoWeekHigh": 85.5,
              "fiftyTwoWeekLow": 0.0
            },
            "timestamp": [1790000000, 1790086400],
            "indicators": { "quote": [{ "close": [70.1, 78.00000122070312, 80] }] },
            "events": {
              "dividends": {
                "1750000000": { "amount": 5.0, "date": 1750000000 },
                "1770000000": { "amount": 1.4, "date": 1770000000 },
                "1789000000": { "amount": 1.0, "date": 1789000000 }
              }
            }
          }
        ],
        "error": null
      }
    }
    """
}

private struct StubSnapshotService: FundMarketSnapshotServing {
    var snapshots: [String: FundMarketSnapshot]

    func marketSnapshot(for symbol: String) async -> FundMarketSnapshot? {
        snapshots[symbol.uppercased()]
    }
}

private struct FailingCatalog: FIICatalogServing {
    func tickers(_ query: FIITickerQuery) async throws -> FIITickerPage {
        throw URLError(.notConnectedToInternet)
    }

    func quote(for symbol: String) async throws -> FundQuote? {
        throw URLError(.notConnectedToInternet)
    }

    func indicators(for symbols: [String]) async throws -> [FIIIndicators] {
        throw URLError(.notConnectedToInternet)
    }

    func dividends(for symbols: [String]) async throws -> [FIIDividend] {
        throw URLError(.notConnectedToInternet)
    }
}
