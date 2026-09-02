import SwiftUI

struct InsightsInsightRow: View {
    let insight: InsightItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline) {
                Text(insight.ticker)
                    .font(.headline)
                    .monospaced()
                Spacer(minLength: Spacing.xs)
                if let label = insight.sentimentLabel {
                    InsightSentimentBadge(label: label)
                }
                Text(insight.currentValue, format: .brl)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            Text(insight.segment.title)
                .font(.caption)
                .foregroundStyle(Color.appSecondaryText)
            if let summary = insight.sentimentSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
                    .lineLimit(2)
            }
            ForEach(reasonTexts, id: \.self) { reason in
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var reasonTexts: [String] {
        insight.reasons.map { reason in
            switch reason {
            case .segmentUnderweight(let currentWeight, let targetWeight):
                L10n.Insights.segmentGap(
                    segment: insight.segment.title,
                    current: percentText(currentWeight),
                    target: percentText(targetWeight)
                )
            case .lowestWeightInSegment:
                L10n.Insights.lowestWeightInSegment
            case .belowAveragePrice:
                L10n.Insights.belowAveragePrice
            case .nextPurchaseYield:
                L10n.Insights.nextPurchaseYield
            case .suggestedContribution(let amount):
                L10n.Insights.suggestedContribution(amount.formatted(.brl))
            case .positiveSentiment:
                L10n.Insights.sentimentPositive
            case .negativeSentiment:
                L10n.Insights.sentimentNegative
            case .neutralSentiment:
                L10n.Insights.sentimentNeutral
            }
        }
    }

    private func percentText(_ value: Double) -> String {
        value.formatted(
            .percent
                .precision(.fractionLength(0))
                .locale(Locale(identifier: "pt_BR"))
        )
    }
}
