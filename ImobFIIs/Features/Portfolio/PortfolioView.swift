import SwiftData
import SwiftUI

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var holdings: [Holding]
    @State private var addHoldingDestination: AddHoldingDestination?

    private let catalog: any FIICatalogServing

    init(catalog: any FIICatalogServing = BrapiFIICatalogService()) {
        self.catalog = catalog
    }

    private var sortedHoldings: [Holding] {
        holdings.sorted { lhs, rhs in
            let left = lhs.fund?.ticker ?? ""
            let right = rhs.fund?.ticker ?? ""
            return left.localizedStandardCompare(right) == .orderedAscending
        }
    }

    var body: some View {
        Group {
            if holdings.isEmpty {
                emptyState
            } else {
                holdingsList
            }
        }
        .imobCanvas()
        .navigationTitle(L10n.Portfolio.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.Common.add, systemImage: "plus") {
                    addHoldingDestination = .pickFund
                }
            }
        }
        .sheet(item: $addHoldingDestination) { destination in
            switch destination {
            case .pickFund:
                AddHoldingSheet()
            case .fund(let summary):
                AddHoldingSheet(summary: summary)
            }
        }
    }

    private var holdingsList: some View {
        List {
            Section {
                portfolioHeader
            }
            .imobSurface()

            Section(L10n.Portfolio.positions) {
                ForEach(sortedHoldings) { holding in
                    if let fund = holding.fund {
                        NavigationLink(value: FundSummary(fund: fund)) {
                            HoldingRow(holding: holding)
                        }
                        .imobSurface()
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button(L10n.Portfolio.addShares, systemImage: "plus") {
                                addHoldingDestination = .fund(FundSummary(fund: fund))
                            }
                            .tint(.accentColor)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(L10n.Common.delete, systemImage: "trash", role: .destructive) {
                                modelContext.delete(holding)
                            }
                        }
                    }
                }
            }
        }
        .imobListCanvas()
        .navigationDestination(for: FundSummary.self) { summary in
            FundDetailView(summary: summary, catalog: catalog)
        }
    }

    private var portfolioHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Portfolio.netWorth)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(holdings.currentValue, format: .brl)
                    .font(.largeTitle.weight(.semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 16) {
                metric(
                    title: L10n.Portfolio.invested,
                    value: holdings.investedAmount
                )
                metric(
                    title: L10n.Portfolio.result,
                    value: holdings.profitAndLoss,
                    emphasizesSign: true
                )
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func metric(title: String, value: Decimal, emphasizesSign: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value, format: .brl)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(emphasizesSign ? (value >= 0 ? Color.green : Color.red) : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(L10n.Portfolio.emptyTitle, systemImage: "chart.pie")
        } description: {
            Text(L10n.Portfolio.emptyDescription)
        } actions: {
            Button(L10n.Portfolio.addFund) {
                addHoldingDestination = .pickFund
            }
            .imobPrimaryButton()
        }
    }
}

private enum AddHoldingDestination: Identifiable {
    case pickFund
    case fund(FundSummary)

    var id: String {
        switch self {
        case .pickFund:
            "pickFund"
        case .fund(let summary):
            summary.ticker
        }
    }
}

#Preview("Com posições") {
    let container = Persistence.makeContainer(inMemory: true)
    SampleData.seedIfNeeded(in: container.mainContext)
    if let fund = try? container.mainContext.fetch(FetchDescriptor<Fund>()).first {
        container.mainContext.insert(Holding(shares: 120, averagePrice: 98.5, fund: fund))
    }
    return NavigationStack {
        PortfolioView(catalog: MockFIICatalogService.preview)
    }
    .modelContainer(container)
}

#Preview("Vazia") {
    NavigationStack {
        PortfolioView(catalog: MockFIICatalogService.preview)
    }
    .modelContainer(Persistence.makeContainer(inMemory: true))
}
