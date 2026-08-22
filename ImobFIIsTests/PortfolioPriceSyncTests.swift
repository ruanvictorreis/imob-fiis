import Foundation
import Testing
@testable import ImobFIIs

@Suite("Atualização de preços da carteira")
struct PortfolioPriceSyncTests {
    @Test @MainActor
    func updatesPriceAndYieldFromIndicators() async {
        PortfolioPriceSync.resetSessionStateForTesting()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let fund = TestFunds.make(ticker: "MXRF11", price: 8)
        let catalog = MockFIICatalogService(
            page: MockFIICatalogService.sample.page,
            indicatorsByTicker: [
                "MXRF11": FIIIndicators(
                    ticker: "MXRF11",
                    name: "FII MAXI RENDA RL",
                    price: 9.50,
                    navPerShare: nil,
                    priceToNav: nil,
                    dividendYield12m: 0.11,
                    dividendYield1m: nil,
                    monthlyReturn: nil,
                    totalInvestors: nil,
                    equity: nil,
                    segmentType: nil,
                    segmentoAtuacao: nil,
                    tipoGestao: nil,
                    administratorName: nil,
                    vacancyRate: nil
                ),
            ]
        )

        await PortfolioPriceSync.refreshIfNeeded(
            [fund],
            using: catalog,
            defaults: defaults
        )

        #expect(fund.currentPrice == Decimal(string: "9.5"))
        #expect(fund.dividendYield == 0.11)
        #expect(defaults.object(forKey: PortfolioPriceSync.storageKey) is Date)
    }

    @Test @MainActor
    func keepsCachedPriceWhenIndicatorPriceIsMissingOrZero() async {
        PortfolioPriceSync.resetSessionStateForTesting()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let fund = TestFunds.make(ticker: "MXRF11", price: 8)
        let catalog = MockFIICatalogService(
            page: MockFIICatalogService.sample.page,
            indicatorsByTicker: [
                "MXRF11": FIIIndicators(
                    ticker: "MXRF11",
                    name: nil,
                    price: 0,
                    navPerShare: nil,
                    priceToNav: nil,
                    dividendYield12m: 0.12,
                    dividendYield1m: nil,
                    monthlyReturn: nil,
                    totalInvestors: nil,
                    equity: nil,
                    segmentType: nil,
                    segmentoAtuacao: nil,
                    tipoGestao: nil,
                    administratorName: nil,
                    vacancyRate: nil
                ),
            ]
        )

        await PortfolioPriceSync.refreshIfNeeded(
            [fund],
            using: catalog,
            defaults: defaults
        )

        #expect(fund.currentPrice == 8)
        #expect(fund.dividendYield == 0.12)
    }

    @Test @MainActor
    func runsOnlyOncePerSession() async {
        PortfolioPriceSync.resetSessionStateForTesting()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let fund = TestFunds.make(ticker: "MXRF11", price: 8)
        var catalog = MockFIICatalogService(
            page: MockFIICatalogService.sample.page,
            indicatorsByTicker: [
                "MXRF11": FIIIndicators(
                    ticker: "MXRF11",
                    name: nil,
                    price: 9,
                    navPerShare: nil,
                    priceToNav: nil,
                    dividendYield12m: nil,
                    dividendYield1m: nil,
                    monthlyReturn: nil,
                    totalInvestors: nil,
                    equity: nil,
                    segmentType: nil,
                    segmentoAtuacao: nil,
                    tipoGestao: nil,
                    administratorName: nil,
                    vacancyRate: nil
                ),
            ]
        )

        await PortfolioPriceSync.refreshIfNeeded([fund], using: catalog, defaults: defaults)
        #expect(fund.currentPrice == 9)

        catalog.indicatorsByTicker["MXRF11"] = FIIIndicators(
            ticker: "MXRF11",
            name: nil,
            price: 12,
            navPerShare: nil,
            priceToNav: nil,
            dividendYield12m: nil,
            dividendYield1m: nil,
            monthlyReturn: nil,
            totalInvestors: nil,
            equity: nil,
            segmentType: nil,
            segmentoAtuacao: nil,
            tipoGestao: nil,
            administratorName: nil,
            vacancyRate: nil
        )

        await PortfolioPriceSync.refreshIfNeeded([fund], using: catalog, defaults: defaults)
        #expect(fund.currentPrice == 9)
    }

    @Test @MainActor
    func skipsWhenMinimumIntervalHasNotElapsed() async {
        PortfolioPriceSync.resetSessionStateForTesting()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let now = Date()
        defaults.set(now, forKey: PortfolioPriceSync.storageKey)

        let fund = TestFunds.make(ticker: "MXRF11", price: 8)
        let catalog = MockFIICatalogService(
            page: MockFIICatalogService.sample.page,
            indicatorsByTicker: [
                "MXRF11": FIIIndicators(
                    ticker: "MXRF11",
                    name: nil,
                    price: 11,
                    navPerShare: nil,
                    priceToNav: nil,
                    dividendYield12m: nil,
                    dividendYield1m: nil,
                    monthlyReturn: nil,
                    totalInvestors: nil,
                    equity: nil,
                    segmentType: nil,
                    segmentoAtuacao: nil,
                    tipoGestao: nil,
                    administratorName: nil,
                    vacancyRate: nil
                ),
            ]
        )

        await PortfolioPriceSync.refreshIfNeeded(
            [fund],
            using: catalog,
            defaults: defaults,
            now: now.addingTimeInterval(60)
        )

        #expect(fund.currentPrice == 8)
    }
}
