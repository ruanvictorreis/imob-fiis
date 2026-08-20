import Foundation

struct TickerListResponse: Decodable, Sendable {
    var results: [TickerDTO]
    var pagination: BrapiPaginationDTO?
}

struct TickerDTO: Decodable, Sendable {
    var symbol: String
    var name: String
    var longName: String?
    var assetType: String?
    var subType: String?
    var sector: String?
    var subsector: String?
    var isActive: Bool?
    var logoUrl: String?
    var quote: TickerQuoteDTO?
}

struct TickerQuoteDTO: Decodable, Sendable {
    var lastPrice: Double?
    var changePercent: Double?
    var volume: Double?
    var marketCap: Double?
}

struct BrapiPaginationDTO: Decodable, Sendable {
    var page: Int
    var limit: Int
    var totalItems: Int
    var totalPages: Int
    var hasNextPage: Bool
}

struct FIIIndicatorsResponse: Decodable, Sendable {
    var fiis: [FIIIndicatorDTO]
}

struct FIIIndicatorDTO: Decodable, Sendable {
    var symbol: String
    var name: String?
    var price: Double?
    var navPerShare: Double?
    var priceToNav: Double?
    var dividendYield12m: Double?
    var dividendYield1m: Double?
    var monthlyReturn: Double?
    var totalInvestors: Int?
    var sharesOutstanding: Double?
    var equity: Double?
    var totalAssets: Double?
    var segmentType: String?
    var segmentoAtuacao: String?
    var tipoGestao: String?
    var administratorName: String?
    var vacancyRate: Double?
}

struct QuoteListResponse: Decodable, Sendable {
    var results: [QuoteDTO]
}

struct QuoteDTO: Decodable, Sendable {
    var symbol: String
    var shortName: String?
    var longName: String?
    var regularMarketPrice: Double?
    var regularMarketChangePercent: Double?
    var regularMarketVolume: Double?
    var regularMarketPreviousClose: Double?
    var regularMarketDayHigh: Double?
    var regularMarketDayLow: Double?
    var fiftyTwoWeekHigh: Double?
    var fiftyTwoWeekLow: Double?
    var marketCap: Double?
    var logourl: String?
}

struct FIIDividendsResponse: Decodable, Sendable {
    var dividends: [FIIDividendDTO]
}

struct FIIDividendDTO: Decodable, Sendable {
    var symbol: String
    var label: String?
    var paymentDate: String?
    var lastDatePrior: String?
    var rate: Double?
}
