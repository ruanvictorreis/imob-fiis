import SwiftData
import SwiftUI

struct MockFIICatalogService: FIICatalogServing {
    var page: FIITickerPage
    var indicatorsByTicker: [String: FIIIndicators] = [:]
    var quotesByTicker: [String: FundQuote] = [:]

    func tickers(_ query: FIITickerQuery) async throws -> FIITickerPage {
        _ = query
        return page
    }

    func quote(for symbol: String) async throws -> FundQuote? {
        quotesByTicker[symbol]
    }

    func indicators(for symbols: [String]) async throws -> [FIIIndicators] {
        symbols.compactMap { indicatorsByTicker[$0] }
    }

    static let preview = MockFIICatalogService(
        page: FIITickerPage(
            funds: [
                FundSummary(
                    ticker: "MXRF11",
                    name: "MXRF11",
                    longName: "Maxi Renda Fundo de Investimento Imobiliário",
                    segment: .logistics,
                    currentPrice: 9.29,
                    changePercent: 0.0043,
                    volume: 1_899_639,
                    logoURL: nil
                ),
                FundSummary(
                    ticker: "HGLG11",
                    name: "HGLG11",
                    longName: "Pátria Log Fundo de Investimento Imobiliário",
                    segment: .logistics,
                    currentPrice: 145.90,
                    changePercent: 0.0054,
                    volume: 131_172,
                    logoURL: nil
                ),
                FundSummary(
                    ticker: "XPML11",
                    name: "XPML11",
                    longName: "XP Malls Fundo de Investimento Imobiliário",
                    segment: .malls,
                    currentPrice: 104.20,
                    changePercent: -0.0031,
                    volume: 80_000,
                    logoURL: nil
                ),
            ],
            totalItems: 3
        ),
        indicatorsByTicker: [
            "MXRF11": FIIIndicators(
                ticker: "MXRF11",
                name: "FII MAXI RENDA RL",
                price: 9.29,
                navPerShare: 9.26,
                priceToNav: 0.998,
                dividendYield12m: 0.129,
                dividendYield1m: 0.01,
                monthlyReturn: 0.008,
                totalInvestors: 1_509_087,
                equity: 4_331_102_700,
                segmentType: "papel",
                segmentoAtuacao: "Logística",
                tipoGestao: "Ativa",
                administratorName: "BTG Pactual",
                vacancyRate: nil
            ),
        ],
        quotesByTicker: [
            "MXRF11": FundQuote(
                ticker: "MXRF11",
                shortName: "MXRF11",
                longName: "Maxi Renda Fundo de Investimento Imobiliário",
                price: 9.29,
                changePercent: 0.0043,
                volume: 1_899_639,
                previousClose: 9.25,
                dayHigh: 9.35,
                dayLow: 9.20,
                fiftyTwoWeekHigh: 10.80,
                fiftyTwoWeekLow: 8.90,
                marketCap: nil
            ),
        ]
    )
}
