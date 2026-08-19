import SwiftData
import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: AppTab = .portfolio
    @Query(sort: \Holding.purchasedAt, order: .reverse) private var holdings: [Holding]

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Carteira", systemImage: "chart.pie.fill", value: .portfolio) {
                NavigationStack {
                    PortfolioView()
                }
            }

            Tab("Explorar", systemImage: "building.columns.fill", value: .explore) {
                NavigationStack {
                    ExploreView()
                }
            }

            Tab(value: .search, role: .search) {
                NavigationStack {
                    ExploreView()
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
    let container = Persistence.makeContainer(inMemory: true)
    SampleData.seedIfNeeded(in: container.mainContext)
    return RootTabView()
        .modelContainer(container)
}
