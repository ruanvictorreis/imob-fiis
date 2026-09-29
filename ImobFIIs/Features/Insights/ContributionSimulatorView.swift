import SwiftUI

struct ContributionSimulatorView: View {
    @Environment(\.dismiss) private var dismiss

    let holdings: [Holding]
    let strategy: any AllocationStrategy

    @State private var amount: Decimal?

    private var contributions: [SegmentContribution] {
        guard let amount else { return [] }
        return ContributionSimulator.simulate(amount: amount, holdings: holdings, strategy: strategy)
    }

    var body: some View {
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

                if !contributions.isEmpty {
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
