import SwiftUI

struct InsightsNewsCoverageNote: View {
    let insights: [InsightItem]
    var now: Date = .now

    var body: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(L10n.Insights.newsCoverage(covered: coveredCount, total: insights.count))
                if let oldest {
                    Text(L10n.Insights.newsUpdated(FundNewsSection.relativeText(oldest)))
                }
                if isStale {
                    Label(L10n.Insights.newsStale, systemImage: "clock.badge.exclamationmark")
                        .foregroundStyle(Color.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(Color.appSecondaryText)
            .accessibilityElement(children: .combine)
        }
    }

    private var coveredCount: Int {
        insights.filter { $0.sentimentLabel != nil }.count
    }

    private var oldest: Date? {
        insights.compactMap(\.sentimentGeneratedAt).min()
    }

    private var isStale: Bool {
        oldest.map { SentimentFreshness.isStale($0, now: now) } ?? false
    }
}
