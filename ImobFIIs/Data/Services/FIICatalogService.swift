import Foundation

struct FIITickerPage: Sendable, Equatable {
    var funds: [FundSummary]
    var totalItems: Int
}

struct FIIIndicators: Sendable, Equatable {
    var ticker: String
    var name: String?
    var price: Decimal?
    var navPerShare: Decimal?
    var priceToNav: Double?
    var dividendYield12m: Double?
    var dividendYield1m: Double?
    var monthlyReturn: Double?
    var totalInvestors: Int?
    var equity: Decimal?
    var segmentType: String?
    var segmentoAtuacao: String?
    var tipoGestao: String?
    var administratorName: String?
    var vacancyRate: Double?
}

struct FundQuote: Sendable, Equatable {
    var ticker: String
    var shortName: String?
    var longName: String?
    var price: Decimal?
    var changePercent: Double?
    var volume: Double?
    var previousClose: Decimal?
    var dayHigh: Decimal?
    var dayLow: Decimal?
    var fiftyTwoWeekHigh: Decimal?
    var fiftyTwoWeekLow: Decimal?
    var marketCap: Decimal?
}

protocol FIICatalogServing: Sendable {
    func tickers(_ query: FIITickerQuery) async throws -> FIITickerPage
    func quote(for symbol: String) async throws -> FundQuote?
    func indicators(for symbols: [String]) async throws -> [FIIIndicators]
}

struct BrapiFIICatalogService: FIICatalogServing {
    var client: BrapiClient

    init(client: BrapiClient = BrapiClient()) {
        self.client = client
    }

    func tickers(_ query: FIITickerQuery) async throws -> FIITickerPage {
        async let fiiResponse: TickerListResponse = client.send(.tickers(query.with(subType: "fii")))
        async let fiagroResponse: TickerListResponse = client.send(.tickers(query.with(subType: "fi-agro")))
        async let etfResponse: TickerListResponse = client.send(.tickers(query.with(subType: "etf")))

        let (fiis, fiagros, etfs) = try await (fiiResponse, fiagroResponse, etfResponse)
        let combined = fiis.results + fiagros.results + etfs.results
        var seen = Set<String>()
        let funds = combined.compactMap { dto -> FundSummary? in
            guard let summary = FundSummary(dto: dto), seen.insert(summary.ticker).inserted else {
                return nil
            }
            return summary
        }

        return FIITickerPage(
            funds: funds,
            totalItems: funds.count
        )
    }

    func quote(for symbol: String) async throws -> FundQuote? {
        do {
            let response: QuoteListResponse = try await client.send(.quote(symbol: symbol))
            return response.results.first.map(FundQuote.init(dto:))
        } catch let error as BrapiError where error.isOptionalDataUnavailable {
            return nil
        }
    }

    func indicators(for symbols: [String]) async throws -> [FIIIndicators] {
        guard !symbols.isEmpty else { return [] }

        do {
            let response: FIIIndicatorsResponse = try await client.send(.fiiIndicators(symbols: symbols))
            return response.fiis.map(FIIIndicators.init(dto:))
        } catch let error as BrapiError where error.isOptionalDataUnavailable {
            return []
        }
    }
}

extension FundSummary {
    init?(dto: TickerDTO) {
        guard dto.isActive != false else { return nil }
        guard dto.belongsInExploreCatalog else { return nil }

        ticker = dto.symbol
        name = dto.name
        longName = dto.longName
        segment = FundSegment.fromAPI(
            subsector: dto.subsector,
            subType: dto.subType,
            name: [dto.longName, dto.name].compactMap { $0 }.joined(separator: " ")
        )
        currentPrice = dto.quote?.lastPrice.map { Decimal($0) }
        changePercent = dto.quote?.changePercent.map { $0 / 100 }
        volume = dto.quote?.volume
        logoURL = dto.logoUrl.flatMap(URL.init(string:))
    }
}

extension TickerDTO {
    /// FIIs, Fiagros, and funds still named as FII/Fiagro even if brapi tags them as ETF
    /// (ex.: BTAL11 after converting from FII to Fiagro).
    var belongsInExploreCatalog: Bool {
        switch subType {
        case "fii", "fi-agro":
            return true
        default:
            return hasRealEstateOrAgroIdentity
        }
    }

    var hasRealEstateOrAgroIdentity: Bool {
        let blob = [name, longName, subsector]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .lowercased()

        return blob.contains("imobiliario") || blob.contains("fiagro")
    }
}

extension FIIIndicators {
    init(dto: FIIIndicatorDTO) {
        ticker = dto.symbol
        name = dto.name
        price = dto.price.map { Decimal($0) }
        navPerShare = dto.navPerShare.map { Decimal($0) }
        priceToNav = dto.priceToNav
        dividendYield12m = dto.dividendYield12m
        dividendYield1m = dto.dividendYield1m
        monthlyReturn = dto.monthlyReturn
        totalInvestors = dto.totalInvestors
        equity = dto.equity.map { Decimal($0) }
        segmentType = dto.segmentType
        segmentoAtuacao = dto.segmentoAtuacao
        tipoGestao = dto.tipoGestao
        administratorName = dto.administratorName
        vacancyRate = dto.vacancyRate
    }
}

extension FundQuote {
    init(dto: QuoteDTO) {
        ticker = dto.symbol
        shortName = dto.shortName
        longName = dto.longName
        price = dto.regularMarketPrice.map { Decimal($0) }
        changePercent = dto.regularMarketChangePercent.map { $0 / 100 }
        volume = dto.regularMarketVolume
        previousClose = dto.regularMarketPreviousClose.map { Decimal($0) }
        dayHigh = dto.regularMarketDayHigh.map { Decimal($0) }
        dayLow = dto.regularMarketDayLow.map { Decimal($0) }
        fiftyTwoWeekHigh = dto.fiftyTwoWeekHigh.map { Decimal($0) }
        fiftyTwoWeekLow = dto.fiftyTwoWeekLow.map { Decimal($0) }
        marketCap = dto.marketCap.map { Decimal($0) }
    }
}
