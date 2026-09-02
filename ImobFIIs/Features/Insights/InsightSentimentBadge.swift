import SwiftUI

struct InsightSentimentBadge: View {
    let label: SentimentLabel

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, Spacing.xxs)
            .padding(.vertical, Spacing.xxxs)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
    }

    private var text: String {
        switch label {
        case .positive: L10n.Insights.sentimentPositive
        case .neutral: L10n.Insights.sentimentNeutral
        case .negative: L10n.Insights.sentimentNegative
        }
    }

    private var foreground: Color {
        switch label {
        case .positive: Color.appPositive
        case .neutral: Color.appSecondaryText
        case .negative: Color.red
        }
    }

    private var background: Color {
        switch label {
        case .positive: Color.appPositive.opacity(0.15)
        case .neutral: Color.appBackground
        case .negative: Color.red.opacity(0.15)
        }
    }
}
