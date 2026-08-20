import SwiftUI

struct HoldingRow: View {
    let holding: Holding

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(holding.fund?.ticker ?? L10n.Common.dash)
                    .font(.headline)
                    .monospaced()
                Text(
                    L10n.Holding.sharesAverage(
                        shares: holding.shares,
                        average: holding.averagePrice.formatted(.brl)
                    )
                )
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(holding.currentValue, format: .brl)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(holding.profitAndLoss, format: .brl)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(holding.profitAndLoss >= 0 ? Color.appPositive : Color.red)
            }
        }
        .padding(.vertical, 4)
    }
}
