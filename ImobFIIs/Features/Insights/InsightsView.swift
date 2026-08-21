import SwiftData
import SwiftUI

struct InsightsView: View {
    private let catalog: any FIICatalogServing

    @State private var targetsStore: AllocationTargetsStore
    @State private var isEditingTargets = false

    @Query private var holdings: [Holding]

    init(
        catalog: any FIICatalogServing,
        targetsStore: AllocationTargetsStore = AllocationTargetsStore()
    ) {
        self.catalog = catalog
        _targetsStore = State(initialValue: targetsStore)
    }

    private var strategy: CustomAllocationStrategy {
        targetsStore.strategy
    }

    private var snapshot: InsightSnapshot {
        InsightEngine.evaluate(holdings, strategy: strategy)
    }

    private var hasStrategyHoldings: Bool {
        holdings.contains { holding in
            guard let segment = holding.fund?.segment else { return false }
            return (strategy.targetWeights[segment] ?? 0) > 0
        }
    }

    var body: some View {
        Group {
            if holdings.isEmpty {
                emptyPortfolio
            } else if !hasStrategyHoldings {
                emptyNoMatch
            } else {
                insightsList
            }
        }
        .imobCanvas()
        .navigationTitle(L10n.Insights.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditingTargets = true
                } label: {
                    Label(L10n.Insights.editAllocation, systemImage: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $isEditingTargets) {
            EditAllocationTargetsView(store: targetsStore)
        }
        .navigationDestination(for: FundSummary.self) { summary in
            FundDetailView(summary: summary, catalog: catalog)
        }
    }

    private var insightsList: some View {
        List {
            allocationSection

            if let first = snapshot.insights.first {
                Section(L10n.Insights.nextContribution) {
                    insightLink(first)
                }
                .imobSurface()
            }

            if snapshot.insights.count > 1 {
                Section(L10n.Insights.otherOptions) {
                    ForEach(snapshot.insights.dropFirst()) { insight in
                        insightLink(insight)
                    }
                }
                .imobSurface()
            }

            disclaimerSection
        }
        .imobListCanvas()
    }

    private var allocationSection: some View {
        Section(L10n.Insights.allocation) {
            Text(strategy.title)
                .font(.caption)
                .foregroundStyle(Color.appSecondaryText)
            ForEach(activeAllocations) { allocation in
                allocationRow(allocation)
            }
        }
        .imobSurface()
    }

    private var activeAllocations: [SegmentAllocation] {
        snapshot.allocations.filter { $0.targetWeight > 0 }
    }

    private var disclaimerSection: some View {
        Section {
            Text(L10n.Insights.disclaimer)
                .font(.footnote)
                .foregroundStyle(Color.appSecondaryText)
        }
        .imobSurface()
    }

    private func allocationRow(_ allocation: SegmentAllocation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
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
            allocationBar(allocation)
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    private func allocationBar(_ allocation: SegmentAllocation) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appBackground)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * targetProgress(allocation))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    private func targetProgress(_ allocation: SegmentAllocation) -> Double {
        guard allocation.targetWeight > 0 else { return 0 }
        return min(max(allocation.currentWeight / allocation.targetWeight, 0), 1)
    }

    private func insightLink(_ insight: InsightItem) -> some View {
        Group {
            if let summary = fundSummary(for: insight.ticker) {
                NavigationLink(value: summary) {
                    insightRow(insight)
                }
            } else {
                insightRow(insight)
            }
        }
    }

    private func insightRow(_ insight: InsightItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline) {
                Text(insight.ticker)
                    .font(.headline)
                    .monospaced()
                Spacer(minLength: Spacing.xs)
                Text(insight.currentValue, format: .brl)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            Text(insight.segment.title)
                .font(.caption)
                .foregroundStyle(Color.appSecondaryText)
            ForEach(reasonTexts(for: insight), id: \.self) { reason in
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private func reasonTexts(for insight: InsightItem) -> [String] {
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

    private func fundSummary(for ticker: String) -> FundSummary? {
        holdings
            .first { $0.fund?.ticker == ticker }
            .flatMap(\.fund)
            .map(FundSummary.init(fund:))
    }

    private var emptyPortfolio: some View {
        ContentUnavailableView {
            Label(L10n.Insights.emptyTitle, systemImage: "sparkles")
        } description: {
            Text(L10n.Insights.emptyDescription)
        }
    }

    private var emptyNoMatch: some View {
        ContentUnavailableView {
            Label(L10n.Insights.noMatchTitle, systemImage: "sparkles")
        } description: {
            Text(L10n.Insights.noMatchDescription)
        }
    }
}

#Preview("Com posições") {
    let container = Persistence.makeContainer(inMemory: true)
    SampleData.seedIfNeeded(in: container.mainContext)
    if let fund = try? container.mainContext.fetch(FetchDescriptor<Fund>()).first {
        container.mainContext.insert(Holding(shares: 120, averagePrice: 98.5, fund: fund))
    }
    return NavigationStack {
        InsightsView(catalog: BrapiFIICatalogService())
    }
    .modelContainer(container)
}

#Preview("Vazia") {
    NavigationStack {
        InsightsView(catalog: BrapiFIICatalogService())
    }
    .modelContainer(Persistence.makeContainer(inMemory: true))
}
