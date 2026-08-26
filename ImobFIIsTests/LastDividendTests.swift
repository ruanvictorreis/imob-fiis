import Foundation
import SwiftData
import Testing
@testable import ImobFIIs

@Suite("Último provento")
struct LastDividendTests {
    @Test
    func prefersLatestIncomeOverAmortization() {
        let olderIncome = FIIDividend(
            ticker: "MXRF11",
            label: "RENDIMENTO",
            paymentDate: Date(timeIntervalSince1970: 1_700_000_000),
            lastDatePrior: nil,
            rate: Decimal(8) / 100
        )
        let amortization = FIIDividend(
            ticker: "MXRF11",
            label: "AMORTIZAÇÃO",
            paymentDate: Date(timeIntervalSince1970: 1_800_000_000),
            lastDatePrior: nil,
            rate: Decimal(5) / 10
        )
        let latestIncome = FIIDividend(
            ticker: "MXRF11",
            label: "RENDIMENTO",
            paymentDate: Date(timeIntervalSince1970: 1_750_000_000),
            lastDatePrior: nil,
            rate: Decimal(11) / 100
        )

        #expect(LastDividend.latestRate(from: [olderIncome, amortization, latestIncome]) == Decimal(11) / 100)
    }

    @Test
    func estimatesFromMonthlyYieldWhenDividendsAreMissing() {
        let estimate = LastDividend.estimate(price: 10, yield1m: 0.01)

        #expect(estimate == Decimal(10) * Decimal(0.01))
        #expect(
            LastDividend.resolved(dividends: [], price: 10, yield1m: 0.01) == estimate
        )
    }

    @Test
    func resolvedPrefersDividendRateOverYieldEstimate() {
        let dividend = FIIDividend(
            ticker: "HGLG11",
            label: "RENDIMENTO",
            paymentDate: Date(),
            lastDatePrior: nil,
            rate: Decimal(11) / 10
        )

        #expect(
            LastDividend.resolved(dividends: [dividend], price: 100, yield1m: 0.01)
                == Decimal(11) / 10
        )
    }

    @Test
    func parsesBrapiPaymentDates() throws {
        let iso = try #require(BrapiDate.parse("2025-04-14T00:00:00.000Z"))
        let spaced = try #require(BrapiDate.parse("2025-12-01 00:00:00+00"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt

        #expect(calendar.component(.year, from: iso) == 2025)
        #expect(calendar.component(.month, from: spaced) == 12)
    }

    @Test
    func decodesFIIDividendsFromBrapi() throws {
        let response: FIIDividendsResponse = try JSONDecoder().decode(
            FIIDividendsResponse.self,
            from: Data(HTTPFixtures.dividends.utf8)
        )
        let dividends = response.dividends.compactMap(FIIDividend.init(dto:))

        #expect(dividends.count == 2)
        #expect(LastDividend.latestRate(from: dividends) == dividends[0].rate)
    }

    @Test @MainActor
    func upsertCachesLastDividendFromIndicatorsFallback() {
        let container = Persistence.makeContainer(inMemory: true)
        let summary = MockFIICatalogService.sample.page.funds[0]
        let indicators = MockFIICatalogService.sample.indicatorsByTicker["MXRF11"]
        let fund = FundStore.upsert(summary, indicators: indicators, in: container.mainContext)

        #expect(fund.lastDividend == LastDividend.estimate(price: 9.29, yield1m: 0.01))
        #expect(fund.lastDividendUpdatedAt != nil)
    }

    @Test @MainActor
    func upsertDoesNotReplaceCachedDividendWithEstimate() {
        let container = Persistence.makeContainer(inMemory: true)
        let summary = MockFIICatalogService.sample.page.funds[0]
        let fund = FundStore.upsert(
            summary,
            indicators: nil,
            lastDividend: Decimal(11) / 100,
            in: container.mainContext
        )
        let indicators = MockFIICatalogService.sample.indicatorsByTicker["MXRF11"]

        _ = FundStore.upsert(summary, indicators: indicators, in: container.mainContext)

        #expect(fund.lastDividend == Decimal(11) / 100)
    }

    @Test @MainActor
    func refreshAppliesDividendRateToStaleFund() async {
        let container = Persistence.makeContainer(inMemory: true)
        let fund = TestFunds.make(lastDividend: 0)
        container.mainContext.insert(fund)

        await LastDividendSync.refreshStaleFunds([fund], using: MockFIICatalogService.sample)

        #expect(fund.lastDividend == Decimal(9) / 100)
        #expect(fund.lastDividendUpdatedAt != nil)
        #expect(LastDividend.isCacheStale(fund) == false)
    }

    @Test @MainActor
    func refreshKeepsCachedRateWhenDividendsAreUnavailable() async {
        let container = Persistence.makeContainer(inMemory: true)
        let fund = TestFunds.make(ticker: "XPML11", lastDividend: Decimal(82) / 100)
        container.mainContext.insert(fund)
        let catalog = MockFIICatalogService(
            page: MockFIICatalogService.sample.page,
            indicatorsByTicker: MockFIICatalogService.sample.indicatorsByTicker
        )

        await LastDividendSync.refreshStaleFunds([fund], using: catalog)

        #expect(fund.lastDividend == Decimal(82) / 100)
        #expect(fund.lastDividendUpdatedAt != nil)
    }

    @Test @MainActor
    func refreshEstimatesWhenFundHasNoCachedDividend() async {
        let container = Persistence.makeContainer(inMemory: true)
        let fund = TestFunds.make(ticker: "MXRF11", price: 9.29, lastDividend: 0)
        container.mainContext.insert(fund)
        let catalog = MockFIICatalogService(
            page: MockFIICatalogService.sample.page,
            indicatorsByTicker: MockFIICatalogService.sample.indicatorsByTicker
        )

        await LastDividendSync.refreshStaleFunds([fund], using: catalog)

        #expect(fund.lastDividend == LastDividend.estimate(price: 9.29, yield1m: 0.01))
    }

    @Test @MainActor
    func skipsFreshCache() async {
        let container = Persistence.makeContainer(inMemory: true)
        let fund = TestFunds.make(lastDividend: Decimal(2) / 10, updatedAt: .now)
        container.mainContext.insert(fund)

        await LastDividendSync.refreshStaleFunds([fund], using: MockFIICatalogService.sample)

        #expect(fund.lastDividend == Decimal(2) / 10)
    }

    @Test @MainActor
    func detailViewModelResolvesLastDividendFromCatalog() async {
        let viewModel = FundDetailViewModel(
            summary: MockFIICatalogService.sample.page.funds[0],
            catalog: MockFIICatalogService.sample
        )

        await viewModel.loadMarketData()

        #expect(viewModel.lastDividend == Decimal(9) / 100)
    }
}

