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
            from: Data(dividendsFixture.utf8)
        )
        let dividends = response.dividends.compactMap(FIIDividend.init(dto:))

        #expect(dividends.count == 2)
        #expect(LastDividend.latestRate(from: dividends) == dividends[0].rate)
    }

    @Test @MainActor
    func upsertCachesLastDividendFromIndicatorsFallback() {
        let container = Persistence.makeContainer(inMemory: true)
        let summary = MockFIICatalogService.preview.page.funds[0]
        let indicators = MockFIICatalogService.preview.indicatorsByTicker["MXRF11"]
        let fund = FundStore.upsert(summary, indicators: indicators, in: container.mainContext)

        #expect(fund.lastDividend == LastDividend.estimate(price: 9.29, yield1m: 0.01))
        #expect(fund.lastDividendUpdatedAt != nil)
    }

    @Test @MainActor
    func upsertDoesNotReplaceCachedDividendWithEstimate() {
        let container = Persistence.makeContainer(inMemory: true)
        let summary = MockFIICatalogService.preview.page.funds[0]
        let fund = FundStore.upsert(
            summary,
            indicators: nil,
            lastDividend: Decimal(11) / 100,
            in: container.mainContext
        )
        let indicators = MockFIICatalogService.preview.indicatorsByTicker["MXRF11"]

        _ = FundStore.upsert(summary, indicators: indicators, in: container.mainContext)

        #expect(fund.lastDividend == Decimal(11) / 100)
    }

    @Test @MainActor
    func refreshAppliesDividendRateToStaleFund() async {
        let container = Persistence.makeContainer(inMemory: true)
        let fund = makeFund(lastDividend: 0)
        container.mainContext.insert(fund)

        await LastDividendSync.refreshStaleFunds([fund], using: MockFIICatalogService.preview)

        #expect(fund.lastDividend == Decimal(9) / 100)
        #expect(fund.lastDividendUpdatedAt != nil)
        #expect(LastDividend.isCacheStale(fund) == false)
    }

    @Test @MainActor
    func refreshKeepsCachedRateWhenDividendsAreUnavailable() async {
        let container = Persistence.makeContainer(inMemory: true)
        let fund = makeFund(ticker: "XPML11", lastDividend: Decimal(82) / 100)
        container.mainContext.insert(fund)
        let catalog = MockFIICatalogService(
            page: MockFIICatalogService.preview.page,
            indicatorsByTicker: MockFIICatalogService.preview.indicatorsByTicker
        )

        await LastDividendSync.refreshStaleFunds([fund], using: catalog)

        #expect(fund.lastDividend == Decimal(82) / 100)
        #expect(fund.lastDividendUpdatedAt != nil)
    }

    @Test @MainActor
    func refreshEstimatesWhenFundHasNoCachedDividend() async {
        let container = Persistence.makeContainer(inMemory: true)
        let fund = makeFund(ticker: "MXRF11", price: 9.29, lastDividend: 0)
        container.mainContext.insert(fund)
        let catalog = MockFIICatalogService(
            page: MockFIICatalogService.preview.page,
            indicatorsByTicker: MockFIICatalogService.preview.indicatorsByTicker
        )

        await LastDividendSync.refreshStaleFunds([fund], using: catalog)

        #expect(fund.lastDividend == LastDividend.estimate(price: 9.29, yield1m: 0.01))
    }

    @Test @MainActor
    func skipsFreshCache() async {
        let container = Persistence.makeContainer(inMemory: true)
        let fund = makeFund(lastDividend: Decimal(2) / 10, updatedAt: .now)
        container.mainContext.insert(fund)

        await LastDividendSync.refreshStaleFunds([fund], using: MockFIICatalogService.preview)

        #expect(fund.lastDividend == Decimal(2) / 10)
    }

    @Test @MainActor
    func detailViewModelResolvesLastDividendFromCatalog() async {
        let viewModel = FundDetailViewModel(
            summary: MockFIICatalogService.preview.page.funds[0],
            catalog: MockFIICatalogService.preview
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
            session: DividendHTTPClient(data: Data(dividendsFixture.utf8), statusCode: 200)
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
            session: DividendHTTPClient(data: Data(body.utf8), statusCode: 401)
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
            session: DividendHTTPClient(data: Data(body.utf8), statusCode: 403)
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
struct YahooDividendFallbackTests {
    @Test
    func buildsB3YahooSymbol() {
        #expect(YahooDividendFallback.yahooSymbol(for: "cpts11") == "CPTS11.SA")
        #expect(YahooDividendFallback.yahooSymbol(for: "CPTS11.SA") == "CPTS11.SA")
    }

    @Test
    func mapsLatestCashDividendFromYahooChart() async {
        let fallback = YahooDividendFallback(
            session: DividendHTTPClient(data: Data(yahooChartFixture.utf8), statusCode: 200)
        )
        let dividends = await fallback.latestDividends(for: ["CPTS11"])

        #expect(dividends.count == 1)
        #expect(dividends[0].ticker == "CPTS11")
        #expect(dividends[0].rate == Decimal(9) / 100)
        #expect(dividends[0].isIncome)
    }
}

private func makeFund(
    ticker: String = "MXRF11",
    price: Decimal = 10,
    lastDividend: Decimal = 0,
    updatedAt: Date? = nil
) -> Fund {
    Fund(
        ticker: ticker,
        name: ticker,
        segment: .paper,
        manager: "",
        currentPrice: price,
        dividendYield: 0,
        lastDividend: lastDividend,
        lastDividendUpdatedAt: updatedAt
    )
}

private struct MockDividendFallback: DividendFallbackServing {
    var dividends: [FIIDividend]

    func latestDividends(for symbols: [String]) async -> [FIIDividend] {
        dividends.filter { symbols.contains($0.ticker) }
    }
}

private struct DividendHTTPClient: HTTPPerforming {
    let data: Data
    let statusCode: Int

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
              )
        else {
            throw BrapiError.invalidResponse
        }
        return (data, response)
    }
}

private let dividendsFixture = """
{
  "dividends": [
    {
      "symbol": "MXRF11",
      "approvedOn": null,
      "label": "RENDIMENTO",
      "lastDatePrior": "2025-12-01 00:00:00+00",
      "paymentDate": "2025-12-01 00:00:00+00",
      "rate": 0.08941643,
      "relatedTo": null,
      "isinCode": null,
      "remarks": "backfilled from FiiMonthlyReports"
    },
    {
      "symbol": "MXRF11",
      "approvedOn": null,
      "label": "RENDIMENTO",
      "lastDatePrior": "2025-11-01 00:00:00+00",
      "paymentDate": "2025-11-01 00:00:00+00",
      "rate": 0.098144606,
      "relatedTo": null,
      "isinCode": null,
      "remarks": "backfilled from FiiMonthlyReports"
    }
  ],
  "requestedAt": "2026-02-08T16:25:19.026Z",
  "took": 23
}
"""

private let yahooChartFixture = """
{
  "chart": {
    "result": [
      {
        "meta": { "symbol": "CPTS11.SA" },
        "events": {
          "dividends": {
            "1": { "amount": 0.08, "date": 1 },
            "1786971600": { "amount": 0.09, "date": 1786971600 }
          }
        }
      }
    ],
    "error": null
  }
}
"""
