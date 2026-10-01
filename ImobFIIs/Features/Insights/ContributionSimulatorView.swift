import SwiftData
import SwiftUI

struct ContributionSimulatorView: View {
    let strategy: any AllocationStrategy

    @Query private var holdings: [Holding]

    @State private var amount: Decimal?
    @State private var simulatedAmount: Decimal = 0
    /// Patrimônio por segmento no momento em que o simulador abriu: as cotas compradas a partir dele
    /// não redistribuem o aporte que o usuário está executando.
    @State private var frozenValues: [FundSegment: Double]?

    var body: some View {
        let contributions = ContributionSimulator.simulate(
            amount: simulatedAmount,
            valueBySegment: frozenValues ?? ContributionSimulator.segmentValues(in: holdings),
            strategy: strategy
        )

        Form {
            Section {
                BRLCurrencyTextField(amount: $amount)
                    .font(.title3.weight(.semibold))
            } header: {
                Text(L10n.Simulator.amount)
            } footer: {
                Text(L10n.Simulator.amountFooter)
            }
            .imobSurface()

            Section {
                ForEach(contributions) { contribution in
                    NavigationLink(value: InsightsRoute.segmentHoldings(contribution)) {
                        contributionRow(contribution)
                    }
                }
            } header: {
                Text(L10n.Simulator.distribution)
            } footer: {
                Text(L10n.Simulator.disclaimer)
            }
            .imobSurface()
        }
        .onAppear {
            if frozenValues == nil {
                frozenValues = ContributionSimulator.segmentValues(in: holdings)
            }
        }
        .task(id: amount) {
            // Recalcular a lista a cada tecla atrasa a atualização da máscara enquanto o campo está em edição.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            simulatedAmount = amount ?? 0
        }
        .imobListCanvas()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(L10n.Simulator.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func contributionRow(_ contribution: SegmentContribution) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Label(contribution.segment.title, systemImage: contribution.segment.systemImage)
                Spacer(minLength: Spacing.xs)
                Text(contribution.amount, format: .brl)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(contribution.amount > 0 ? Color.appPrimaryText : Color.appSecondaryText)
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

    private func percentText(_ value: Double) -> String {
        value.formatted(
            .percent
                .precision(.fractionLength(0))
                .locale(Locale(identifier: "pt_BR"))
        )
    }
}
