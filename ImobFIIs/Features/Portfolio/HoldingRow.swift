import SwiftUI

struct HoldingRow: View {
    let holding: Holding

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(holding.fund?.ticker ?? "—")
                    .font(.headline)
                    .monospaced()
                Text("\(holding.shares) cotas · média \(holding.averagePrice.formatted(.brl))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(holding.currentValue, format: .brl)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(holding.profitAndLoss, format: .brl)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(holding.profitAndLoss >= 0 ? Color.green : Color.red)
            }
        }
        .padding(.vertical, 4)
    }
}
