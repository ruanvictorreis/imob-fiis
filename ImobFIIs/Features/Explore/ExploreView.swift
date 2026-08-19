import SwiftData
import SwiftUI

struct ExploreView: View {
    @Query(sort: \Fund.ticker) private var funds: [Fund]
    @State private var searchText = ""
    @State private var selectedSegment: FundSegment?

    private var filteredFunds: [Fund] {
        funds.filter { fund in
            let matchesSegment = selectedSegment.map { fund.segment == $0 } ?? true
            let matchesSearch = searchText.isEmpty
                || fund.ticker.localizedStandardContains(searchText)
                || fund.name.localizedStandardContains(searchText)
                || fund.manager.localizedStandardContains(searchText)
            return matchesSegment && matchesSearch
        }
    }

    private var groupedFunds: [(FundSegment, [Fund])] {
        Dictionary(grouping: filteredFunds, by: \.segment)
            .map { ($0.key, $0.value.sorted { $0.ticker < $1.ticker }) }
            .sorted { $0.0.rawValue < $1.0.rawValue }
    }

    var body: some View {
        List {
            if !searchText.isEmpty || selectedSegment != nil {
                Section {
                    filterSummary
                }
            }

            ForEach(groupedFunds, id: \.0) { segment, funds in
                Section(segment.rawValue) {
                    ForEach(funds) { fund in
                        NavigationLink(value: fund) {
                            FundRow(fund: fund)
                        }
                    }
                }
            }
        }
        .navigationTitle("Explorar")
        .navigationDestination(for: Fund.self) { fund in
            FundDetailView(fund: fund)
        }
        .searchable(text: $searchText, prompt: "Ticker, nome ou gestora")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Segmento", systemImage: "line.3.horizontal.decrease") {
                    Button("Todos") {
                        selectedSegment = nil
                    }
                    Divider()
                    ForEach(FundSegment.allCases) { segment in
                        Button {
                            selectedSegment = segment
                        } label: {
                            Label(segment.rawValue, systemImage: segment.systemImage)
                        }
                    }
                }
            }
        }
        .overlay {
            if filteredFunds.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private var filterSummary: some View {
        HStack {
            Text("\(filteredFunds.count) fundos")
                .foregroundStyle(.secondary)
            Spacer()
            if let selectedSegment {
                Button {
                    self.selectedSegment = nil
                } label: {
                    Label(selectedSegment.rawValue, systemImage: "xmark")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
        }
    }
}

#Preview {
    let container = Persistence.makeContainer(inMemory: true)
    SampleData.seedIfNeeded(in: container.mainContext)
    return NavigationStack {
        ExploreView()
    }
    .modelContainer(container)
}
