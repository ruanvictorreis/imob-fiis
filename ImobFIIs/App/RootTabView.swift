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
            Tab(value: .portfolio) {
                NavigationStack {
                    PortfolioView(catalog: exploreViewModel.catalog)
                }
            } label: {
                Label(L10n.Tab.portfolio, systemImage: "chart.pie.fill")
            }

            Tab(value: .explore) {
                NavigationStack {
                    ExploreView(viewModel: exploreViewModel)
                }
            } label: {
                Label(L10n.Tab.explore, systemImage: "building.columns.fill")
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
    case explore
    case search
}

#Preview {
    RootTabView(
        exploreViewModel: ExploreViewModel(catalog: MockFIICatalogService.preview)
    )
    .modelContainer(Persistence.makeContainer(inMemory: true))
}
