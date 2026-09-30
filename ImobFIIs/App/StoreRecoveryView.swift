import SwiftUI

struct StoreRecoveryView: View {
    let errorDescription: String
    let restoreFailed: Bool
    let onRetry: () -> Void
    let onRestore: () -> Void

    @State private var isConfirmingRestore = false

    var body: some View {
        ContentUnavailableView {
            Label(L10n.Recovery.title, systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            VStack(spacing: Spacing.md) {
                Text(L10n.Recovery.description)
                if restoreFailed {
                    Text(L10n.Recovery.restoreFailed)
                        .foregroundStyle(Color.red)
                }
                DisclosureGroup(L10n.Recovery.details) {
                    Text(errorDescription)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.footnote)
            }
        } actions: {
            Button(L10n.Recovery.restore) {
                isConfirmingRestore = true
            }
            .imobPrimaryButton()
            Button(L10n.Common.retry, action: onRetry)
        }
        .imobCanvas()
        .confirmationDialog(
            L10n.Recovery.restoreConfirmTitle,
            isPresented: $isConfirmingRestore,
            titleVisibility: .visible
        ) {
            Button(L10n.Recovery.restore, role: .destructive, action: onRestore)
        } message: {
            Text(L10n.Recovery.restoreConfirmMessage)
        }
    }
}

#Preview {
    StoreRecoveryView(
        errorDescription: "SwiftDataError(_error: SwiftData.SwiftDataError._Error.loadIssueModelContainer)",
        restoreFailed: false,
        onRetry: {},
        onRestore: {}
    )
}
