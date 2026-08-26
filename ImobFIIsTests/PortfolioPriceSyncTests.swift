import Foundation
import Testing
@testable import ImobFIIs

@Suite("Atualização de preços da carteira")
struct PortfolioPriceSyncTests {
    @Test @MainActor
    func updatesPriceFromYahooSource() async {
        PortfolioPriceSync.resetSessionStateForTesting()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let fund = TestFunds.make(ticker: "MXRF11", price: 8)
        let marketDataSource = MockPortfolioMarketDataSource(
            snapshots: [.init(ticker: "MXRF11", price: 9.50, lastDividend: 0.09)]
        )

        let outcome = await PortfolioPriceSync.refreshIfNeeded(
            [fund],
            using: marketDataSource,
            defaults: defaults,
            postsNotification: false
        )

        #expect(outcome == .updated)
        #expect(fund.currentPrice == Decimal(string: "9.5"))
        #expect(fund.lastDividend == Decimal(string: "0.09"))
        #expect(defaults.dictionary(forKey: PortfolioPriceSync.priceStorageKey)?["MXRF11"] != nil)
        #expect(defaults.dictionary(forKey: PortfolioPriceSync.dividendStorageKey)?["MXRF11"] != nil)
    }

    @Test @MainActor
    func keepsCachedPriceWhenYahooReturnsNoPrice() async {
        PortfolioPriceSync.resetSessionStateForTesting()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let fund = TestFunds.make(ticker: "MXRF11", price: 8)
        let marketDataSource = MockPortfolioMarketDataSource(snapshots: [])

        let outcome = await PortfolioPriceSync.refreshIfNeeded(
            [fund],
            using: marketDataSource,
            defaults: defaults,
            postsNotification: false
        )

        #expect(outcome == .failed)
        #expect(fund.currentPrice == 8)
    }

    @Test @MainActor
    func usesPerTickerCacheInsteadOfBlockingTheWholeSession() async {
        PortfolioPriceSync.resetSessionStateForTesting()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let fund = TestFunds.make(ticker: "MXRF11", price: 8)
        let now = Date()
        let marketDataSource = MockPortfolioMarketDataSource(
            snapshots: [.init(ticker: "MXRF11", price: 9, lastDividend: nil)]
        )

        await PortfolioPriceSync.refreshIfNeeded(
            [fund],
            using: marketDataSource,
            defaults: defaults,
            now: now,
            postsNotification: false
        )
        #expect(fund.currentPrice == 9)

        await PortfolioPriceSync.refreshIfNeeded(
            [fund],
            using: MockPortfolioMarketDataSource(
                snapshots: [.init(ticker: "MXRF11", price: 12, lastDividend: nil)]
            ),
            defaults: defaults,
            now: now.addingTimeInterval(PortfolioPriceSync.minimumInterval + 1),
            postsNotification: false
        )

        #expect(fund.currentPrice == 12)
    }

    @Test @MainActor
    func skipsWhenMinimumIntervalHasNotElapsed() async {
        PortfolioPriceSync.resetSessionStateForTesting()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let now = Date()
        defaults.set(
            ["MXRF11": now.timeIntervalSinceReferenceDate],
            forKey: PortfolioPriceSync.priceStorageKey
        )
        defaults.set(
            ["MXRF11": now.timeIntervalSinceReferenceDate],
            forKey: PortfolioPriceSync.dividendStorageKey
        )

        let fund = TestFunds.make(ticker: "MXRF11", price: 8)
        let marketDataSource = MockPortfolioMarketDataSource(
            snapshots: [.init(ticker: "MXRF11", price: 11, lastDividend: nil)]
        )

        let outcome = await PortfolioPriceSync.refreshIfNeeded(
            [fund],
            using: marketDataSource,
            defaults: defaults,
            now: now.addingTimeInterval(60),
            postsNotification: false
        )

        #expect(outcome == .skipped)
        #expect(fund.currentPrice == 8)
    }

    @Test @MainActor
    func refreshesDividendIndependentlyFromPrice() async {
        PortfolioPriceSync.resetSessionStateForTesting()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let now = Date()
        defaults.set(["MXRF11": now.timeIntervalSinceReferenceDate], forKey: PortfolioPriceSync.priceStorageKey)
        defaults.set(
            [
                "MXRF11": now
                    .addingTimeInterval(-PortfolioPriceSync.dividendMinimumInterval)
                    .timeIntervalSinceReferenceDate,
            ],
            forKey: PortfolioPriceSync.dividendStorageKey
        )
        let fund = TestFunds.make(ticker: "MXRF11", price: 8)
        let source = MockPortfolioMarketDataSource(
            snapshots: [.init(ticker: "MXRF11", price: 9, lastDividend: 0.09)]
        )

        let outcome = await PortfolioPriceSync.refreshIfNeeded(
            [fund],
            using: source,
            defaults: defaults,
            now: now,
            postsNotification: false
        )

        #expect(outcome == .updated)
        #expect(fund.currentPrice == 8)
        #expect(fund.lastDividend == Decimal(string: "0.09"))
    }

    @Test @MainActor
    func marksFailureWhenSnapshotsHaveNoUsablePrice() async {
        PortfolioPriceSync.resetSessionStateForTesting()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let fund = TestFunds.make(ticker: "MXRF11", price: 8)
        let source = MockPortfolioMarketDataSource(
            snapshots: [.init(ticker: "MXRF11", price: nil, lastDividend: 0.09)]
        )

        let outcome = await PortfolioPriceSync.refreshIfNeeded(
            [fund],
            using: source,
            defaults: defaults,
            postsNotification: false
        )

        #expect(outcome == .failed)
        #expect(fund.currentPrice == 8)
        #expect(fund.lastDividend == Decimal(string: "0.09"))
    }

    @Test
    func fallsBackToBrapiQuoteWhenYahooHasNoPrice() async {
        let source = FallbackPortfolioMarketDataService(
            primary: MockPortfolioMarketDataSource(snapshots: []),
            fallback: BrapiQuoteMarketDataService(catalog: MockFIICatalogService.sample)
        )

        let snapshots = await source.latestMarketData(for: ["MXRF11"])

        #expect(snapshots.count == 1)
        #expect(snapshots.first?.ticker == "MXRF11")
        #expect(snapshots.first?.price == Decimal(string: "9.29"))
    }
}

private struct MockPortfolioMarketDataSource: PortfolioMarketDataServing {
    var snapshots: [PortfolioMarketData]

    func latestMarketData(for symbols: [String]) async -> [PortfolioMarketData] {
        let requested = Set(symbols.map { $0.uppercased() })
        return snapshots.filter { requested.contains($0.ticker.uppercased()) }
    }
}
