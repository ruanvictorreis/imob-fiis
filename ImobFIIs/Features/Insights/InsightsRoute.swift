import Foundation

enum InsightsRoute: Hashable {
    case contributionSimulator
    case segmentHoldings(SegmentContribution)
    case fund(FundSummary, suggestedContribution: Decimal?)
}
