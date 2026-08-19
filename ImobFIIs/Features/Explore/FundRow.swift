import SwiftUI

struct FundRow: View {
    let fund: Fund

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fund.segment.systemImage)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(fund.ticker)
                        .font(.headline)
                        .monospaced()
                    if fund.isInPortfolio {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Na carteira")
                    }
                }
                Text(fund.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(fund.currentPrice, format: .brl)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(fund.dividendYield, format: .fiiYield)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Dividend yield \(fund.dividendYield.formatted(.fiiYield))")
            }
        }
        .padding(.vertical, 4)
    }
}
