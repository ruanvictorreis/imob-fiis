import SwiftData
import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: AppTab = .portfolio
    @State private var exploreViewModel: ExploreViewModel
    @Query(sort: \Holding.purchasedAt, order: .reverse) private var holdings: [Holding]

    init(exploreViewModel: ExploreViewModel = ExploreViewModel()) {
        _exploreViewModel = State(initialValue: exploreViewModel)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Carteira", systemImage: "chart.pie.fill", value: .portfolio) {
                NavigationStack {
                    PortfolioView()
                }
            }

            Tab("Explorar", systemImage: "building.columns.fill", value: .explore) {
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
            PortfolioSummaryAccessory(holdings: holdings)
        }
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
