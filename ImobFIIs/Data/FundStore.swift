import Foundation
import SwiftData

enum FundStore {
    @MainActor
    @discardableResult
    static func upsert(
        _ summary: FundSummary,
        indicators: FIIIndicators?,
        lastDividend: Decimal? = nil,
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
        applyLastDividend(lastDividend, indicators: indicators, summary: summary, to: fund)

        if fund.modelContext == nil {
            context.insert(fund)
            FundCacheRevision.shared.fundInserted()
        }

        return fund
    }

    /// Posições sincronizadas de outro aparelho chegam só com o ticker; busca os fundos
    /// que ainda não estão no cache local.
    ///
    /// Os indicadores de FII exigem plano pago da brapi; sem eles, usa a listagem do catálogo
    /// (plano gratuito), que traz preço e segmento.
    @MainActor
    static func cacheMissingFunds(
        for tickers: [String],
        using catalog: any FIICatalogServing,
        in context: ModelContext
    ) async {
        let cached = Set(((try? context.fetch(FetchDescriptor<Fund>())) ?? []).map(\.ticker))
        var missing = Set(tickers.filter { !$0.isEmpty }).subtracting(cached)
        guard !missing.isEmpty else { return }

        let indicators = (try? await catalog.indicators(for: missing.sorted())) ?? []
        for item in indicators where missing.remove(item.ticker) != nil {
            let name = item.name ?? item.ticker
            let summary = FundSummary(
                ticker: item.ticker,
                name: name,
                segment: FundSegment.fromAPI(
                    subsector: item.segmentoAtuacao,
                    subType: item.segmentType,
                    name: "\(item.ticker) \(name)"
                ),
                currentPrice: item.price
            )
            upsert(summary, indicators: item, in: context)
        }

        guard !missing.isEmpty, let page = try? await catalog.tickers(.allFIIs) else { return }
        for summary in page.funds where missing.remove(summary.ticker) != nil {
            upsert(summary, indicators: nil, in: context)
        }
    }

    private static func applyLastDividend(
        _ lastDividend: Decimal?,
        indicators: FIIIndicators?,
        summary: FundSummary,
        to fund: Fund
    ) {
        let resolved = lastDividend ?? LastDividend.estimate(
            price: indicators?.price ?? summary.currentPrice ?? fund.currentPrice,
            yield1m: indicators?.dividendYield1m
        )
        guard let resolved, resolved > 0 else { return }
        if lastDividend == nil, fund.lastDividend > 0 { return }
        fund.lastDividend = resolved
        fund.lastDividendUpdatedAt = .now
    }

    @MainActor
    static func repairSegments(in context: ModelContext) {
        guard let funds = try? context.fetch(FetchDescriptor<Fund>()) else { return }

        for fund in funds {
            let repaired = FundSegment.fromAPI(
                subsector: fund.segmentRaw,
                name: "\(fund.ticker) \(fund.name)"
            )
            if fund.segment != repaired {
                fund.segment = repaired
            }
        }
    }

    @MainActor
    static func syncSegments(_ summaries: [FundSummary], in context: ModelContext) {
        guard !summaries.isEmpty else { return }
        let byTicker = Dictionary(uniqueKeysWithValues: summaries.map { ($0.ticker, $0) })
        guard let funds = try? context.fetch(FetchDescriptor<Fund>()) else { return }

        for fund in funds {
            guard let summary = byTicker[fund.ticker], fund.segment != summary.segment else { continue }
            fund.segment = summary.segment
        }
    }
}
