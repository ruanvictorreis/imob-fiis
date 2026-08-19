import Foundation
import SwiftData
import Testing
@testable import ImobFIIs

@Suite("Catálogo e carteira")
struct ImobFIIsTests {
    @Test @MainActor
    func seedingCatalogIsIdempotent() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext

        SampleData.seedIfNeeded(in: context)
        SampleData.seedIfNeeded(in: context)

        let funds = try context.fetch(FetchDescriptor<Fund>())
        #expect(funds.count == SampleData.catalogCount)
        #expect(Set(funds.map(\.ticker)).count == funds.count)
    }

    @Test @MainActor
    func addingSharesMergesExistingHolding() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext
        SampleData.seedIfNeeded(in: context)

        let fund = try #require(context.fetch(FetchDescriptor<Fund>()).first)
        let holding = Holding(shares: 10, averagePrice: 100, fund: fund)
        context.insert(holding)

        holding.addShares(10, at: 120)

        #expect(holding.shares == 20)
        #expect(holding.averagePrice == 110)
        #expect(holding.fund?.holdings.count == 1)
    }

    @Test @MainActor
    func repairSegmentsUpdatesStaleOtherClassification() {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext

        let rura = Fund(
            ticker: "RURA11",
            name: "Itau Asset Rural Figaro Imobiliario",
            segment: .other,
            manager: "",
            currentPrice: 10,
            dividendYield: 0,
            lastDividend: 0
        )
        let cpts = Fund(
            ticker: "CPTS11",
            name: "Capitania Securities II Fundo de Investimento Imobiliario Cotas",
            segment: .other,
            manager: "",
            currentPrice: 8,
            dividendYield: 0,
            lastDividend: 0
        )
        context.insert(rura)
        context.insert(cpts)

        FundStore.repairSegments(in: context)

        #expect(rura.segment == .fiagro)
        #expect(cpts.segment == .paper)
    }

    @Test
    func projectedPositionShowsWeightedAverageBeforeSaving() {
        let holding = Holding(shares: 120, averagePrice: Decimal(string: "98.5")!)
        let projected = holding.projectedPosition(adding: 30, at: 100)

        #expect(projected?.shares == 150)
        #expect(projected?.averagePrice == Decimal(string: "98.8"))
        #expect(holding.shares == 120)
        #expect(holding.averagePrice == Decimal(string: "98.5"))
    }

    @Test
    func brlInputFormatsPriceAsBrazilianCurrency() {
        let formatted = Decimal(string: "98.5")!.formatted(.brlInput)

        #expect(formatted.contains("R$"))
        #expect(formatted.contains("98,50"))

        let thousands = Decimal(string: "1234.5")!.formatted(.brlInput)
        #expect(thousands.contains("1.234,50"))
    }
}

@Suite("Explorar / brapi")
struct ExploreCatalogTests {
    @Test
    func decodesTickerListFromBrapi() throws {
        let page: TickerListResponse = try JSONDecoder().decode(
            TickerListResponse.self,
            from: Data(tickerListFixture.utf8)
        )

        #expect(page.results.count == 1)
        #expect(page.results[0].symbol == "MXRF11")
        #expect(page.results[0].quote?.lastPrice == 9.29)

        let summary = try #require(FundSummary(dto: page.results[0]))
        #expect(summary.ticker == "MXRF11")
        #expect(summary.segment == .logistics)
        #expect(summary.changePercent == 0.0043)
    }