@Suite("Dividendos / brapi HTTP")
struct FIIDividendsCatalogTests {
    @Test
    func catalogServiceMapsDividendsFromHTTP() async throws {
        let client = BrapiClient(
            token: "test-token",
            session: MockHTTPClient(data: Data(HTTPFixtures.dividends.utf8), statusCode: 200)
        )
        let service = BrapiFIICatalogService(client: client, dividendFallback: EmptyDividendFallback())
        let dividends = try await service.dividends(for: ["MXRF11"])

        #expect(dividends.map(\.ticker) == ["MXRF11", "MXRF11"])
        #expect(LastDividend.latestRate(from: dividends) == dividends[0].rate)
    }

    @Test
    func missingTokenOnDividendsReturnsEmptyList() async throws {
        let body = #"{"error":true,"message":"Token de autenticação não fornecido","code":"MISSING_TOKEN"}"#
        let client = BrapiClient(
            token: nil,
            session: MockHTTPClient(data: Data(body.utf8), statusCode: 401)
        )
        let service = BrapiFIICatalogService(client: client, dividendFallback: EmptyDividendFallback())
        let dividends = try await service.dividends(for: ["KNRI11"])

        #expect(dividends.isEmpty)
    }

    @Test
    func usesFallbackWhenBrapiFIIDividendsAreUnavailable() async throws {
        let body = """
        {"error":true,"message":"Fundos Imobiliários (FIIs) requer o plano Pro.","code":"FEATURE_NOT_AVAILABLE"}
        """
        let client = BrapiClient(
            token: "test-token",
            session: MockHTTPClient(data: Data(body.utf8), statusCode: 403)
        )
        let fallback = MockDividendFallback(
            dividends: [
                FIIDividend(
                    ticker: "CPTS11",
                    label: "RENDIMENTO",
                    paymentDate: Date(),
                    lastDatePrior: nil,
                    rate: Decimal(9) / 100
                ),
            ]
        )
        let service = BrapiFIICatalogService(client: client, dividendFallback: fallback)
        let dividends = try await service.dividends(for: ["CPTS11"])

        #expect(dividends.map(\.ticker) == ["CPTS11"])
        #expect(LastDividend.latestRate(from: dividends) == Decimal(9) / 100)
    }
}

@Suite("Fallback de proventos")
struct YahooMarketDataServiceTests {
    @Test
    func buildsB3YahooSymbol() {
        #expect(YahooMarketDataService.yahooSymbol(for: "cpts11") == "CPTS11.SA")
        #expect(YahooMarketDataService.yahooSymbol(for: "CPTS11.SA") == "CPTS11.SA")
    }

    @Test
    func mapsLatestCashDividendFromYahooChart() async {
        let fallback = YahooMarketDataService(
            session: MockHTTPClient(data: Data(HTTPFixtures.yahooChart.utf8), statusCode: 200)
        )
        let dividends = await fallback.latestDividends(for: ["CPTS11"])

        #expect(dividends.count == 1)
        #expect(dividends[0].ticker == "CPTS11")
        #expect(dividends[0].rate == Decimal(9) / 100)
        #expect(dividends[0].isIncome)
    }

    @Test
    func mapsCurrentMarketDataFromYahooChart() async {
        let fallback = YahooMarketDataService(
            session: MockHTTPClient(data: Data(HTTPFixtures.yahooChartWithPrice.utf8), statusCode: 200)
        )

        let snapshots = await fallback.latestMarketData(for: ["CPTS11"])

        #expect(snapshots.first?.price == Decimal(string: "76.42"))
        #expect(snapshots.first?.lastDividend == Decimal(string: "0.09"))
    }
}
