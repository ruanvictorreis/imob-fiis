import SwiftUI

struct HoldingRow: View {
    let holding: Holding

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
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

            Spacer(minLength: Spacing.xs)

            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(holding.currentValue, format: .brl)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(holding.profitAndLoss, format: .brl)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(holding.profitAndLoss >= 0 ? Color.appPositive : Color.red)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }
}
