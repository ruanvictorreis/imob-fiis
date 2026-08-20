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
                .imobSurface()
            }

            ForEach(viewModel.groupedFunds, id: \.0) { segment, funds in
                Section(segment.title) {
                    ForEach(funds) { fund in
                        NavigationLink(value: fund) {
                            FundRow(fund: fund)
                        }
                        .imobSurface()
                    }
                }
            }
        }
        .imobListCanvas()
        .navigationTitle(L10n.Explore.title)
        .navigationDestination(for: FundSummary.self) { fund in
            FundDetailView(summary: fund, catalog: viewModel.catalog)
        }
        .searchable(text: $viewModel.searchText, prompt: L10n.Explore.searchPrompt)
        .searchFocused($isSearchFocused)
        .scrollDismissesKeyboard(.immediately)
        .background {
            DismissKeyboardOnTap {
                isSearchFocused = false
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu(L10n.Explore.segmentFilter, systemImage: "line.3.horizontal.decrease") {
                    Button(L10n.Common.all) {
                        viewModel.selectedSegment = nil
                    }
                    Divider()
                    ForEach(viewModel.availableSegments) { segment in
                        Button {
                            viewModel.selectedSegment = segment
                        } label: {
                            Label(segment.title, systemImage: segment.systemImage)
                        }
                    }
                }
                .tint(.accentColor)
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
            ProgressView(L10n.Explore.loading)
        } else if let errorMessage = viewModel.errorMessage, viewModel.funds.isEmpty {
            ContentUnavailableView {
                Label(L10n.Explore.loadError, systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button(L10n.Common.retry) {
                    Task { await viewModel.refresh() }
                }
                .imobPrimaryButton()
            }
        } else if viewModel.displayedFunds.isEmpty {
            ContentUnavailableView.search(text: viewModel.searchText)
        }
    }

    private var filterSummary: some View {
        HStack {
            Text(L10n.Explore.fundsCount(viewModel.displayedFunds.count))
                .foregroundStyle(Color.appSecondaryText)
            Spacer()
            if let selectedSegment = viewModel.selectedSegment {
                Button {
                    viewModel.selectedSegment = nil
                } label: {
                    Label(selectedSegment.title, systemImage: "xmark")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExploreView(viewModel: ExploreViewModel())
    }
}
