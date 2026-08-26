import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .portfolio
    @State private var exploreViewModel: ExploreViewModel
    @Query(sort: \Holding.purchasedAt, order: .reverse) private var holdings: [Holding]

    init(exploreViewModel: ExploreViewModel = ExploreViewModel()) {
        _exploreViewModel = State(initialValue: exploreViewModel)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(L10n.Tab.portfolio, systemImage: "chart.pie.fill", value: .portfolio) {
                NavigationStack {
                    PortfolioView(catalog: exploreViewModel.catalog)
                }
            }

            Tab(L10n.Tab.insights, systemImage: "sparkles", value: .insights) {
                NavigationStack {
                    InsightsView(catalog: exploreViewModel.catalog) { segment in
                        exploreViewModel.searchText = ""
                        exploreViewModel.selectedSegment = segment
                        selectedTab = .explore
                    }
                }
            }

            Tab(L10n.Tab.explore, systemImage: "building.columns.fill", value: .explore) {
                NavigationStack {
                    ExploreView(viewModel: exploreViewModel)
                }
            }

            Tab(value: .search, role: .search) {
                NavigationStack {
                    ExploreView(viewModel: exploreViewModel)
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: !holdings.isEmpty) {
            PortfolioSummaryAccessory()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .imobAppearance()
        .task {
            FundStore.repairSegments(in: modelContext)
        }
        .task(id: portfolioRefreshKey) {
            await refreshPortfolioData()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshPortfolioData() }
        }
    }

    private var portfolioRefreshKey: String {
        holdings.compactMap(\.fund?.ticker).sorted().joined(separator: ",")
    }

    private func refreshPortfolioData() async {
        let funds = holdings.compactMap(\.fund)
        await PortfolioPriceSync.refreshIfNeeded(funds, using: portfolioMarketDataSource)
    }

    private var portfolioMarketDataSource: FallbackPortfolioMarketDataService {
        FallbackPortfolioMarketDataService(
            primary: YahooMarketDataService(),
            fallback: BrapiQuoteMarketDataService(catalog: exploreViewModel.catalog)
        )
    }
}

private enum AppTab: Hashable {
    case portfolio
    case insights
    case explore
    case search
}

#Preview {
    RootTabView()
        .modelContainer(Persistence.makeContainer(inMemory: true))
}
