import SwiftUI

struct SegmentAllocationRow: View {
    let allocation: SegmentAllocation

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Label(allocation.segment.title, systemImage: allocation.segment.systemImage)
                Spacer(minLength: Spacing.xs)
                Text(percentText(allocation.currentWeight))
                    .monospacedDigit()
                    .foregroundStyle(
                        allocation.isUnderweight(tolerance: InsightEngine.allocationTolerance)
                            ? Color.accentColor
                            : Color.appPrimaryText
                    )
                Text(L10n.Insights.target(percentText(allocation.targetWeight)))
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }
            allocationBar
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    private var allocationBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appBackground)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * targetProgress)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    private var targetProgress: Double {
        guard allocation.targetWeight > 0 else { return 0 }
        return min(max(allocation.currentWeight / allocation.targetWeight, 0), 1)
    }

    private func percentText(_ value: Double) -> String {
        value.formatted(
            .percent
                .precision(.fractionLength(0))
                .locale(Locale(identifier: "pt_BR"))
        )
    }
}
