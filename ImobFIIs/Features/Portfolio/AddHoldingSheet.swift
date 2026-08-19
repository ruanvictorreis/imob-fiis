import SwiftData
import SwiftUI

struct AddHoldingSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Fund.ticker) private var funds: [Fund]
    @Query private var holdings: [Holding]

    let summary: FundSummary?
    let indicators: FIIIndicators?

    @State private var selectedFund: Fund?
    @State private var sharesText = ""
    @State private var price: Decimal?
    @FocusState private var focusedField: Field?

    init(summary: FundSummary? = nil, indicators: FIIIndicators? = nil) {
        self.summary = summary
        self.indicators = indicators
        _price = State(initialValue: summary?.currentPrice)
    }

    private var shares: Int {
        Int(sharesText) ?? 0
    }

    private var existingHolding: Holding? {
        guard let ticker = summary?.ticker ?? selectedFund?.ticker else { return nil }
        return holdings.first { $0.fund?.ticker == ticker }
    }

    private var isAddingToExisting: Bool {
        existingHolding != nil
    }

    private var canSave: Bool {
        let hasFund = summary != nil || selectedFund != nil
        return hasFund && shares > 0 && (price ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fundo") {
                    fundSection
                }

                if let existingHolding {
                    Section("Posição atual") {
                        Text("Você tem \(existingHolding.shares) cotas · média \(existingHolding.averagePrice.formatted(.brl))")
                            .foregroundStyle(.secondary)
                    }
                }

                Section(isAddingToExisting ? "Nesta compra" : "Posição") {
                    LabeledContent(isAddingToExisting ? "Cotas nesta compra" : "Cotas") {
                        TextField("0", text: $sharesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .focused($focusedField, equals: .shares)
                            .onChange(of: sharesText) { _, newValue in
                                sharesText = sanitizedShareCount(from: newValue)
                            }
                    }

                    shareQuickAddButtons

                    LabeledContent(isAddingToExisting ? "Preço desta compra" : "Preço médio") {
                        TextField("R$ 0,00", value: $price, format: .brlInput)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .focused($focusedField, equals: .price)
                    }
                }

                if let projectedPositionText {
                    Section {
                        Text(projectedPositionText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .safeAreaPadding(.bottom, 20)
            .navigationTitle(isAddingToExisting ? "Adicionar cotas" : "Adicionar à carteira")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isAddingToExisting ? "Adicionar" : "Salvar") {
                        save()
                    }
                    .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") {
                        focusedField = nil
                    }
                }
            }
            .onChange(of: selectedFund) { _, fund in
                guard summary == nil, let fund else { return }
                price = fund.currentPrice
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.thickMaterial)
    }

    private var projectedPositionText: String? {
        guard let existingHolding,
              let price,
              let projected = existingHolding.projectedPosition(adding: shares, at: price)
        else { return nil }

        return "Nova posição: \(projected.shares) cotas · nova média \(projected.averagePrice.formatted(.brl))"
    }

    private var shareQuickAddButtons: some View {
        HStack(spacing: 4) {
            ForEach([1, 5, 10, 50, 100], id: \.self) { amount in
                Button("+\(amount)") {
                    addShares(amount)
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Atalhos de cotas")
    }

    private func addShares(_ amount: Int) {
        sharesText = sanitizedShareCount(from: String(min(shares + amount, 1_000_000)))
    }

    private func sanitizedShareCount(from raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        guard let value = Int(digits) else { return digits }
        return String(min(value, 1_000_000))
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
        guard let price, price > 0 else { return }

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

    private enum Field: Hashable {
        case shares
        case price
    }
}

#Preview("Nova posição") {
    let container = Persistence.makeContainer(inMemory: true)
    SampleData.seedIfNeeded(in: container.mainContext)
    return AddHoldingSheet()
        .modelContainer(container)
}

#Preview("Adicionar cotas") {
    let container = Persistence.makeContainer(inMemory: true)
    SampleData.seedIfNeeded(in: container.mainContext)
    let fund = try! container.mainContext.fetch(FetchDescriptor<Fund>()).first!
    container.mainContext.insert(Holding(shares: 120, averagePrice: 98.5, fund: fund))
    return AddHoldingSheet(summary: FundSummary(fund: fund))
        .modelContainer(container)
}
