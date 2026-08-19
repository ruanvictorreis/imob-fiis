import SwiftData
import SwiftUI

struct PortfolioSummaryAccessory: View {
    let holdings: [Holding]
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "brazilianrealsign.circle.fill")
                .font(isExpanded ? .title2 : .body)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Proventos estimados")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isExpanded {
                    Text("Último rendimento × cotas")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            Text(holdings.estimatedMonthlyIncome, format: .brl)
                .font(isExpanded ? .headline : .subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal)
        .padding(.vertical, isExpanded ? 8 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Proventos estimados \(holdings.estimatedMonthlyIncome.formatted(.brl))")
    }

    private var isExpanded: Bool {
        placement == .expanded
    }
}
