import SwiftUI

struct BRLCurrencyTextField: View {
    @Binding var amount: Decimal?
    var placeholder: String = "R$ 0,00"

    @State private var cents = 0

    var body: some View {
        TextField(placeholder, text: textBinding)
            .keyboardType(.numberPad)
            .monospacedDigit()
            .onAppear(perform: syncCentsFromAmount)
            .onChange(of: amount) { _, _ in
                syncCentsFromAmount()
            }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { cents == 0 ? "" : BRLCurrencyMask.formatted(cents: cents) },
            set: { newValue in
                cents = BRLCurrencyMask.cents(fromTypedText: newValue)
                amount = BRLCurrencyMask.amount(fromCents: cents)
            }
        )
    }

    private func syncCentsFromAmount() {
        let parsed = BRLCurrencyMask.cents(fromAmount: amount)
        guard parsed != cents else { return }
        cents = parsed
    }
}
