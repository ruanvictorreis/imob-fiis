import SwiftData
import SwiftUI

struct SegmentHoldingsView: View {
    let contribution: SegmentContribution
    let strategy: any AllocationStrategy
    let sentiment: SentimentContext
    var showsMissingNews = false
    var onExploreSegment: (() -> Void)?

    @Query private var holdings: [Holding]
    @State private var snapshotCache = InsightSnapshotCache()

    private var insights: [InsightItem] {
        snapshotCache.snapshot(for: holdings, strategy: strategy, sentiment: sentiment)
            .insights(in: contribution.segment)
    }

    var body: some View {
        let insights = insights

        Group {
            if insights.isEmpty {
                emptySegment
            } else {
                List {
                    suggestionSection

                    Section {
                        ForEach(insights) { insight in
                            insightLink(insight)
                        }
                    } header: {
                        Text(L10n.Simulator.segmentHoldings)
                    } footer: {
                        Text(L10n.Simulator.segmentHoldingsFooter)
                    }
                    .imobSurface()
                }
                .imobListCanvas()
            }
        }
        .imobCanvas()
        .navigationTitle(contribution.segment.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var suggestionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                LabeledContent(L10n.Simulator.suggestedForSegment) {
                    Text(contribution.amount, format: .brl)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                Text(
                    L10n.Simulator.weightChange(
                        current: percentText(contribution.currentWeight),
                        projected: percentText(contribution.projectedWeight),
                        target: percentText(contribution.targetWeight)
                    )
                )
                .font(.caption)
                .foregroundStyle(Color.appSecondaryText)
                .monospacedDigit()
            }
            .padding(.vertical, Spacing.xxs)
            .accessibilityElement(children: .combine)
        }
        .imobSurface()
    }

    @ViewBuilder
    private func insightLink(_ insight: InsightItem) -> some View {
        if let summary = fundSummary(for: insight.ticker) {
            NavigationLink(
                value: InsightsRoute.fund(summary, suggestedContribution: suggestedContribution)
            ) {
                InsightsInsightRow(insight: insight, showsMissingNews: showsMissingNews)
            }
        } else {
            InsightsInsightRow(insight: insight, showsMissingNews: showsMissingNews)
        }
    }

    private var suggestedContribution: Decimal? {
        contribution.amount > 0 ? contribution.amount : nil
    }

    private var emptySegment: some View {
        ContentUnavailableView {
            Label(contribution.segment.title, systemImage: contribution.segment.systemImage)
        } description: {
            Text(L10n.Simulator.emptySegment)
        } actions: {
            if let onExploreSegment {
                Button(L10n.Insights.exploreSegment(contribution.segment.title), action: onExploreSegment)
                    .imobPrimaryButton()
            }
        }
    }

    private func fundSummary(for ticker: String) -> FundSummary? {
        holdings
            .first { $0.ticker == ticker }
            .flatMap(\.fund)
            .map(FundSummary.init(fund:))
    }

    private func percentText(_ value: Double) -> String {
        value.formatted(
            .percent
                .precision(.fractionLength(0))
                .locale(Locale(identifier: "pt_BR"))
        )
    }
}
