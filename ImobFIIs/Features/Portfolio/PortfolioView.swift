import SwiftData
import SwiftUI

struct PortfolioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Holding.purchasedAt, order: .reverse) private var holdings: [Holding]
    @State private var isAddingHolding = false

    var body: some View {
        Group {
            if holdings.isEmpty {
                emptyState
            } else {
                holdingsList
            }
        }
        .navigationTitle("Carteira")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Adicionar", systemImage: "plus") {
                    isAddingHolding = true
                }
            }
        }
        .sheet(isPresented: $isAddingHolding) {
            AddHoldingSheet()
        }
    }

    private var holdingsList: some View {
        List {
            Section {
                portfolioHeader
            }

            Section("Posições") {
                ForEach(holdings) { holding in
                    if let fund = holding.fund {
                        NavigationLink(value: fund) {
                            HoldingRow(holding: holding)
                        }
                    }
                }
                .onDelete(perform: deleteHoldings)
            }
        }
        .navigationDestination(for: Fund.self) { fund in
            FundDetailView(fund: fund)
        }
    }

    private var portfolioHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Patrimônio")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(holdings.currentValue, format: .brl)
                    .font(.largeTitle.weight(.semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 16) {
                metric(
                    title: "Investido",
                    value: holdings.investedAmount
                )
                metric(
                    title: "Resultado",
                    value: holdings.profitAndLoss,
                    emphasizesSign: true
                )
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func metric(title: String, value: Decimal, emphasizesSign: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value, format: .brl)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(emphasizesSign ? (value >= 0 ? Color.green : Color.red) : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Sua carteira está vazia", systemImage: "chart.pie")
        } description: {
            Text("Adicione fundos imobiliários para acompanhar cotações, dividend yield e proventos.")
        } actions: {
            Button("Adicionar fundo") {
                isAddingHolding = true
            }
            .buttonStyle(.glassProminent)
        }
    }

    private func deleteHoldings(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(holdings[index])
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
