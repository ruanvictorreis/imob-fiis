import SwiftUI

struct FundRow: View {
    let fund: FundSummary

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: fund.segment.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(fund.ticker)
                    .font(.headline)
                    .monospaced()
                Text(fund.displayName)
                    .font(.subheadline)
                    .foregroundStyle(Color.appSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.xs)

            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                if let price = fund.currentPrice {
                    Text(price, format: .brl)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                } else {
                    Text(L10n.Common.dash)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appSecondaryText)
                }

                if let changePercent = fund.changePercent {
                    Text(changePercent, format: .marketChange)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(changePercent >= 0 ? Color.appPositive : Color.red)
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }
}
