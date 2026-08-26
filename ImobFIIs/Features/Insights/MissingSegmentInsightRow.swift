import SwiftUI

struct MissingSegmentInsightRow: View {
    let missing: MissingSegmentInsight
    let onExplore: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Label(missing.segment.title, systemImage: missing.segment.systemImage)
                    .font(.headline)
                Spacer(minLength: Spacing.xs)
                Text(percentText(missing.currentWeight))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                Text(L10n.Insights.target(percentText(missing.targetWeight)))
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }

            Text(
                L10n.Insights.missingSegmentGap(
                    segment: missing.segment.title,
                    current: percentText(missing.currentWeight),
                    target: percentText(missing.targetWeight)
                )
            )
            .font(.caption)
            .foregroundStyle(Color.appSecondaryText)

            if let amount = missing.suggestedContribution {
                Text(L10n.Insights.suggestedContribution(amount.formatted(.brl)))
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }

            if let onExplore {
                Button(action: onExplore) {
                    Text(L10n.Insights.exploreSegment(missing.segment.title))
                        .frame(maxWidth: .infinity)
                }
                .imobPrimaryButton()
                .controlSize(.small)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private func percentText(_ value: Double) -> String {
        value.formatted(
            .percent
                .precision(.fractionLength(0))
                .locale(Locale(identifier: "pt_BR"))
        )
    }
}
