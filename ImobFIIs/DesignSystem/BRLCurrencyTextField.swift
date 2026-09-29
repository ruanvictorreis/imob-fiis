import SwiftUI

struct BRLCurrencyTextField: View {
    @Binding var amount: Decimal?
    var placeholder: String = "R$ 0,00"

    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .monospacedDigit()
            .onAppear(perform: syncTextFromAmount)
            .onChange(of: text) { _, newValue in
                applyMask(to: newValue)
            }
            .onChange(of: amount) { _, _ in
                syncTextFromAmount()
            }
    }

    private func applyMask(to newValue: String) {
        let masked = BRLCurrencyMask.maskedText(fromTypedText: newValue)
        if masked != newValue {
            text = masked
        }
        let newAmount = BRLCurrencyMask.amount(fromCents: BRLCurrencyMask.cents(fromTypedText: masked))
        if newAmount != amount {
            amount = newAmount
        }
    }

    private func syncTextFromAmount() {
        let cents = BRLCurrencyMask.cents(fromAmount: amount)
        guard cents != BRLCurrencyMask.cents(fromTypedText: text) else { return }
        text = cents == 0 ? "" : BRLCurrencyMask.formatted(cents: cents)
    }
}
