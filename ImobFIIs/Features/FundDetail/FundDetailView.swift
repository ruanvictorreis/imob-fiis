import SwiftData
import SwiftUI

struct FundDetailView: View {
    @Query private var holdings: [Holding]
    @State private var viewModel: FundDetailViewModel
    @State private var isAddingHolding = false

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

            Section("Cotação") {
                LabeledContent("Preço atual") {
                    if let price = viewModel.displayPrice {
                        Text(price, format: .brl)
                            .monospacedDigit()
                    } else {
                        Text("—")
                    }
                }
                if let changePercent = viewModel.displayChangePercent {
                    LabeledContent("Variação") {
                        Text(changePercent, format: .marketChange)
                            .monospacedDigit()
                            .foregroundStyle(changePercent >= 0 ? Color.green : Color.red)
                    }
                }
                if let previousClose = viewModel.quote?.previousClose {
                    LabeledContent("Fechamento anterior") {
                        Text(previousClose, format: .brl)
                            .monospacedDigit()
                    }
                }
                if let dayLow = viewModel.quote?.dayLow, let dayHigh = viewModel.quote?.dayHigh {
                    LabeledContent("Máxima/mínima do dia") {
                        Text("\(dayLow.formatted(.brl)) – \(dayHigh.formatted(.brl))")
                            .monospacedDigit()
                    }
                }
                if let weekLow = viewModel.quote?.fiftyTwoWeekLow, let weekHigh = viewModel.quote?.fiftyTwoWeekHigh {
                    LabeledContent("Mínima/máxima 52 semanas") {
                        Text("\(weekLow.formatted(.brl)) – \(weekHigh.formatted(.brl))")
                            .monospacedDigit()
                    }
                }
                if let volume = viewModel.displayVolume {
                    LabeledContent("Volume") {
                        Text(volume, format: .number.notation(.compactName).locale(Locale(identifier: "pt_BR")))
                    }
                }
            }

            if let indicators = viewModel.indicators {
                Section("Indicadores") {
                    if let yield = indicators.dividendYield12m {
                        LabeledContent("Dividend yield 12m") {
                            Text(yield, format: .fiiYield)
                                .monospacedDigit()
                        }
                    }
                    if let priceToNav = indicators.priceToNav {
                        LabeledContent("P/VP") {
                            Text(priceToNav, format: .number.precision(.fractionLength(2)))
                                .monospacedDigit()
                        }
                    }
                    if let nav = indicators.navPerShare {
                        LabeledContent("Valor patrimonial") {
                            Text(nav, format: .brl)
                                .monospacedDigit()
                        }
                    }
                    if let investors = indicators.totalInvestors {
                        LabeledContent("Cotistas") {
                            Text(investors, format: .number.notation(.compactName).locale(Locale(identifier: "pt_BR")))
                        }
                    }
                    if let vacancyRate = indicators.vacancyRate {
                        LabeledContent("Vacância") {
                            Text(vacancyRate, format: .fiiYield)
                                .monospacedDigit()
                        }
                    }
                }
            }

            Section("Sobre") {
                LabeledContent("Segmento", value: viewModel.summary.segment.rawValue)
                if let tipoGestao = viewModel.indicators?.tipoGestao {
                    LabeledContent("Gestão", value: tipoGestao)
                }
                LabeledContent("Administrador", value: administratorText)
            }
        }
        .navigationTitle(viewModel.summary.ticker)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            addToPortfolioButton
        }
        .task {
            await viewModel.loadMarketData()
        }
        .sheet(isPresented: $isAddingHolding) {
            AddHoldingSheet(
                summary: viewModel.summary,
                indicators: viewModel.indicators
            )
        }
    }

    private var isInPortfolio: Bool {
        holdings.contains { $0.fund?.ticker == viewModel.summary.ticker }
    }

    private var addToPortfolioButton: some View {
        Button(isInPortfolio ? "Adicionar cotas" : "Adicionar à carteira", systemImage: "plus") {
            isAddingHolding = true
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var administratorText: String {
        let manager = viewModel.manager
        return manager.isEmpty ? "Não informado" : manager
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(viewModel.summary.segment.rawValue, systemImage: viewModel.summary.segment.systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(viewModel.displayName)
                .font(.title2.weight(.semibold))
            if viewModel.isLoadingMarketData {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        FundDetailView(
            summary: MockFIICatalogService.preview.page.funds[0],
            catalog: MockFIICatalogService.preview
        )
    }
    .modelContainer(Persistence.makeContainer(inMemory: true))
}