    @Test
    func mapsAPISubsectorsToFundSegments() {
        #expect(FundSegment.fromAPI(subsector: "Logística") == .logistics)
        #expect(FundSegment.fromAPI(subsector: "Escritórios") == .offices)
        #expect(FundSegment.fromAPI(subsector: "Shoppings") == .malls)
        #expect(FundSegment.fromAPI(subsector: "Híbrido") == .hybrid)
        #expect(FundSegment.fromAPI(subsector: "Multicategoria") == .other)
        #expect(FundSegment.fromAPI(subsector: nil) == .other)
        #expect(FundSegment.fromAPI(subsector: nil, subType: "fi-agro") == .fiagro)
        #expect(FundSegment.fromAPI(subsector: "Fiagro") == .fiagro)
        #expect(
            FundSegment.fromAPI(
                subsector: "Outros",
                name: "Itau Asset Rural Figaro Imobiliario"
            ) == .fiagro
        )
        #expect(
            FundSegment.fromAPI(
                subsector: "Outros",
                name: "Capitania Securities II Fundo de Investimento Imobiliario Cotas"
            ) == .paper
        )
    }

    @Test @MainActor
    func viewModelLoadsAndFiltersFunds() async {
        let viewModel = ExploreViewModel(catalog: MockFIICatalogService.preview)
        await viewModel.loadIfNeeded()

        #expect(viewModel.funds.count == 3)
        #expect(viewModel.errorMessage == nil)

        viewModel.searchText = "XPML"
        #expect(viewModel.displayedFunds.map(\.ticker) == ["XPML11"])

        viewModel.searchText = ""
        viewModel.selectedSegment = .malls
        #expect(viewModel.displayedFunds.map(\.ticker) == ["XPML11"])
    }

    @Test
    func keepsConvertedFIIMisclassifiedAsETF() {
        let dto = TickerDTO(
            symbol: "BTAL11",
            name: "BTAL11",
            longName: "Fundo de Investimento Imobiliario BTG Pactual Agro Logistica",
            assetType: "fund",
            subType: "etf",
            sector: nil,
            subsector: "Logística",
            isActive: true,
            logoUrl: nil,
            quote: nil
        )

        let summary = FundSummary(dto: dto)
        #expect(summary?.ticker == "BTAL11")
        #expect(summary?.segment == .logistics)
    }

    @Test
    func keepsFiagroSubtype() {
        let dto = TickerDTO(
            symbol: "RURA11",
            name: "RURA11",
            longName: "Itau Asset Rural Figaro Imobiliario",
            assetType: "fund",
            subType: "fi-agro",
            sector: nil,
            subsector: nil,
            isActive: true,
            logoUrl: nil,
            quote: nil
        )

        #expect(FundSummary(dto: dto)?.ticker == "RURA11")
        #expect(FundSummary(dto: dto)?.segment == .fiagro)
    }

    @Test
    func dropsIndexETFsFromExploreCatalog() {
        let dto = TickerDTO(
            symbol: "BOVA11",
            name: "BOVA11",
            longName: "iShares Ibovespa Fundo de Indice",
            assetType: "fund",
            subType: "etf",
            sector: "Miscellaneous",
            subsector: nil,
            isActive: true,
            logoUrl: nil,
            quote: nil
        )

        #expect(FundSummary(dto: dto) == nil)
    }

    @Test
    func catalogServiceMapsTickersFromHTTP() async throws {
        let client = BrapiClient(
            token: nil,
            session: MockHTTPClient(data: Data(tickerListFixture.utf8), statusCode: 200)
        )
        let service = BrapiFIICatalogService(client: client)
        let page = try await service.tickers(.allFIIs)

        #expect(page.funds.map(\.ticker) == ["MXRF11"])
        #expect(page.totalItems == 1)
    }

    @Test
    func missingTokenOnIndicatorsReturnsEmptyList() async throws {
        let body = #"{"error":true,"message":"Token de autenticação não fornecido","code":"MISSING_TOKEN"}"#
        let client = BrapiClient(
            token: nil,
            session: MockHTTPClient(data: Data(body.utf8), statusCode: 401)
        )
        let service = BrapiFIICatalogService(client: client)
        let indicators = try await service.indicators(for: ["KNRI11"])
        #expect(indicators.isEmpty)
    }

    @Test
    func proFeatureOnIndicatorsReturnsEmptyList() async throws {
        let body = #"{"error":true,"message":"Fundos Imobiliários (FIIs) requer o plano Pro.","code":"FEATURE_NOT_AVAILABLE"}"#
        let client = BrapiClient(
            token: "test-token",
            session: MockHTTPClient(data: Data(body.utf8), statusCode: 403)
        )
        let service = BrapiFIICatalogService(client: client)
        let indicators = try await service.indicators(for: ["KNRI11"])
        #expect(indicators.isEmpty)
    }

    @Test
    func catalogServiceMapsQuoteFromHTTP() async throws {
        let client = BrapiClient(
            token: "test-token",
            session: MockHTTPClient(data: Data(quoteFixture.utf8), statusCode: 200)
        )
        let service = BrapiFIICatalogService(client: client)
        let quote = try await service.quote(for: "KNRI11")

        #expect(quote?.ticker == "KNRI11")
        #expect(quote?.previousClose == 152)
        #expect(quote?.dayHigh == Decimal(string: "154.2"))
    }

    @Test @MainActor
    func upsertCreatesFundFromLiveQuote() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let summary = MockFIICatalogService.preview.page.funds[0]
        let fund = FundStore.upsert(summary, indicators: nil, in: container.mainContext)

        #expect(fund.ticker == "MXRF11")
        #expect(fund.currentPrice == (summary.currentPrice ?? 0))
        #expect(try container.mainContext.fetch(FetchDescriptor<Fund>()).count == 1)
    }
}

private struct MockHTTPClient: HTTPPerforming {
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

private let tickerListFixture = """
{
  "results": [
    {
      "symbol": "MXRF11",
      "name": "MXRF11",
      "longName": "Maxi Renda Fundo de Investimento Imobiliario Cotas",
      "assetType": "fund",
      "subType": "fii",
      "exchange": "B3",
      "currency": "BRL",
      "sector": "Miscellaneous",
      "subsector": "Logística",
      "isActive": true,
      "logoUrl": "https://icons.brapi.dev/icons/BRAPI.svg",
      "quote": {
        "lastPrice": 9.29,
        "changePercent": 0.43,
        "volume": 1899639,
        "marketCap": null
      }
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 1,
    "totalItems": 1,
    "totalPages": 1,
    "hasNextPage": false
  }
}
"""

private let quoteFixture = """
{
  "results": [
    {
      "symbol": "KNRI11",
      "shortName": "KNRI11",
      "longName": "Kinea Renda Imobiliaria Fundo de Investimento Imobiliario",
      "regularMarketPrice": 153.48,
      "regularMarketChangePercent": 0.97,
      "regularMarketVolume": 66189,
      "regularMarketPreviousClose": 152,
      "regularMarketDayHigh": 154.2,
      "regularMarketDayLow": 151.8,
      "fiftyTwoWeekHigh": 170.1,
      "fiftyTwoWeekLow": 130.4,
      "marketCap": null
    }
  ]
}
"""
