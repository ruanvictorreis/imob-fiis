import Foundation
import SwiftData

enum FundStore {
    @MainActor
    static func upsert(
        _ summary: FundSummary,
        indicators: FIIIndicators?,
        in context: ModelContext
    ) -> Fund {
        let ticker = summary.ticker
        var descriptor = FetchDescriptor<Fund>(
            predicate: #Predicate { $0.ticker == ticker }
        )
        descriptor.fetchLimit = 1

        let fund = (try? context.fetch(descriptor).first) ?? Fund(
            ticker: summary.ticker,
            name: summary.displayName,
            segment: summary.segment,
            manager: indicators?.administratorName ?? "",
            currentPrice: summary.currentPrice ?? 0,
            dividendYield: indicators?.dividendYield12m ?? 0,
            lastDividend: 0
        )

        fund.name = indicators?.name ?? summary.displayName
        fund.segment = summary.segment
        if let price = indicators?.price ?? summary.currentPrice {
            fund.currentPrice = price
        }
        if let yield = indicators?.dividendYield12m {
            fund.dividendYield = yield
        }
        if let manager = indicators?.administratorName, !manager.isEmpty {
            fund.manager = manager
        }
        if let vacancyRate = indicators?.vacancyRate {
            fund.vacancyRate = vacancyRate
        }

        if fund.modelContext == nil {
            context.insert(fund)
        }

        return fund
    }
}
