import SwiftData
import SwiftUI

struct AddHoldingSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Fund.ticker) private var funds: [Fund]

    let summary: FundSummary?
    let indicators: FIIIndicators?

    @State private var selectedFund: Fund?
    @State private var shares = 10
    @State private var priceText = ""

    init(summary: FundSummary? = nil, indicators: FIIIndicators? = nil) {
        self.summary = summary
        self.indicators = indicators
        if let price = summary?.currentPrice {
            _priceText = State(initialValue: NSDecimalNumber(decimal: price).stringValue)
        }
    }

    private var parsedPrice: Decimal? {
        let normalized = priceText.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    private var canSave: Bool {
        let hasFund = summary != nil || selectedFund != nil
        return hasFund && shares > 0 && (parsedPrice ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fundo") {
                    fundSection
                }

                Section("Posição") {
                    Stepper(value: $shares, in: 1...1_000_000) {
                        LabeledContent("Cotas", value: "\(shares)")
                    }

                    TextField("Preço médio", text: $priceText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Adicionar à carteira")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: selectedFund) { _, fund in
                guard summary == nil, let fund, priceText.isEmpty else { return }
                priceText = NSDecimalNumber(decimal: fund.currentPrice).stringValue
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var fundSection: some View {
        if let summary {
            LabeledContent("Ticker", value: summary.ticker)
            LabeledContent("Nome", value: summary.displayName)
        } else if funds.isEmpty {
            Text("Adicione um fundo pela aba Explorar para começar a montar a carteira.")
                .foregroundStyle(.secondary)
        } else {
            Picker("Ticker", selection: $selectedFund) {
                Text("Selecione").tag(nil as Fund?)
                ForEach(funds) { fund in
                    Text(fund.ticker).tag(fund as Fund?)
                }
            }
        }
    }

    private func save() {
        guard let price = parsedPrice else { return }

        let fund: Fund
        if let summary {
            fund = FundStore.upsert(summary, indicators: indicators, in: modelContext)
        } else if let selectedFund {
            fund = selectedFund
        } else {
            return
        }

        if let existing = fund.holdings.first {
            existing.addShares(shares, at: price)
        } else {
            modelContext.insert(Holding(shares: shares, averagePrice: price, fund: fund))
        }

        dismiss()
    }
}

#Preview {
    let container = Persistence.makeContainer(inMemory: true)
    SampleData.seedIfNeeded(in: container.mainContext)
    return AddHoldingSheet()
        .modelContainer(container)
}
