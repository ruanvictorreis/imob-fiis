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
                    EditHoldingField(
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

                    EditHoldingField(
                        title: L10n.AddHolding.averagePrice,
                        isFocused: focusedField == .price,
                        onSelect: { focusedField = .price },
                        field: {
                            TextField("R$ 0,00", value: $price, format: .brlInput)
                                .keyboardType(.decimalPad)
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
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 20)
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

private struct EditHoldingField<FieldContent: View>: View {
    let title: String
    let isFocused: Bool
    let onSelect: () -> Void
    @ViewBuilder var field: () -> FieldContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.appSecondaryText)

            HStack(spacing: 8) {
                field()
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHint(L10n.EditHolding.tapToEdit)
                Button(action: onSelect) {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.EditHolding.tapToEdit)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isFocused ? Color.accentColor : .clear, lineWidth: 1)
            }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        .listRowSeparator(.hidden)
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
