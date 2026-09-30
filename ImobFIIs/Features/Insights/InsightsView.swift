import SwiftData
import SwiftUI

struct InsightsView: View {
    private let catalog: any FIICatalogServing
    private let sentimentService: SentimentReportService
    private let onExploreSegment: ((FundSegment) -> Void)?

    @State private var targetsStore: AllocationTargetsStore
    @State private var isEditingTargets = false
    @State private var isSimulatingContribution = false
    @State private var sentimentContext = SentimentContext.empty
    @State private var hasLoadedSentiment = false
    @State private var snapshotCache = InsightSnapshotCache()

    @Query private var holdings: [Holding]

    init(
        catalog: any FIICatalogServing,
        sentimentService: SentimentReportService = SentimentReportService(),
        targetsStore: AllocationTargetsStore = .live(),
        onExploreSegment: ((FundSegment) -> Void)? = nil
    ) {
        self.catalog = catalog
        self.sentimentService = sentimentService
        self.onExploreSegment = onExploreSegment
        _targetsStore = State(initialValue: targetsStore)
    }

    private var strategy: CustomAllocationStrategy {
        targetsStore.strategy
    }

    private var snapshot: InsightSnapshot {
        snapshotCache.snapshot(for: holdings, strategy: strategy, sentiment: sentimentContext)
    }

    private var activeAllocations: [SegmentAllocation] {
        snapshot.allocations.filter { $0.targetWeight > 0 }
    }

    var body: some View {
        Group {
            if holdings.isEmpty {
                emptyPortfolio
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
        .sheet(isPresented: $isSimulatingContribution) {
            ContributionSimulatorView(holdings: holdings, strategy: strategy)
        }
        .onAppear {
            presentTargetsEditorIfNeeded()
        }
        .task(id: sentimentTaskKey) {
            await loadSentiment()
        }
        .navigationDestination(for: FundSummary.self) { summary in
            FundDetailView(summary: summary, catalog: catalog)
        }
    }

    private var insightsList: some View {
        List {
            if !targetsStore.hasSavedTargets {
                setTargetsPromptSection
            }

            analysisNoticeSection

            allocationSection

            if let first = snapshot.insights.first {
                Section(L10n.Insights.largestGap) {
                    insightLink(first)
                }
                .imobSurface()
            }

            if snapshot.insights.count > 1 {
                Section(L10n.Insights.otherPositions) {
                    ForEach(snapshot.insights.dropFirst()) { insight in
                        insightLink(insight)
                    }
                }
                .imobSurface()
            }

            if !snapshot.missingSegments.isEmpty {
                Section {
                    ForEach(snapshot.missingSegments) { missing in
                        MissingSegmentInsightRow(
                            missing: missing,
                            onExplore: onExploreSegment.map { explore in
                                { explore(missing.segment) }
                            }
                        )
                    }
                } header: {
                    Text(L10n.Insights.missingSegments)
                } footer: {
                    Text(L10n.Insights.missingSegmentsFooter)
                }
                .imobSurface()
            }

            disclaimerSection
        }
        .imobListCanvas()
    }

    private var setTargetsPromptSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(L10n.Insights.setTargetsTitle)
                    .font(.headline)
                Text(L10n.Insights.setTargetsDescription)
                    .font(.caption)
                    .foregroundStyle(Color.appSecondaryText)
                Button(L10n.Insights.setTargetsAction) {
                    isEditingTargets = true
                }
                .imobPrimaryButton()
                .controlSize(.small)
            }
            .padding(.vertical, Spacing.xxs)
        }
        .imobSurface()
    }

    private var analysisNoticeSection: some View {
        Section {
            Text(L10n.Insights.analysisNotice)
                .font(.caption)
                .foregroundStyle(Color.appSecondaryText)
            if hasLoadedSentiment {
                InsightsNewsCoverageNote(insights: snapshot.insights)
            }
        }
        .imobSurface()
    }

    private var allocationSection: some View {
        Section(L10n.Insights.allocation) {
            Text(strategy.title)
                .font(.caption)
                .foregroundStyle(Color.appSecondaryText)
            ForEach(activeAllocations) { allocation in
                SegmentAllocationRow(allocation: allocation)
            }
            Button {
                isSimulatingContribution = true
            } label: {
                Label(L10n.Simulator.open, systemImage: "banknote")
            }
        }
        .imobSurface()
    }

    private var disclaimerSection: some View {
        Section {
            Text(L10n.Insights.disclaimer)
                .font(.footnote)
                .foregroundStyle(Color.appSecondaryText)
        }
        .imobSurface()
    }

    private func insightLink(_ insight: InsightItem) -> some View {
        Group {
            if let summary = fundSummary(for: insight.ticker) {
                NavigationLink(value: summary) {
                    InsightsInsightRow(insight: insight, showsMissingNews: hasLoadedSentiment)
                }
            } else {
                InsightsInsightRow(insight: insight, showsMissingNews: hasLoadedSentiment)
            }
        }
    }

    private var sentimentTaskKey: String {
        let segments = holdings.compactMap(\.fund?.segment)
            .filter { (strategy.targetWeights[$0] ?? 0) > 0 }
            .map(\.sentimentKey)
        return segments.sorted().joined(separator: ",")
    }

    private func loadSentiment() async {
        let segmentKeys = Set(
            holdings.compactMap(\.fund?.segment)
                .filter { (strategy.targetWeights[$0] ?? 0) > 0 }
                .map(\.sentimentKey)
                .filter { $0 != "other" }
        )
        guard !segmentKeys.isEmpty else {
            sentimentContext = .empty
            hasLoadedSentiment = true
            return
        }
        let context = await sentimentService.reports(for: Array(segmentKeys))
        guard !Task.isCancelled else { return }
        sentimentContext = context
        hasLoadedSentiment = true
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
            .first { $0.ticker == ticker }
            .flatMap(\.fund)
            .map(FundSummary.init(fund:))
    }

    private func presentTargetsEditorIfNeeded() {
        guard targetsStore.shouldAutoPresentTargetsEditor else { return }
        targetsStore.markTargetsPrompted()
        isEditingTargets = true
    }

    private var emptyPortfolio: some View {
        ContentUnavailableView {
            Label(L10n.Insights.emptyTitle, systemImage: "sparkles")
        } description: {
            Text(L10n.Insights.emptyDescription)
        } actions: {
            if !targetsStore.hasSavedTargets {
                Button(L10n.Insights.setTargetsAction) {
                    isEditingTargets = true
                }
                .imobPrimaryButton()
            }
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
        InsightsView(catalog: ResilientFIICatalogService())
    }
    .modelContainer(container)
}

#Preview("Vazia") {
    NavigationStack {
        InsightsView(catalog: ResilientFIICatalogService())
    }
    .modelContainer(Persistence.makeContainer(inMemory: true))
}
