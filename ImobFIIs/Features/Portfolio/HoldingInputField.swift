import SwiftUI

struct HoldingInputField<FieldContent: View>: View {
    let title: String
    let isFocused: Bool
    let onSelect: () -> Void
    @ViewBuilder var field: () -> FieldContent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.appSecondaryText)

            HStack(spacing: Spacing.xs) {
                field()
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHint(L10n.EditHolding.tapToEdit)
                Button(action: onSelect) {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.EditHolding.tapToEdit)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.field)
            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isFocused ? Color.accentColor : .clear, lineWidth: 1)
            }
        }
        .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.md, bottom: Spacing.sm, trailing: Spacing.md))
        .listRowSeparator(.hidden)
    }
}
