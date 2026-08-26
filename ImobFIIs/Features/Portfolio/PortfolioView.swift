import SwiftData
import SwiftUI

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var holdings: [Holding]
    @State private var positionSheet: PositionSheet?
    @State private var isRefreshingMarketData = false
    @State private var lastPriceRefreshDate: Date?
    @State private var didFailLastRefresh = false

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
                Button {
                    Task { await refreshMarketData() }
                } label: {
                    if isRefreshingMarketData {
                        ProgressView()
                    } else {
                        Label(L10n.Portfolio.refresh, systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshingMarketData || holdings.isEmpty)
                .accessibilityLabel(L10n.Portfolio.refresh)
            }
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
        .onAppear {
            syncRefreshStatusFromStore()
        }
        .onReceive(NotificationCenter.default.publisher(for: .portfolioMarketDataDidSync)) { notification in
            let key = PortfolioPriceSync.outcomeUserInfoKey
            applySyncOutcome(notification.userInfo?[key] as? PortfolioPriceSyncOutcome)
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
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(L10n.Portfolio.netWorth)
                    .font(.subheadline)
                    .foregroundStyle(Color.appSecondaryText)
                Text(holdings.currentValue, format: .brl)
                    .font(.largeTitle.weight(.semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                marketDataStatusText
            }

            HStack(spacing: Spacing.md) {
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
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private func metric(title: String, value: Decimal, emphasizesSign: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxxs) {
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

    @ViewBuilder
    private var marketDataStatusText: some View {
        if didFailLastRefresh {
            Text(L10n.Portfolio.refreshFailed)
                .font(.caption)
                .foregroundStyle(Color.red)
        } else if let lastPriceRefreshDate {
            Text(L10n.Portfolio.updatedAt(lastPriceRefreshDate.formatted(date: .omitted, time: .shortened)))
                .font(.caption)
                .foregroundStyle(Color.appSecondaryText)
        }
    }

    private func refreshMarketData() async {
        guard !isRefreshingMarketData else { return }
        isRefreshingMarketData = true
        defer { isRefreshingMarketData = false }

        let funds = holdings.compactMap(\.fund)
        let source = FallbackPortfolioMarketDataService(
            primary: YahooMarketDataService(),
            fallback: BrapiQuoteMarketDataService(catalog: catalog)
        )
        let outcome = await PortfolioPriceSync.refreshIfNeeded(funds, using: source, force: true)
        applySyncOutcome(outcome)
    }

    private func syncRefreshStatusFromStore() {
        lastPriceRefreshDate = PortfolioPriceSync.lastPriceRefreshDate(for: holdings.compactMap(\.fund))
    }

    private func applySyncOutcome(_ outcome: PortfolioPriceSyncOutcome?) {
        syncRefreshStatusFromStore()
        switch outcome {
        case .failed:
            didFailLastRefresh = true
        case .updated:
            didFailLastRefresh = false
        case .skipped, .none:
            break
        }
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
