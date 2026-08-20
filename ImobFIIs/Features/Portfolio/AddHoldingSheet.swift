import SwiftData
import SwiftUI

struct AddHoldingSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Fund.ticker) private var funds: [Fund]
    @Query private var holdings: [Holding]

    let summary: FundSummary?
    let indicators: FIIIndicators?
    let lastDividend: Decimal?

    @State private var selectedFund: Fund?
    @State private var sharesText = ""
    @State private var price: Decimal?
    @FocusState private var focusedField: Field?

    init(
        summary: FundSummary? = nil,
        indicators: FIIIndicators? = nil,
        lastDividend: Decimal? = nil
    ) {
        self.summary = summary
        self.indicators = indicators
        self.lastDividend = lastDividend
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
                Section(L10n.AddHolding.fund) {
                    fundSection
                }
                .imobSurface()

                if let existingHolding {
                    Section(L10n.AddHolding.currentPosition) {
                        Text(
                            L10n.AddHolding.currentPositionValue(
                                shares: existingHolding.shares,
                                average: existingHolding.averagePrice.formatted(.brl)
                            )
                        )
                        .foregroundStyle(Color.appSecondaryText)
                    }
                    .imobSurface()
                }

                Section(isAddingToExisting ? L10n.AddHolding.thisPurchase : L10n.AddHolding.position) {
                    LabeledContent(
                        isAddingToExisting ? L10n.AddHolding.sharesThisPurchase : L10n.AddHolding.shares
                    ) {
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

                    LabeledContent(
                        isAddingToExisting ? L10n.AddHolding.priceThisPurchase : L10n.AddHolding.averagePrice
                    ) {
                        TextField("R$ 0,00", value: $price, format: .brlInput)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .focused($focusedField, equals: .price)
                    }
                }
                .imobSurface()

                if let projectedPositionText {
                    Section {
                        Text(projectedPositionText)
                            .font(.subheadline)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                    .imobSurface()
                }
            }
            .imobListCanvas()
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(
                isAddingToExisting ? L10n.AddHolding.addSharesTitle : L10n.AddHolding.addToPortfolioTitle
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                    .accessibilityLabel(L10n.Common.close)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.Common.ok) {
                        focusedField = nil
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveButton
            }
            .onChange(of: selectedFund) { _, fund in
                guard summary == nil, let fund else { return }
                price = fund.currentPrice
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.appBackground)
        .imobAppearance()
    }

    private var projectedPositionText: String? {
        guard let existingHolding,
              let price,
              let projected = existingHolding.projectedPosition(adding: shares, at: price)
        else { return nil }

        return L10n.AddHolding.projectedPosition(
            shares: projected.shares,
            average: projected.averagePrice.formatted(.brl)
        )
    }

    private var shareQuickAddButtons: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach([1, 5, 10, 50, 100], id: \.self) { amount in
                Button("+\(amount)") {
                    addShares(amount)
                }
                .buttonStyle(.glass)
                .tint(.accentColor)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
            }
        }
        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.sm, bottom: Spacing.xs, trailing: Spacing.sm))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.AddHolding.shareShortcuts)
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
            LabeledContent(L10n.Common.ticker, value: summary.ticker)
            LabeledContent(L10n.Common.name, value: summary.displayName)
        } else if funds.isEmpty {
            Text(L10n.AddHolding.emptyFunds)
                .foregroundStyle(Color.appSecondaryText)
        } else {
            Picker(L10n.Common.ticker, selection: $selectedFund) {
                Text(L10n.Common.select).tag(nil as Fund?)
                ForEach(funds) { fund in
                    Text(fund.ticker).tag(fund as Fund?)
                }
            }
        }
    }

    private var saveButton: some View {
        Button(isAddingToExisting ? L10n.Common.add : L10n.Common.save) {
            save()
        }
        .imobPrimaryButton()
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.lg)
        .disabled(!canSave)
    }

    private func save() {
        guard let price, price > 0 else { return }

        let fund: Fund
        if let summary {
            fund = FundStore.upsert(
                summary,
                indicators: indicators,
                lastDividend: lastDividend,
                in: modelContext
            )
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
    let fund = try? container.mainContext.fetch(FetchDescriptor<Fund>()).first
    if let fund {
        container.mainContext.insert(Holding(shares: 120, averagePrice: 98.5, fund: fund))
    }
    return AddHoldingSheet(summary: fund.map(FundSummary.init(fund:)))
        .modelContainer(container)
}
