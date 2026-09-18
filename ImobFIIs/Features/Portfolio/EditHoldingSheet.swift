import SwiftData
import SwiftUI

struct EditHoldingSheet: View {
    @Environment(\.dismiss) private var dismiss

    let holding: Holding

    @State private var sharesText: String
    @State private var price: Decimal?
    @FocusState private var focusedField: Field?

    init(holding: Holding) {
        self.holding = holding
        _sharesText = State(initialValue: String(holding.shares))
        _price = State(initialValue: holding.averagePrice)
    }

    private var shares: Int {
        Int(sharesText) ?? 0
    }

    private var canSave: Bool {
        shares > 0 && (price ?? 0) > 0 && hasChanges
    }

    private var hasChanges: Bool {
        guard let price else { return false }
        return shares != holding.shares || price != holding.averagePrice
    }

    private var fundDisplayName: String {
        guard let fund = holding.fund else { return L10n.Common.dash }
        return FundSummary(fund: fund).displayName
    }

    private var previewInvested: Decimal? {
        guard shares > 0, let price, price > 0 else { return nil }
        return price * Decimal(shares)
    }

    private var previewProfitAndLoss: Decimal? {
        guard let invested = previewInvested else { return nil }
        let currentPrice = holding.fund?.currentPrice ?? 0
        return currentPrice * Decimal(shares) - invested
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.AddHolding.fund) {
                    LabeledContent(L10n.Common.ticker, value: holding.fund?.ticker ?? L10n.Common.dash)
                    LabeledContent(L10n.Common.name, value: fundDisplayName)
                }
                .imobSurface()

                Section {
                    HoldingInputField(
                        title: L10n.AddHolding.shares,
                        isFocused: focusedField == .shares,
                        onSelect: { focusedField = .shares },
                        field: {
                            TextField("0", text: $sharesText)
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .shares)
                                .onChange(of: sharesText) { _, newValue in
                                    sharesText = sanitizedShareCount(from: newValue)
                                }
                        },
                    )

                    HoldingInputField(
                        title: L10n.AddHolding.averagePrice,
                        isFocused: focusedField == .price,
                        onSelect: { focusedField = .price },
                        field: {
                            BRLCurrencyTextField(amount: $price)
                                .focused($focusedField, equals: .price)
                        },
                    )
                } header: {
                    Text(L10n.AddHolding.position)
                } footer: {
                    Text(L10n.EditHolding.helper)
                }
                .imobSurface()

                if let previewInvested, let previewProfitAndLoss {
                    Section {
                        LabeledContent(L10n.Portfolio.invested) {
                            Text(previewInvested, format: .brl)
                                .monospacedDigit()
                        }
                        LabeledContent(L10n.Portfolio.result) {
                            Text(previewProfitAndLoss, format: .brl)
                                .monospacedDigit()
                                .foregroundStyle(previewProfitAndLoss >= 0 ? Color.appPositive : Color.red)
                        }
                    }
                    .imobSurface()
                }
            }
            .imobListCanvas()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L10n.EditHolding.title)
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
            .task {
                try? await Task.sleep(for: .milliseconds(350))
                focusedField = .price
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.appBackground)
        .imobAppearance()
    }

    private var saveButton: some View {
        Button(L10n.Common.save) {
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
        holding.replacePosition(shares: shares, averagePrice: price)
        dismiss()
    }

    private func sanitizedShareCount(from raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        guard let value = Int(digits) else { return digits }
        return String(min(value, 1_000_000))
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
    return EditHoldingSheet(holding: holding)
        .modelContainer(container)
}
