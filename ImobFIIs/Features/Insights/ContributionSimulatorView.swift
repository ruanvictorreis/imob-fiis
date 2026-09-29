import SwiftUI

struct ContributionSimulatorView: View {
    @Environment(\.dismiss) private var dismiss

    let holdings: [Holding]
    let strategy: any AllocationStrategy

    @State private var amount: Decimal?
    @State private var simulatedAmount: Decimal = 0

    var body: some View {
        let contributions = ContributionSimulator.simulate(
            amount: simulatedAmount,
            holdings: holdings,
            strategy: strategy
        )

        NavigationStack {
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
                        contributionRow(contribution)
                    }
                } header: {
                    Text(L10n.Simulator.distribution)
                } footer: {
                    Text(L10n.Simulator.disclaimer)
                }
                .imobSurface()
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) {
                        dismiss()
                    }
                }
            }
        }
        .imobAppearance()
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
