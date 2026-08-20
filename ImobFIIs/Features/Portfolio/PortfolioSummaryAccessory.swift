import SwiftData
import SwiftUI

struct PortfolioSummaryAccessory: View {
    @Query private var holdings: [Holding]
    @Query private var funds: [Fund]
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "brazilianrealsign.circle.fill")
                .font(isExpanded ? .title2 : .body)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Accessory.estimatedIncome)
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
                if isExpanded {
                    Text(L10n.Accessory.estimatedIncomeFormula)
                        .font(.caption2)
                        .foregroundStyle(Color.appSecondaryText)
                }
            }

            Spacer(minLength: 8)

            Text(estimatedMonthlyIncome, format: .brl)
                .font(isExpanded ? .headline : .subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal)
        .padding(.vertical, isExpanded ? 8 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Accessory.estimatedIncomeAccessibility(estimatedMonthlyIncome.formatted(.brl)))
    }

    private var estimatedMonthlyIncome: Decimal {
        let rates = Dictionary(uniqueKeysWithValues: funds.map { ($0.ticker, $0.lastDividend) })
        return holdings.reduce(0) { partial, holding in
            let ticker = holding.fund?.ticker
            let rate = ticker.flatMap { rates[$0] } ?? 0
            return partial + (rate * Decimal(holding.shares))
        }
    }

    private var isExpanded: Bool {
        placement == .expanded
    }
}
