import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
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
                    InsightsView(catalog: exploreViewModel.catalog)
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
        .task(id: dividendRefreshKey) {
            await LastDividendSync.refreshStaleFunds(
                holdings.compactMap(\.fund),
                using: exploreViewModel.catalog
            )
        }
    }

    private var dividendRefreshKey: String {
        holdings.compactMap(\.fund?.ticker).sorted().joined(separator: ",")
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
