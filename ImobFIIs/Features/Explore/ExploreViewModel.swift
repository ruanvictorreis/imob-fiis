import Foundation
import Observation

@MainActor
@Observable
final class ExploreViewModel {
    var searchText = ""
    var selectedSegment: FundSegment?
    var funds: [FundSummary] = []
    var isLoading = false
    var errorMessage: String?

    let catalog: any FIICatalogServing
    private var hasLoaded = false

    init(catalog: any FIICatalogServing = BrapiFIICatalogService()) {
        self.catalog = catalog
    }

    var displayedFunds: [FundSummary] {
        funds.filter { fund in
            let matchesSegment = selectedSegment.map { $0 == fund.segment } ?? true
            let matchesSearch = searchText.isEmpty
                || fund.ticker.localizedStandardContains(searchText)
                || fund.displayName.localizedStandardContains(searchText)
            return matchesSegment && matchesSearch
        }
    }

    var groupedFunds: [(FundSegment, [FundSummary])] {
        Dictionary(grouping: displayedFunds, by: \.segment)
            .map { segment, funds in
                (segment, funds.sorted {
                    ($0.volume ?? 0) > ($1.volume ?? 0)
                })
            }
            .sorted { $0.0.rawValue < $1.0.rawValue }
    }

    var availableSegments: [FundSegment] {
        let present = Set(funds.map(\.segment))
        return FundSegment.allCases.filter { present.contains($0) }
    }

    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let page = try await catalog.tickers(.allFIIs)
            funds = page.funds
            hasLoaded = true
        } catch is CancellationError {
            return
        } catch {
            if funds.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }
}
