import SwiftData
import SwiftUI

struct FundDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var holdings: [Holding]
    @State private var viewModel: FundDetailViewModel
    @State private var isAddingHolding = false
    @State private var isEditingHolding = false

    init(summary: FundSummary, catalog: any FIICatalogServing = BrapiFIICatalogService()) {
        _viewModel = State(
            initialValue: FundDetailViewModel(summary: summary, catalog: catalog)
        )
    }

    var body: some View {
        List {
            Section {
                header
            }
            .imobSurface()

            Section(L10n.FundDetail.quote) {
                LabeledContent(L10n.FundDetail.currentPrice) {
                    if let price = viewModel.displayPrice {
                        Text(price, format: .brl)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    } else {
                        Text(L10n.Common.dash)
                    }
                }
                if let changePercent = viewModel.displayChangePercent {
                    LabeledContent(L10n.FundDetail.change) {
                        Text(changePercent, format: .marketChange)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(changePercent >= 0 ? Color.appPositive : Color.red)
                    }
                }
                if let previousClose = viewModel.quote?.previousClose {
                    LabeledContent(L10n.FundDetail.previousClose) {
                        Text(previousClose, format: .brl)
                            .monospacedDigit()
                    }
                }
                if let dayLow = viewModel.quote?.dayLow, let dayHigh = viewModel.quote?.dayHigh {
                    LabeledContent(L10n.FundDetail.dayRange) {
                        Text(
                            L10n.FundDetail.rangeValue(
                                low: dayLow.formatted(.brl),
                                high: dayHigh.formatted(.brl)
                            )
                        )
                        .monospacedDigit()
                    }
                }
                if let weekLow = viewModel.quote?.fiftyTwoWeekLow, let weekHigh = viewModel.quote?.fiftyTwoWeekHigh {
                    LabeledContent(L10n.FundDetail.weekRange) {
                        Text(
                            L10n.FundDetail.rangeValue(
                                low: weekLow.formatted(.brl),
                                high: weekHigh.formatted(.brl)
                            )
                        )
                        .monospacedDigit()
                    }
                }
                if let volume = viewModel.displayVolume {
                    LabeledContent(L10n.FundDetail.volume) {
                        Text(volume, format: .number.notation(.compactName).locale(Locale(identifier: "pt_BR")))
                    }
                }
            }
            .imobSurface()

            if let indicators = viewModel.indicators {
                Section(L10n.FundDetail.indicators) {
                    if let lastDividend = viewModel.lastDividend {
                        LabeledContent(L10n.FundDetail.lastDividend) {
                            Text(lastDividend, format: .brl)
                                .monospacedDigit()
                        }
                    }
                    if let yield = indicators.dividendYield12m {
                        LabeledContent(L10n.FundDetail.dividendYield12m) {
                            Text(yield, format: .fiiYield)
                                .monospacedDigit()
                        }
                    }
                    if let priceToNav = indicators.priceToNav {
                        LabeledContent(L10n.FundDetail.priceToNav) {
                            Text(priceToNav, format: .number.precision(.fractionLength(2)))
                                .monospacedDigit()
                        }
                    }
                    if let nav = indicators.navPerShare {
                        LabeledContent(L10n.FundDetail.nav) {
                            Text(nav, format: .brl)
                                .monospacedDigit()
                        }
                    }
                    if let investors = indicators.totalInvestors {
                        LabeledContent(L10n.FundDetail.investors) {
                            Text(investors, format: .number.notation(.compactName).locale(Locale(identifier: "pt_BR")))
                        }
                    }
                    if let vacancyRate = indicators.vacancyRate {
                        LabeledContent(L10n.FundDetail.vacancy) {
                            Text(vacancyRate, format: .fiiYield)
                                .monospacedDigit()
                        }
                    }
                }
                .imobSurface()
            } else if let lastDividend = viewModel.lastDividend {
                Section(L10n.FundDetail.indicators) {
                    LabeledContent(L10n.FundDetail.lastDividend) {
                        Text(lastDividend, format: .brl)
                            .monospacedDigit()
                    }
                }
                .imobSurface()
            }

            Section(L10n.FundDetail.about) {
                LabeledContent(L10n.Common.segment, value: viewModel.summary.segment.title)
                if let tipoGestao = viewModel.indicators?.tipoGestao {
                    LabeledContent(L10n.FundDetail.management, value: tipoGestao)
                }
                LabeledContent(L10n.FundDetail.administrator, value: administratorText)
            }
            .imobSurface()
        }
        .imobListCanvas()
        .animation(.smooth(duration: 0.4), value: viewModel.isLoadingMarketData)
        .navigationTitle(viewModel.summary.ticker)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            addToPortfolioButton
        }
        .task {
            await viewModel.loadMarketData()
            guard !Task.isCancelled else { return }
            persistCachedFund()
        }
        .sheet(isPresented: $isAddingHolding) {
            AddHoldingSheet(
                summary: viewModel.summary,
                indicators: viewModel.indicators,
                lastDividend: viewModel.lastDividend
            )
        }
        .sheet(isPresented: $isEditingHolding) {
            if let currentHolding {
                EditHoldingSheet(holding: currentHolding)
            }
        }
    }

    private func persistCachedFund() {
        FundStore.upsert(
            viewModel.summary,
            indicators: viewModel.indicators,
            lastDividend: viewModel.lastDividend,
            in: modelContext
        )
    }

    private var currentHolding: Holding? {
        holdings.first { $0.fund?.ticker == viewModel.summary.ticker }
    }

    private var isInPortfolio: Bool {
        currentHolding != nil
    }

    private var addToPortfolioButton: some View {
        VStack(spacing: Spacing.xs) {
            ImobExpandingPrimaryButton(
                title: isInPortfolio ? L10n.FundDetail.addShares : L10n.FundDetail.addToPortfolio,
                systemImage: "plus",
                action: { isAddingHolding = true },
            )

            if isInPortfolio {
                Button(L10n.FundDetail.editPosition) {
                    isEditingHolding = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.top, Spacing.xxs)
                .padding(.bottom, Spacing.xxs)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.md)
    }

    private var administratorText: String {
        let manager = viewModel.manager
        return manager.isEmpty ? L10n.Common.notSpecified : manager
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label(viewModel.summary.segment.title, systemImage: viewModel.summary.segment.systemImage)
                .font(.subheadline)
                .foregroundStyle(Color.appSecondaryText)
            Text(viewModel.displayName)
                .font(.title2.weight(.semibold))
            if viewModel.isLoadingMarketData {
                ProgressView()
                    .controlSize(.small)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let fund = SampleData.makeCatalog()[0]
    NavigationStack {
        FundDetailView(summary: FundSummary(fund: fund))
    }
    .modelContainer(Persistence.makeContainer(inMemory: true))
}
