import SwiftUI

struct EditAllocationTargetsView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var store: AllocationTargetsStore

    @State private var draftPercents: [FundSegment: Int] = [:]

    private var orderedSegments: [FundSegment] {
        store.orderedSegments
    }

    private var totalPercent: Int {
        orderedSegments.reduce(0) { $0 + (draftPercents[$1] ?? 0) }
    }

    private var isValid: Bool {
        totalPercent == 100
    }

    private var hasChanges: Bool {
        orderedSegments.contains { segment in
            let current = Int((store.weight(for: segment) * 100).rounded())
            return (draftPercents[segment] ?? 0) != current
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(orderedSegments) { segment in
                        segmentRow(segment)
                    }
                } header: {
                    Text(L10n.Insights.editAllocationHeader)
                } footer: {
                    Text(totalFooter)
                        .foregroundStyle(isValid ? Color.appSecondaryText : Color.red)
                }
                .imobSurface()

                Section {
                    Button(L10n.Insights.resetAllocation) {
                        applyDefaultsToDraft()
                    }
                }
                .imobSurface()
            }
            .imobListCanvas()
            .navigationTitle(L10n.Insights.editAllocationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.save) {
                        save()
                    }
                    .disabled(!isValid || !hasChanges)
                }
            }
            .onAppear {
                loadDraftFromStore()
            }
        }
        .imobAppearance()
    }

    private var totalFooter: String {
        if isValid {
            L10n.Insights.allocationTotalValid(percentText(totalPercent))
        } else {
            L10n.Insights.allocationTotalInvalid(percentText(totalPercent))
        }
    }

    private func segmentRow(_ segment: FundSegment) -> some View {
        HStack {
            Label(segment.title, systemImage: segment.systemImage)
            Spacer(minLength: Spacing.xs)
            Text(percentText(draftPercents[segment] ?? 0))
                .monospacedDigit()
                .foregroundStyle(Color.appSecondaryText)
                .frame(minWidth: 44, alignment: .trailing)
            Stepper(
                value: binding(for: segment),
                in: 0...100,
                step: 1,
                label: { EmptyView() },
            )
            .labelsHidden()
            .accessibilityLabel(segment.title)
        }
    }

    private func binding(for segment: FundSegment) -> Binding<Int> {
        Binding(
            get: { draftPercents[segment] ?? 0 },
            set: { draftPercents[segment] = min(max($0, 0), 100) }
        )
    }

    private func loadDraftFromStore() {
        draftPercents = Dictionary(
            uniqueKeysWithValues: orderedSegments.map { segment in
                (segment, Int((store.weight(for: segment) * 100).rounded()))
            }
        )
    }

    private func applyDefaultsToDraft() {
        draftPercents = Dictionary(
            uniqueKeysWithValues: orderedSegments.map { segment in
                let weight = AllocationTargetsStore.defaultWeights[segment] ?? 0
                return (segment, Int((weight * 100).rounded()))
            }
        )
    }

    private func save() {
        guard isValid else { return }
        let weights = Dictionary(
            uniqueKeysWithValues: orderedSegments.map { segment in
                (segment, Double(draftPercents[segment] ?? 0) / 100)
            }
        )
        store.replaceAll(weights)
        guard store.save() else { return }
        dismiss()
    }

    private func percentText(_ value: Int) -> String {
        (Double(value) / 100).formatted(
            .percent
                .precision(.fractionLength(0))
                .locale(Locale(identifier: "pt_BR"))
        )
    }
}

#Preview {
    EditAllocationTargetsView(store: AllocationTargetsStore(defaults: UserDefaults(suiteName: "preview")!))
}
