import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class FundDetailViewModel {
    var summary: FundSummary
    var quote: FundQuote?
    var indicators: FIIIndicators?
    var isLoadingMarketData = false
    var lastDividend: Decimal?

    private let catalog: any FIICatalogServing

    init(summary: FundSummary, catalog: any FIICatalogServing = BrapiFIICatalogService()) {
        self.summary = summary
        self.catalog = catalog
    }

    var displayPrice: Decimal? {
        quote?.price ?? indicators?.price ?? summary.currentPrice
    }

    var displayChangePercent: Double? {
        quote?.changePercent ?? summary.changePercent
    }

    var displayVolume: Double? {
        quote?.volume ?? summary.volume
    }

    var displayName: String {
        quote?.longName ?? indicators?.name ?? summary.displayName
    }

    var manager: String {
        indicators?.administratorName ?? ""
    }

    func loadMarketData() async {
        isLoadingMarketData = true
        defer {
            if isLoadingMarketData {
                isLoadingMarketData = false
            }
        }

        async let fetchedQuote = catalog.quote(for: summary.ticker)
        async let fetchedIndicators = catalog.indicators(for: [summary.ticker])
        async let fetchedDividends = catalog.dividends(for: [summary.ticker])

        let quote = try? await fetchedQuote
        let indicatorsList = try? await fetchedIndicators
        let dividends = (try? await fetchedDividends) ?? []

        guard !Task.isCancelled else { return }

        withAnimation(.smooth(duration: 0.4)) {
            applyMarketData(
                quote: quote,
                indicators: indicatorsList?.first,
                dividends: dividends
            )
            isLoadingMarketData = false
        }
    }

    private func applyMarketData(
        quote: FundQuote?,
        indicators: FIIIndicators?,
        dividends: [FIIDividend]
    ) {
        if let quote {
            self.quote = quote
            apply(quote)
        }

        if let indicators {
            self.indicators = indicators
            if let price = indicators.price {
                summary.currentPrice = price
            }
            if let name = indicators.name, !name.isEmpty {
                summary.longName = name
            }
        }

        lastDividend = LastDividend.resolved(
            dividends: dividends,
            price: displayPrice,
            yield1m: self.indicators?.dividendYield1m
        )
    }

    private func apply(_ quote: FundQuote) {
        if let price = quote.price {
            summary.currentPrice = price
        }
        if let changePercent = quote.changePercent {
            summary.changePercent = changePercent
        }
        if let volume = quote.volume {
            summary.volume = volume
        }
        if let longName = quote.longName, !longName.isEmpty {
            summary.longName = longName
        }
    }
}
