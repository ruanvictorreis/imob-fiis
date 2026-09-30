import SwiftData
import SwiftUI

struct SellHoldingSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let holding: Holding

    @State private var sharesText = ""
    @State private var price: Decimal?
    @State private var saleDate = Date.now
    @FocusState private var focusedField: Field?

    init(holding: Holding) {
        self.holding = holding
        let currentPrice = holding.fund?.currentPrice ?? 0
        _price = State(initialValue: currentPrice > 0 ? currentPrice : nil)
    }

    private var shares: Int {
        Int(sharesText) ?? 0
    }

    private var exceedsPosition: Bool {
        shares > holding.shares
    }

    private var canSave: Bool {
        shares > 0 && !exceedsPosition && (price ?? 0) > 0
    }

    private var realizedResult: Decimal? {
        guard canSave, let price else { return nil }
        return (price - holding.averagePrice) * Decimal(shares)
    }

    private var remainingPositionText: String? {
        guard let projected = holding.projectedPosition(selling: shares) else { return nil }
        guard projected.shares > 0 else { return L10n.SellHolding.closesPosition }
        return L10n.SellHolding.remainingPosition(
            shares: projected.shares,
            average: projected.averagePrice.formatted(.brl)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.AddHolding.currentPosition) {
                    LabeledContent(L10n.Common.ticker, value: holding.ticker)
                    Text(
                        L10n.AddHolding.currentPositionValue(
                            shares: holding.shares,
                            average: holding.averagePrice.formatted(.brl)
                        )
                    )
                    .foregroundStyle(Color.appSecondaryText)
                }
                .imobSurface()

                Section {
                    sharesField
                    HoldingInputField(
                        title: L10n.SellHolding.price,
                        isFocused: focusedField == .price,
                        onSelect: { focusedField = .price },
                        field: {
                            BRLCurrencyTextField(amount: $price)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .price)
                        }
                    )
                    DatePicker(
                        L10n.SellHolding.date,
                        selection: $saleDate,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                } footer: {
                    if exceedsPosition {
                        Text(L10n.SellHolding.exceedsPosition(holding.shares))
                            .foregroundStyle(.red)
                    }
                }
                .imobSurface()

                if let remainingPositionText {
                    summarySection(remainingPositionText)
                }
            }
            .imobListCanvas()
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(L10n.SellHolding.title)
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
        }
        .presentationDetents([.large])
        .presentationBackground(Color.appBackground)
        .imobAppearance()
    }

    private var sharesField: some View {
        LabeledContent(L10n.SellHolding.shares) {
            HStack(spacing: Spacing.xs) {
                Button(L10n.SellHolding.sellAll) {
                    sharesText = String(holding.shares)
                }
                .buttonStyle(.glass)
                .tint(.accentColor)
                .controlSize(.small)

                TextField("0", text: $sharesText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused($focusedField, equals: .shares)
                    .onChange(of: sharesText) { _, newValue in
                        sharesText = newValue.filter(\.isNumber)
                    }
            }
        }
    }

    private func summarySection(_ remainingPositionText: String) -> some View {
        Section {
            Text(remainingPositionText)
                .font(.subheadline)
                .foregroundStyle(Color.appSecondaryText)
            if let realizedResult {
                LabeledContent(L10n.SellHolding.realizedResult) {
                    Text(realizedResult, format: .brl)
                        .monospacedDigit()
                        .foregroundStyle(realizedResult >= 0 ? Color.appPositive : Color.red)
                }
            }
        }
        .imobSurface()
    }

    private var saveButton: some View {
        Button(L10n.SellHolding.confirm) {
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
        guard let price else { return }
        let recorded = PortfolioLedger.recordSell(
            ticker: holding.ticker,
            shares: shares,
            price: price,
            date: saleDate,
            in: modelContext
        )
        if recorded {
            dismiss()
        }
    }

    private enum Field: Hashable {
        case shares
        case price
    }
}

#Preview {
    let container = Persistence.makeContainer(inMemory: true)
    SampleData.seedIfNeeded(in: container.mainContext)
    let fund = try? container.mainContext.fetch(FetchDescriptor<Fund>()).first
    let holding = Holding(shares: 120, averagePrice: 98.5, fund: fund)
    container.mainContext.insert(holding)
    return SellHoldingSheet(holding: holding)
        .modelContainer(container)
}
