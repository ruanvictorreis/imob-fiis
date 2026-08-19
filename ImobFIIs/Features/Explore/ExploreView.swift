import SwiftData
import SwiftUI

struct ExploreView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: ExploreViewModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        List {
            if !viewModel.searchText.isEmpty || viewModel.selectedSegment != nil {
                Section {
                    filterSummary
                }
            }

            ForEach(viewModel.groupedFunds, id: \.0) { segment, funds in
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
        .navigationDestination(for: FundSummary.self) { fund in
            FundDetailView(summary: fund)
        }
        .searchable(text: $viewModel.searchText, prompt: "Ticker ou nome")
        .searchFocused($isSearchFocused)
        .scrollDismissesKeyboard(.immediately)
        .background {
            DismissKeyboardOnTap {
                isSearchFocused = false
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Segmento", systemImage: "line.3.horizontal.decrease") {
                    Button("Todos") {
                        viewModel.selectedSegment = nil
                    }
                    Divider()
                    ForEach(viewModel.availableSegments) { segment in
                        Button {
                            viewModel.selectedSegment = segment
                        } label: {
                            Label(segment.rawValue, systemImage: segment.systemImage)
                        }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
            FundStore.syncSegments(viewModel.funds, in: modelContext)
        }
        .task {
            await viewModel.loadIfNeeded()
            FundStore.syncSegments(viewModel.funds, in: modelContext)
        }
        .overlay {
            overlayContent
        }
    }

    @ViewBuilder
    private var overlayContent: some View {
        if viewModel.isLoading && viewModel.funds.isEmpty {
            ProgressView("Carregando FIIs…")
        } else if let errorMessage = viewModel.errorMessage, viewModel.funds.isEmpty {
            ContentUnavailableView {
                Label("Não foi possível carregar os FIIs", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Tentar novamente") {
                    Task { await viewModel.refresh() }
                }
                .buttonStyle(.glassProminent)
            }
        } else if viewModel.displayedFunds.isEmpty {
            ContentUnavailableView.search(text: viewModel.searchText)
        }
    }

    private var filterSummary: some View {
        HStack {
            Text("\(viewModel.displayedFunds.count) fundos")
                .foregroundStyle(.secondary)
            Spacer()
            if let selectedSegment = viewModel.selectedSegment {
                Button {
                    viewModel.selectedSegment = nil
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
    NavigationStack {
        ExploreView(
            viewModel: ExploreViewModel(
                catalog: MockFIICatalogService.preview
            )
        )
    }
}
