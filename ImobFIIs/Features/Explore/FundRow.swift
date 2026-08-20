import SwiftUI

struct FundRow: View {
    let fund: FundSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fund.segment.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(fund.ticker)
                    .font(.headline)
                    .monospaced()
                Text(fund.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if let price = fund.currentPrice {
                    Text(price, format: .brl)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                } else {
                    Text(L10n.Common.dash)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let changePercent = fund.changePercent {
                    Text(changePercent, format: .marketChange)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(changePercent >= 0 ? Color.green : Color.red)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
