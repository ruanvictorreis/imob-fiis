import SwiftData
import SwiftUI

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var holdings: [Holding]
    @State private var positionSheet: PositionSheet?

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
                    positionSheet = .addNew
                }
                .tint(.accentColor)
            }
        }
        .sheet(item: $positionSheet) { destination in
            switch destination {
            case .addNew:
                AddHoldingSheet()
            case .edit(let ticker):
                if let holding = holdings.first(where: { $0.fund?.ticker == ticker }) {
                    EditHoldingSheet(holding: holding)
                }
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(L10n.Common.delete, systemImage: "trash", role: .destructive) {
                                modelContext.delete(holding)
                            }
                            .tint(.red)
                            Button(L10n.Portfolio.editPosition, systemImage: "pencil") {
                                presentSheet(.edit(ticker: fund.ticker))
                            }
                            .tint(.accentColor)
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

    private func presentSheet(_ sheet: PositionSheet) {
        Task { @MainActor in
            positionSheet = sheet
        }
    }

    private var portfolioHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Portfolio.netWorth)
                    .font(.subheadline)
                    .foregroundStyle(Color.appSecondaryText)
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
                .foregroundStyle(Color.appSecondaryText)
            Text(value, format: .brl)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(emphasizesSign ? (value >= 0 ? Color.appPositive : Color.red) : Color.appPrimaryText)
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
                positionSheet = .addNew
            }
            .imobPrimaryButton()
        }
    }
}

private enum PositionSheet: Identifiable {
    case addNew
    case edit(ticker: String)

    var id: String {
        switch self {
        case .addNew:
            "addNew"
        case .edit(let ticker):
            "edit-\(ticker)"
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
        PortfolioView()
    }
    .modelContainer(container)
}

#Preview("Vazia") {
    NavigationStack {
        PortfolioView()
    }
    .modelContainer(Persistence.makeContainer(inMemory: true))
}
