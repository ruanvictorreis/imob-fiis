import SwiftData
import SwiftUI

struct AddHoldingSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Fund.ticker) private var funds: [Fund]

    let preselectedFund: Fund?

    @State private var selectedFund: Fund?
    @State private var shares = 10
    @State private var priceText = ""

    init(preselectedFund: Fund? = nil) {
        self.preselectedFund = preselectedFund
        _selectedFund = State(initialValue: preselectedFund)
        if let preselectedFund {
            _priceText = State(initialValue: NSDecimalNumber(decimal: preselectedFund.currentPrice).stringValue)
        }
    }

    private var parsedPrice: Decimal? {
        let normalized = priceText.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }

    private var canSave: Bool {
        selectedFund != nil && shares > 0 && (parsedPrice ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fundo") {
                    if preselectedFund == nil {
                        Picker("Ticker", selection: $selectedFund) {
                            Text("Selecione").tag(nil as Fund?)
                            ForEach(funds) { fund in
                                Text(fund.ticker).tag(fund as Fund?)
                            }
                        }
                    } else if let selectedFund {
                        LabeledContent("Ticker", value: selectedFund.ticker)
                        LabeledContent("Nome", value: selectedFund.name)
                    }
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
                guard preselectedFund == nil, let fund, priceText.isEmpty else { return }
                priceText = NSDecimalNumber(decimal: fund.currentPrice).stringValue
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let fund = selectedFund, let price = parsedPrice else { return }

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
