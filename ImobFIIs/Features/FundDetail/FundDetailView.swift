import SwiftData
import SwiftUI

struct FundDetailView: View {
    @Bindable var fund: Fund
    @State private var isAddingHolding = false

    var body: some View {
        List {
            Section {
                header
            }

            Section("Indicadores") {
                LabeledContent("Preço atual") {
                    Text(fund.currentPrice, format: .brl)
                        .monospacedDigit()
                }
                LabeledContent("Dividend yield") {
                    Text(fund.dividendYield, format: .fiiYield)
                        .monospacedDigit()
                }
                LabeledContent("Último provento") {
                    Text(fund.lastDividend, format: .brl)
                        .monospacedDigit()
                }
                if let vacancyRate = fund.vacancyRate {
                    LabeledContent("Vacância") {
                        Text(vacancyRate, format: .fiiYield)
                            .monospacedDigit()
                    }
                }
            }

            Section("Sobre") {
                LabeledContent("Segmento", value: fund.segment.rawValue)
                LabeledContent("Gestora", value: fund.manager)
            }

            if let holding = fund.holdings.first {
                Section("Na carteira") {
                    LabeledContent("Cotas", value: "\(holding.shares)")
                    LabeledContent("Preço médio") {
                        Text(holding.averagePrice, format: .brl)
                            .monospacedDigit()
                    }
                    LabeledContent("Valor atual") {
                        Text(holding.currentValue, format: .brl)
                            .monospacedDigit()
                    }
                    LabeledContent("Resultado") {
                        Text(holding.profitAndLoss, format: .brl)
                            .monospacedDigit()
                            .foregroundStyle(holding.profitAndLoss >= 0 ? Color.green : Color.red)
                    }
                }
            }
        }
        .navigationTitle(fund.ticker)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button(fund.isInPortfolio ? "Adicionar cotas" : "Adicionar à carteira", systemImage: "plus") {
                    isAddingHolding = true
                }
                .buttonStyle(.glassProminent)
            }
        }
        .sheet(isPresented: $isAddingHolding) {
            AddHoldingSheet(preselectedFund: fund)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(fund.segment.rawValue, systemImage: fund.segment.systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(fund.name)
                .font(.title2.weight(.semibold))
            Text(fund.manager)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let container = Persistence.makeContainer(inMemory: true)
    SampleData.seedIfNeeded(in: container.mainContext)
    let fund = (try? container.mainContext.fetch(FetchDescriptor<Fund>()).first)!
    return NavigationStack {
        FundDetailView(fund: fund)
    }
    .modelContainer(container)
}
